import Foundation

public enum NoiseSource { case player, object, event }

struct Observation {
    var rate: Double = 0
    var bump: Double = 0
    var kind: IncidentKind?
    var normalizing = false
}

extension Game {
    public static let reactionDelay = 0.6

    // MARK: Vision

    func npcEye(_ n: NPCState) -> Vec2 { n.pos + Vec2(0, -0.15) }

    func npcSeesPoint(_ n: NPCState, _ p: Vec2, range: Double, fov: Double? = nil) -> Bool {
        let def = Cast.def(n.id)
        let f = fov ?? def.role.vision.fov
        let eye = npcEye(n)
        let d = p - eye
        let dist = d.length
        guard dist <= range * lightingFactor(at: p) else { return false }
        if dist > 1.0 {
            if abs(angleDiff(d.angle, n.heading)) > f / 2 { return false }
        }
        return Sight.clear(map, eye, p, opaque: { self.opaque($0) })
    }

    /// Night and tunnels reduce sight range.
    func lightingFactor(at p: Vec2) -> Double {
        var f = 1.0
        if activity == .lightsOut || activity == .sleep { f *= 0.65 }
        if let z = map.zone(at: p), z.district == .service { f *= 0.8 }
        return f
    }

    func npcCanSeePlayer(_ n: NPCState, _ def: NPCDef) -> Bool {
        guard n.present, s.player.hiddenIn == nil, def.role.vision.range > 0 else { return false }
        return npcSeesPoint(n, s.player.pos, range: def.role.vision.range)
    }

    // MARK: Perception tick (≈10 Hz)

    func updatePerception(_ dt: Double) {
        let showCones = settings.conesAlways || s.player.sneakToggle
        conePolys = [:]
        for i in s.npcs.indices {
            var n = s.npcs[i]
            let def = Cast.def(n.id)
            guard def.role.isStaff, n.present else { s.npcs[i] = n; continue }
            if n.mode == .scripted || n.mode == .escort { s.npcs[i] = n; continue }
            let sees = npcCanSeePlayer(n, def)
            let dist = n.pos.distance(to: s.player.pos)
            var obs = Observation()
            if sees {
                n.lastKnown = s.player.pos
                n.lastSeenTime = s.realTime
                obs = observe(&n, def, dist: dist)
            }
            applySuspicion(&n, def, obs, sees: sees, dist: dist, dt: dt)
            transitionAI(&n, def, sees: sees, dist: dist, dt: dt)
            if (showCones || n.suspicion >= 25) && isOnScreen(n.pos) {
                conePolys[n.id] = Sight.conePolygon(map, origin: npcEye(n), heading: n.heading, fov: def.role.vision.fov,
                                                    range: def.role.vision.range * lightingFactor(at: n.pos), rays: 26, opaque: { self.opaque($0) })
            }
            s.npcs[i] = n
        }
        updateCameras(dt, showCones: showCones)
        if s.watch == .red { ensureObserver() }
    }

    func observe(_ n: inout NPCState, _ def: NPCDef, dist: Double) -> Observation {
        var o = Observation()
        let zone = map.zone(at: s.player.pos) ?? map.zone(id: s.player.lastZone)
        if s.player.changing > 0 {
            o.bump = 50
            o.kind = .changingWatched
            return o
        }
        // A witnessed theft is remembered: seeing you again restarts the pursuit.
        if (n.questionReason == .theft || n.questionReason == .assault) && n.mode != .pursue {
            o.bump = 100
            o.kind = n.questionReason
            return o
        }
        let disguised = s.player.outfit != .tanScrubs
        if disguised && !n.recognizedDisguise && isFamiliar(def.id) && dist <= recognitionRange(observer: def) {
            n.recognizedDisguise = true
            o.bump += 40
            o.kind = .brokenDisguise
            setBubble(&n, [.exclaim, .shirt], 2)
        }
        if let z = zone {
            if disguised && n.recognizedDisguise {
                o.rate += 18
                o.kind = o.kind ?? .brokenDisguise
            } else if disguised {
                if !disguisePlausible(z) {
                    o.rate += Game.restrictedRate(z.cls) * 0.8 + 4
                    o.kind = .restrictedArea
                } else if s.player.outfitCondition < 35 {
                    o.rate += 6
                    o.kind = .brokenDisguise
                }
            } else if !patientAllowed(z) {
                if activity == .lightsOut {
                    o.rate += 25
                    o.kind = .curfew
                } else if isCountActive && s.countState.resolved && !s.countState.present {
                    o.rate += 30
                    o.kind = .missedCount
                } else {
                    o.rate += Game.restrictedRate(z.cls)
                    o.kind = .restrictedArea
                }
            } else if isCountActive && s.countState.resolved && !s.countState.present {
                o.rate += 30
                o.kind = .missedCount
            }
        }
        if s.player.moving && effectiveMode == .run && !(zone?.outdoor ?? false) {
            o.rate += s.lockdown ? 25 : 7
            if s.lockdown { o.kind = o.kind ?? .lockdownRunning }
        }
        for st in s.inventory.carried {
            let d = Items.def(st.id)
            if d.size >= .medium && !Items.isPermitted(st.id, job: s.player.job) {
                if d.legality == .dangerous { o.rate += 40; o.kind = .dangerousItem } else if d.legality >= .contraband || d.legality == .restricted {
                    o.rate += d.legality == .restricted ? 8 : 20
                    if o.kind == nil || o.kind == .restrictedArea { o.kind = .contraband }
                }
            }
        }
        if o.rate == 0 && o.bump == 0 { o.normalizing = isNormalizing() }
        return o
    }

    /// Contextually plausible work that calms unconfirmed suspicion.
    func isNormalizing() -> Bool {
        guard let job = s.player.job, playerOnShift(job) else { return false }
        switch job {
        case .janitorial: return s.inventory.count(.mop) > 0 || s.player.vehicle == .janitorCart
        case .laundry: return s.inventory.count(.laundryBag) > 0 || s.player.vehicle == .laundryCart
        case .kitchen: return s.inventory.count(.tray) > 0
        default:
            if let sp = map.spot(Jobs.def(job).stationSpot) { return sp.pos.distance(to: s.player.pos) < 2.5 }
            return false
        }
    }

    func applySuspicion(_ n: inout NPCState, _ def: NPCDef, _ o: Observation, sees: Bool, dist: Double, dt: Double) {
        if sees && (o.rate > 0 || o.bump > 0) {
            if let k = o.kind {
                if n.questionReason == nil || k.severity >= (n.questionReason?.severity ?? 0) { n.questionReason = k }
            }
            let range = max(1, def.role.vision.range)
            let distFactor = clamp(1.3 - 0.6 * dist / range, 0.6, 1.3)
            let strict = 0.6 + 0.6 * def.strictness
            var mult = distFactor * strict * settings.difficulty.suspicion
            if s.player.caughtImmunity > 0 { mult *= 0.3 }
            if s.watch == .yellow { mult *= 1.15 }
            if s.watch == .red { mult *= 1.3 }
            n.suspicion += o.bump
            if n.reacting < Game.reactionDelay && n.suspicion < 25 {
                n.reacting += dt
                n.suspicion += o.rate * mult * dt * 0.25
            } else {
                n.suspicion += o.rate * mult * dt
            }
            n.suspicion = min(100, n.suspicion)
        } else {
            n.reacting = max(0, n.reacting - dt)
            var decay: Double
            switch n.mode {
            case .routine, .notice, .resume, .count: decay = 6
            case .approach, .question: decay = sees ? 4 : 3
            case .investigate, .search, .inspect: decay = 1.5
            case .pursue: decay = sees ? 0 : 0.8
            default: decay = 4
            }
            if sees && o.normalizing { decay += 8 }
            // Confirmed violations (theft) do not fade while the hunt is on.
            let hunting = n.mode == .pursue || n.mode == .search || n.mode == .investigate || n.mode == .inspect
            let floor: Double = hunting && (n.questionReason == .theft || n.questionReason == .assault) ? 60 : 0
            n.suspicion = max(floor, n.suspicion - decay * dt)
            if n.suspicion < 5 && n.mode == .routine { n.questionReason = nil }
        }
    }

    func transitionAI(_ n: inout NPCState, _ def: NPCDef, sees: Bool, dist: Double, dt: Double) {
        let canAct = def.role.canIntervene
        switch n.mode {
        case .routine, .resume, .count, .follow:
            if n.suspicion >= 99 {
                if canAct { startPursuit(&n) } else { reportToCO(&n, def) }
            } else if n.suspicion >= 75 && canAct {
                n.mode = .investigate; n.modeTimer = 0; n.path = []
                setBubble(&n, [.exclaim], 1.5)
                sound(.alert, at: n.pos, volume: 0.6)
            } else if n.suspicion >= 50 {
                if canAct {
                    n.mode = .approach; n.modeTimer = 0; n.repathTimer = 0
                    setBubble(&n, [.question, .beckon], 2.5, caption: "Hey — you. Over here.")
                    sound(.question, at: n.pos, volume: 0.6)
                } else { reportToCO(&n, def) }
            } else if n.suspicion >= 25 && n.mode != .follow {
                n.mode = .notice; n.modeTimer = 0
                setBubble(&n, [.question], 2)
                sound(.question, at: n.pos, volume: 0.35)
            }
        case .notice:
            if n.suspicion >= 50 {
                if canAct {
                    n.mode = .approach; n.modeTimer = 0; n.repathTimer = 0
                    setBubble(&n, [.question, .beckon], 2.5, caption: "Hey — you. Over here.")
                    sound(.question, at: n.pos, volume: 0.6)
                } else { reportToCO(&n, def) }
            } else if n.suspicion < 15 || (!sees && n.modeTimer > 3) {
                n.mode = .resume; n.postKey = ""
            }
        case .approach:
            if n.suspicion >= 99 { startPursuit(&n); return }
            if sees && dist < 1.5 {
                n.mode = .question
                n.modeTimer = 0
                n.questionTimer = 3.2
                n.questionStart = s.player.pos
                setBubble(&n, [.stop, .question], 3.2, caption: "Stop. What are you doing here?")
                stopWalking()
                ui.questionedBy = n.id
                haptic(.warning)
            } else if !sees && n.modeTimer > 2.5 {
                n.mode = .investigate; n.modeTimer = 0
            } else if n.suspicion < 30 {
                n.mode = .resume; n.postKey = ""
            }
        case .question:
            let moved = s.player.pos.distance(to: n.questionStart ?? s.player.pos)
            if moved > 2.0 || s.player.hiddenIn != nil {
                n.suspicion = 100
                n.questionReason = .fleeing
                ui.questionedBy = nil
                startPursuit(&n)
            } else if n.questionTimer <= 0 || ui.complied == n.id {
                ui.questionedBy = nil
                let complied = ui.complied == n.id
                ui.complied = nil
                resolveQuestion(&n, def, complied: complied)
            }
        case .investigate, .search, .inspect:
            if sees && n.suspicion >= 50 {
                if n.suspicion >= 100 { startPursuit(&n) } else if canAct {
                    n.mode = .approach; n.modeTimer = 0; n.repathTimer = 0
                    setBubble(&n, [.exclaim, .beckon], 2)
                }
            }
            if n.mode == .investigate || n.mode == .search { radioIfNeeded(&n, def) }
        case .pursue:
            radioIfNeeded(&n, def)
        default:
            break
        }
    }

    func startPursuit(_ n: inout NPCState) {
        if n.mode != .pursue {
            n.mode = .pursue
            n.modeTimer = 0
            n.repathTimer = 0
            setBubble(&n, [.exclaim, .stop], 2.2, caption: "Stop right there!")
            sound(.alert, at: n.pos)
            audioCommands.append(.music(.search))
            haptic(.error)
        }
    }

    func reportToCO(_ n: inout NPCState, _ def: NPCDef) {
        guard !n.radioed else { return }
        n.radioed = true
        n.mode = .notice
        setBubble(&n, [.stop, .badge], 2.5, caption: "\(def.short) signals for an officer.")
        let lk = n.lastKnown ?? s.player.pos
        callForHelp(from: n.pos, lastKnown: lk, suspicion: max(60, n.suspicion), reason: n.questionReason, excluding: n.id, count: 1)
    }

    func radioIfNeeded(_ n: inout NPCState, _ def: NPCDef) {
        guard !n.radioed, n.modeTimer > 1.5 else { return }
        n.radioed = true
        s.facilityAlert = min(3, s.facilityAlert + 0.5)
        setBubble(&n, [.badge, .exclaim], 1.6)
        sound(.keys, at: n.pos, volume: 0.5)
        if let lk = n.lastKnown {
            callForHelp(from: n.pos, lastKnown: lk, suspicion: min(70, n.suspicion), reason: n.questionReason, excluding: n.id, count: n.mode == .pursue ? 2 : 1)
        }
    }

    /// Unit alert: nearest available officers converge on the reported position (not the player).
    func callForHelp(from: Vec2, lastKnown: Vec2, suspicion: Double, reason: IncidentKind?, excluding: NPCID, count: Int) {
        var candidates: [(Int, Double)] = []
        for (i, m) in s.npcs.enumerated() where m.id != excluding && m.present {
            let d = Cast.def(m.id)
            guard d.role.canIntervene, d.role != .k9 else { continue }
            guard m.mode == .routine || m.mode == .resume || m.mode == .notice || m.mode == .count else { continue }
            let dist = m.pos.distance(to: from)
            if dist < 35 { candidates.append((i, dist)) }
        }
        candidates.sort { $0.1 < $1.1 }
        for (i, _) in candidates.prefix(count) {
            s.npcs[i].mode = .investigate
            s.npcs[i].modeTimer = 0
            s.npcs[i].lastKnown = lastKnown
            s.npcs[i].suspicion = max(s.npcs[i].suspicion, min(74, suspicion))
            s.npcs[i].questionReason = reason
            s.npcs[i].path = []
            s.npcs[i].radioed = true
            s.npcs[i].bubble = [.badge]
            s.npcs[i].bubbleTimer = 1.5
        }
    }

    func resolveQuestion(_ n: inout NPCState, _ def: NPCDef, complied: Bool) {
        let reason = n.questionReason
        // Pat-down when they have reason to suspect contraband.
        let carryingIllegal = s.inventory.all.contains { !Items.isPermitted($0.1.id, job: s.player.job) }
        let wantsPatDown = reason == .contraband || reason == .dangerousItem || n.suspicion >= 70 || (def.strictness >= 0.9 && carryingIllegal && s.rng.chance(0.5))
        n.mode = .resume
        n.postKey = ""
        if reason == .brokenDisguise || reason == .missedCount || reason == .curfew || (wantsPatDown && carryingIllegal) {
            captured(by: n.id, reason: carryingIllegal && wantsPatDown && reason != .brokenDisguise ? .contraband : (reason ?? .contraband))
            n.suspicion = 0
            return
        }
        if reason == .restrictedArea, let z = map.zone(at: s.player.pos), Game.restrictedRate(z.cls) >= 15 || !complied {
            captured(by: n.id, reason: .restrictedArea)
            n.suspicion = 0
            return
        }
        // Proportionate: a warning and, if out of bounds, an escort back.
        n.suspicion = 8
        n.questionReason = nil
        setBubble(&n, complied ? [.thumbsUp, .walk] : [.stop, .walk], 2.2, caption: complied ? "Fine. Keep it moving." : "Walk. Don't run.")
        adjustStaff(def.id, complied ? 0 : -1)
        s.player.caughtImmunity = max(s.player.caughtImmunity, 20)
        if let z = map.zone(at: s.player.pos), !patientAllowed(z) && s.player.outfit == .tanScrubs {
            logIncident(.restrictedArea, witness: def.id, outcome: "Warning; escorted back")
            startEscort(by: def.id, to: escortHomeSpot())
        }
    }

    func escortHomeSpot() -> String {
        if activity.podLocked || activity == .lightsOut { return "fpod.cell\(s.player.cell).count" }
        return "fpod.center"
    }

    // MARK: Hiding inspection

    func nextHideToInspect(_ n: NPCState) -> String? {
        guard let lk = n.lastKnown else { return nil }
        if let seen = n.sawPlayerEnterHide, !n.searchedSpots.contains(seen) { return seen }
        if n.searchedSpots.count >= 2 { return nil }
        let district = map.district(at: lk.tile)
        let candidates = HideSpots.all.compactMap { h -> (String, Double)? in
            guard !n.searchedSpots.contains(h.objectID), let o = map.object(id: h.objectID) else { return nil }
            let d = o.center.distance(to: lk)
            guard d < 7.5, map.district(at: o.tile) == district else { return nil }
            return (h.objectID, d)
        }
        return candidates.min { $0.1 < $1.1 }?.0
    }

    func resolveInspection(_ n: inout NPCState, _ def: NPCDef, _ spot: String) {
        n.inspectTarget = nil
        if s.player.hiddenIn == spot, let h = hideSpotByObject[spot] {
            var p = h.discovery * settings.difficulty.suspicion
            if n.sawPlayerEnterHide == spot { p = min(0.95, p * 3) }
            if n.suspicion >= 95 { p = min(0.95, p * 1.4) }
            if s.rng.chance(p) {
                exitHide()
                setBubble(&n, [.exclaim], 1.5)
                let reason = (n.questionReason == nil || n.questionReason == .restrictedArea) ? IncidentKind.hidingFromStaff : n.questionReason!
                captured(by: n.id, reason: reason)
                return
            }
            setBubble(&n, [.question], 1.4)
        }
        n.mode = .search
        n.modeTimer = 1.0
    }

    // MARK: Noise

    func makeNoise(at p: Vec2, loudness: Double, suspicious: Bool, source: NoiseSource) {
        if loudness >= 2.5 { noisePulses.append(NoisePulse(pos: p, radius: loudness, age: 0, danger: suspicious)) }
        guard loudness > 0.3 else { return }
        let field = Sight.propagateNoise(map, from: p.tile, loudness: loudness, closedDoor: { self.doorClosed($0) })
        var contextSuspicious = false
        if suspicious {
            if let z = map.zone(at: p) {
                contextSuspicious = !patientAllowed(z) || activity.podLocked || s.lockdown || loudness >= 7 || activity == .lightsOut
            } else { contextSuspicious = s.lockdown || loudness >= 7 }
        }
        for i in s.npcs.indices where s.npcs[i].present {
            let def = Cast.def(s.npcs[i].id)
            guard def.role.isStaff, map.inBounds(s.npcs[i].pos.tile) else { continue }
            guard let rem = field[map.idx(s.npcs[i].pos.tile)], rem > 0 else { continue }
            var n = s.npcs[i]
            if contextSuspicious && (n.mode == .routine || n.mode == .resume || n.mode == .notice || n.mode == .count) && def.role.canIntervene {
                n.mode = .investigate
                n.modeTimer = 0
                n.lastKnown = p   // the noise source, not the player
                n.suspicion = max(n.suspicion, min(74, 30 + rem * 5))
                n.path = []
                setBubble(&n, [.question, .sound], 1.8)
            } else if n.mode == .routine && !n.moving {
                faceToward(&n, p, 1)
            }
            s.npcs[i] = n
        }
    }

    func updateNoisePulses(_ dt: Double) {
        for i in noisePulses.indices { noisePulses[i].age += dt }
        noisePulses.removeAll { $0.age > 0.9 }
    }

    // MARK: Cameras

    public func cameraHeading(_ c: CameraDef) -> Double {
        guard c.sweep > 0 else { return c.heading }
        return c.heading + c.sweep * sin(2 * .pi * s.realTime / c.period)
    }

    func updateCameras(_ dt: Double, showCones: Bool) {
        cameraPolys = [:]
        let gainesOnDuty = npc(.gaines).map { $0.present && map.zone(at: $0.pos)?.district == .control } ?? false
        for c in map.cameras {
            let h = cameraHeading(c)
            if showCones && isOnScreen(c.pos) {
                cameraPolys[c.id] = Sight.conePolygon(map, origin: c.pos, heading: h, fov: c.fov, range: c.range, rays: 20, opaque: { self.opaque($0) })
            }
            var susp = cameraSuspicion[c.id] ?? 0
            let d = s.player.pos - c.pos
            var sees = false
            if s.player.hiddenIn == nil && d.length <= c.range * lightingFactor(at: s.player.pos) && abs(angleDiff(d.angle, h)) <= c.fov / 2 {
                sees = Sight.clear(map, c.pos, s.player.pos, opaque: { self.opaque($0) })
            }
            if sees && !gainesOnDuty && s.player.hiddenIn == nil {
                var pseudo = NPCState(id: .gaines, pos: c.pos, heading: h)
                let o = observeForCamera(&pseudo)
                if o.bump > 0 || o.rate > 0, let z = map.zone(at: s.player.pos) {
                    var f = s.footage ?? []
                    if !f.contains(z.name) { f.append(z.name); s.footage = f; sound(.keys, volume: 0.25) }
                }
            }
            if sees && gainesOnDuty {
                var pseudo = NPCState(id: .gaines, pos: c.pos, heading: h)
                pseudo.recognizedDisguise = false
                let o = observeForCamera(&pseudo)
                susp = min(100, susp + (o.bump + o.rate * dt) * 0.8 * settings.difficulty.suspicion * (s.player.caughtImmunity > 0 ? 0.3 : 1))
                cameraLastKnown = s.player.pos
            } else {
                susp = max(0, susp - 5 * dt)
            }
            if susp >= 60, let lk = cameraLastKnown {
                susp = 25
                toast(.camera, "A camera picked you up", danger: true)
                sound(.keys, volume: 0.4)
                callForHelp(from: lk, lastKnown: lk, suspicion: 65, reason: .restrictedArea, excluding: .gaines, count: 1)
            }
            cameraSuspicion[c.id] = susp
        }
    }

    func observeForCamera(_ n: inout NPCState) -> Observation {
        // Cameras judge presence and visible items; they do not recognize faces.
        var o = Observation()
        guard let z = map.zone(at: s.player.pos) else { return o }
        let disguised = s.player.outfit != .tanScrubs
        if disguised { if !disguisePlausible(z) { o.rate += Game.restrictedRate(z.cls) * 0.8 } } else if !patientAllowed(z) {
            o.rate += Game.restrictedRate(z.cls)
        }
        if s.player.moving && effectiveMode == .run && !z.outdoor && s.lockdown { o.rate += 20 }
        return o
    }

    /// Red watch: a technician stays with the player.
    func ensureObserver() {
        let observerID: NPCID = (npc(.cole)?.present ?? false) ? .cole : .varga
        for i in s.npcs.indices {
            let isObs = s.npcs[i].id == observerID
            if isObs && !s.npcs[i].followPlayer { s.npcs[i].followPlayer = true; s.npcs[i].postKey = "" }
            if !isObs && s.npcs[i].followPlayer && (s.npcs[i].id == .cole || s.npcs[i].id == .varga) { s.npcs[i].followPlayer = false; s.npcs[i].mode = .resume }
        }
    }

    public func maxSuspicion() -> (NPCID?, Double) {
        var best: (NPCID?, Double) = (nil, 0)
        for n in s.npcs where n.present && n.suspicion > best.1 { best = (n.id, n.suspicion) }
        let cam = cameraSuspicion.values.max() ?? 0
        if cam > best.1 { best = (nil, cam) }
        return best
    }
}
