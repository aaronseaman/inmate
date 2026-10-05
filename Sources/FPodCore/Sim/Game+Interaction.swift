import Foundation

extension Game {
    // MARK: Target geometry

    public func targetPosition(_ t: TargetRef) -> Vec2? {
        switch t {
        case .npc(let id): return npc(id).flatMap { $0.present ? $0.pos : nil }
        case .object(let id): return map.object(id: id)?.center
        case .door(let id): return map.door(id: id)?.tile.center
        }
    }

    func targetDistance(_ t: TargetRef) -> Double {
        switch t {
        case .npc(let id):
            guard let n = npc(id), n.present else { return .infinity }
            return n.pos.distance(to: s.player.pos)
        case .object(let id):
            guard let o = map.object(id: id) else { return .infinity }
            return o.rect.rect.distance(to: s.player.pos)
        case .door(let id):
            guard let d = map.door(id: id) else { return .infinity }
            return TileRect(d.tile.x, d.tile.y, 1, 1).rect.distance(to: s.player.pos)
        }
    }

    /// Within ~1.25 tiles with a clear line that crosses no wall or door.
    public func canInteract(with t: TargetRef) -> Bool {
        if s.player.hiddenIn != nil {
            if case .object(let id) = t { return id == s.player.hiddenIn }
            return false
        }
        let dist = targetDistance(t)
        guard dist <= Game.interactRadius else { return false }
        guard let p = targetPosition(t) else { return false }
        // Sample toward the target's nearest point; doors/walls in between block.
        var aim = p
        if case .object(let id) = t, let o = map.object(id: id) {
            let r = o.rect.rect
            aim = Vec2(clamp(s.player.pos.x, r.minX + 0.05, r.maxX - 0.05), clamp(s.player.pos.y, r.minY + 0.05, r.maxY - 0.05))
        }
        let from = s.player.pos
        let d = aim - from
        let steps = max(2, Int(d.length / 0.15))
        let myTile = from.tile
        var targetTiles: Set<TilePos> = [aim.tile]
        if case .object(let id) = t, let o = map.object(id: id) { o.rect.forEach { targetTiles.insert($0) } }
        if case .door(let id) = t, let dd = map.door(id: id) { targetTiles.insert(dd.tile) }
        for k in 1..<steps {
            let q = from + d * (Double(k) / Double(steps))
            let tile = q.tile
            if tile == myTile || targetTiles.contains(tile) { continue }
            let kind = map.kind(tile)
            if kind == .wall || kind == .void || kind == .door || kind == .window { return false }
        }
        return true
    }

    func approachPoint(for t: TargetRef) -> Vec2? {
        switch t {
        case .npc(let id):
            guard let n = npc(id) else { return nil }
            let dir = (s.player.pos - n.pos).normalized
            let p = n.pos + (dir.lengthSquared > 0 ? dir : Vec2(0, 1)) * 0.9
            return map.walkableStatic(p.tile) ? p : n.pos
        case .object(let id):
            guard let o = map.object(id: id) else { return nil }
            let tiles = map.approachTiles(for: o).filter { playerReachable($0) }
            return tiles.min { $0.center.distance(to: s.player.pos) < $1.center.distance(to: s.player.pos) }?.center
        case .door(let id):
            guard let d = map.door(id: id) else { return nil }
            let a = d.vertical ? TilePos(d.tile.x - 1, d.tile.y) : TilePos(d.tile.x, d.tile.y - 1)
            let b = d.vertical ? TilePos(d.tile.x + 1, d.tile.y) : TilePos(d.tile.x, d.tile.y + 1)
            return [a, b].min { $0.center.distance(to: s.player.pos) < $1.center.distance(to: s.player.pos) }?.center
        }
    }

    func playerReachable(_ t: TilePos) -> Bool { map.walkableStatic(t) }

    /// Tap on a target: interact if close, otherwise walk over first.
    public func engage(_ t: TargetRef, run: Bool = false) {
        if case .door(let id) = t, let d = map.door(id: id), let di = map.doorByID[id], !playerCanPass(doorIndex: di) {
            let (icon, text) = doorRequirement(d)
            toast(icon, "\(d.name): \(text)")
            sound(.doorLock, volume: 0.6)
            ui.contextTarget = t
            return
        }
        if canInteract(with: t) {
            openInteraction(t)
            return
        }
        // People pause when they see you coming; if you can't reach them, they come to you.
        if case .npc(let id) = t {
            withNPC(id) { n in
                if n.mode == .routine || n.mode == .resume || n.mode == .count || n.mode == .notice {
                    n.attendTimer = 8
                    n.attendCome = false
                }
            }
        }
        guard let ap = approachPoint(for: t) else { return }
        if walk(to: ap, run: run) {
            ui.pendingTarget = t
        } else if case .npc(let id) = t {
            withNPC(id) { n in if n.attendTimer > 0 { n.attendCome = true; n.attendTimer = 10 } }
            ui.pendingTarget = t
            bubble(id, [.beckon, .clock], seconds: 2, caption: "Hang on — coming.")
        }
    }

    // MARK: Options

    public func options(for t: TargetRef) -> [InteractOption] {
        var out: [InteractOption] = []
        func add(_ id: String, _ icon: Icon, _ caption: String, risky: Bool = false, enabled: Bool = true, note: String? = nil) {
            out.append(InteractOption(id: id, icon: icon, caption: caption, risky: risky, enabled: enabled, note: note))
        }
        // Content interactions first (quest-specific beats).
        for def in Interactions.forTarget(t, map: map) where eval(def.when) {
            if def.once && s.usedInteractions.contains(def.id) { continue }
            add("c.\(def.id)", def.icon, def.caption, risky: def.risky)
        }
        switch t {
        case .npc(let id):
            let def = Cast.def(id)
            if ui.questionedBy == id { out.insert(InteractOption(id: "b.comply", icon: .thumbsUp, caption: "Comply", risky: false, enabled: true, note: nil), at: 0) }
            add("b.talk", .voice, def.role.isStaff ? "Talk" : "Chat")
            if !Trades.forNPC(id).isEmpty && !def.role.isStaff { add("b.trade", .swap, "Trade") }
            if let r = s.recovery, r.npc == id, !s.watch72 { add("b.recovery", .favor, "Talk about the incident") }
            if let ap = appointmentFor(id) { add("b.appt", ap.icon, "Appointment: \(ap.title)") }
            if id == .pruitt && !claimableProperty.isEmpty { add("b.claim", .form, "Claim property") }
        case .object(let oid):
            guard let o = map.object(id: oid) else { break }
            let ownCell = o.zone == "fpod.cell\(s.player.cell)"
            if s.player.hiddenIn == oid { add("b.unhide", .arrowRight, "Come out"); return out }
            switch o.kind {
            case .bunk:
                if ownCell {
                    add("b.sleep", .moon, "Sleep", enabled: canSleepNow(), note: canSleepNow() ? nil : "After 20:00")
                    add("b.stash", .stash, "Mattress stash")
                }
                if hideSpotByObject[oid] != nil { add("b.hide", .hide, "Hide under") }
            case .locker:
                if ownCell { add("b.locker", .stash, "Locker") } else if o.zone.hasPrefix("fpod.cell") { add("b.peek", .hand, "Look inside", risky: true) }
            case .toilet:
                if ownCell { add("b.stash", .stash, "Toilet tank") }
            case .vent:
                if ownCell { add("b.stash", .stash, "Vent", enabled: s.inventory.count(.screwdriver) > 0, note: "Needs screwdriver") }
                if hideSpotByObject[oid] != nil { add("b.hide", .hide, "Ceiling space") }
            case .hamper, .stack:
                if hideSpotByObject[oid] != nil { add("b.hide", .hide, "Hide") }
                if stashByObject[oid] != nil { add("b.stash", .stash, "Stash") }
            case .shower:
                add("b.hide", .hide, "Hide in stall")
                add("b.change", .change, "Change clothes")
            case .closetShelf:
                if hideSpotByObject[oid] != nil { add("b.hide", .hide, "Hide") }
                if privateForChanging() { add("b.change", .change, "Change clothes") }
            case .pew, .dumpster, .crate, .cartBay:
                if hideSpotByObject[oid] != nil { add("b.hide", .hide, "Hide") }
            case .sink:
                add("b.wash", .soap, "Wash up")
            case .tv:
                add("b.tv", .tv, "Watch")
            case .phone:
                add("b.phone", .phone, "Phone", enabled: phoneAvailable().0, note: phoneAvailable().1)
            case .medWindow:
                add("b.med", .pills, "Med window", enabled: activity == .medPass, note: "Med pass 06:20–07:00")
            case .commissary:
                add("b.shop", .coin, "Commissary", enabled: commissaryOpen, note: "Afternoons & free time")
            case .noticeBoard:
                add("b.board", .list, "Read board")
            case .donationBox:
                add("b.stash", .box, "Donation box")
            case .waterCooler:
                add("b.drink", .cup, "Drink")
            case .piano:
                add("b.piano", .music, "Play a tune")
            case .hatch, .culvert:
                if let (link, _) = Hatches.objects[oid], let h = map.hatches.first(where: { $0.id == link }) {
                    let known = h.discoveredBy.map { has($0) } ?? true
                    if known { add("b.climb", .arrowDown, "Climb through", enabled: ruleAllowsPlayer(h.rule) || s.player.escortedBy != nil, note: "Needs the utility key") }
                }
            default:
                break
            }
            if stashByObject[oid] != nil && !out.contains(where: { $0.id == "b.stash" || $0.id == "b.locker" || $0.id == "b.peek" }) {
                add("b.stash", .stash, "Look through")
            }
            // Job stations.
            if let job = s.player.job, Jobs.def(job).stationObject == oid {
                let key = "d\(s.day).\(activity.rawValue)"
                let done = s.shiftDoneKeys.contains(key)
                add("b.shift", Jobs.def(job).icon, done ? "Shift done" : "Start shift", enabled: playerOnShift(job) && !done,
                    note: playerOnShift(job) ? nil : "Work 08:00–11:00, 13:00–15:00")
            }
        case .door(let id):
            if let d = map.door(id: id), let di = map.doorByID[id], !playerCanPass(doorIndex: di) {
                let (icon, text) = doorRequirement(d)
                add("b.info", icon, text, enabled: false)
            }
        }
        return out
    }

    public func openInteraction(_ t: TargetRef) {
        let opts = options(for: t)
        if case .npc(let id) = t { faceNPCTowardPlayer(id); meet(id) }
        faceToward(t)
        guard !opts.isEmpty else { toast(.question, "Nothing to do here"); return }
        let enabled = opts.filter { $0.enabled }
        if enabled.count == 1 && opts.count == 1 && !enabled[0].risky && enabled[0].id.hasPrefix("b.") && !["b.trade", "b.stash", "b.locker"].contains(enabled[0].id) {
            perform(enabled[0].id, on: t)
            return
        }
        ui.modal = .fan(t, opts)
        sound(.tap, volume: 0.5)
        haptic(.light)
    }

    func faceToward(_ t: TargetRef) {
        if let p = targetPosition(t) {
            let d = p - s.player.pos
            if d.length > 0.01 { s.player.heading = d.angle }
        }
    }

    func faceNPCTowardPlayer(_ id: NPCID) {
        withNPC(id) { n in
            let d = s.player.pos - n.pos
            if d.length > 0.01 && n.mode == .routine { n.heading = d.angle }
        }
    }

    func meet(_ id: NPCID) {
        if Cast.def(id).role.isStaff { s.metStaff.insert(id) }
    }

    public func phoneAvailable() -> (Bool, String?) {
        if let until = s.restrictions[.noPhone], until > s.absMinute { return (false, "Phone restricted") }
        if !(activity == .freeTime || activity == .visiting) { return (false, "Calls in free time") }
        if !has(.phoneListApproved) { return (false, "Needs approved phone list") }
        return (true, nil)
    }

    // MARK: Perform

    public func perform(_ optionID: String, on t: TargetRef) {
        ui.modal = nil
        if optionID.hasPrefix("c.") {
            let id = String(optionID.dropFirst(2))
            guard let def = Interactions.byID[id], eval(def.when) else { return }
            if def.once { s.usedInteractions.insert(def.id) }
            emit(.interacted(def.id))
            if case .npc(let n) = t {
                emit(.talked(n))
                if !def.reply.isEmpty { bubble(n, def.reply, caption: def.caption); mumble(n) }
            }
            if let w = def.witnessed { witnessCheck(w) }
            apply(def.effects, npc: { if case .npc(let n) = t { return n }; return nil }())
            processEvents()
            return
        }
        switch optionID {
        case "b.comply":
            if case .npc(let id) = t { ui.complied = id }
        case "b.talk":
            if case .npc(let id) = t { talk(id) }
        case "b.trade":
            if case .npc(let id) = t {
                let trades = Trades.forNPC(id)
                if trades.count == 1 { ui.modal = .trade(quote(trades[0])) } else { ui.modal = .tradeList(id) }
            }
        case "b.recovery":
            if case .npc(let id) = t {
                completeRecovery()
                bubble(id, [.heart, .thumbsUp], caption: "Thanks for owning it. I'll note that.")
                mumble(id)
            }
        case "b.appt":
            if case .npc(let id) = t, let ap = appointmentFor(id) {
                markAppointmentAttended(ap.id)
                bubble(id, [.check, ap.icon], caption: ap.title)
                mumble(id)
                emit(.appointmentKept(ap.id))
            }
        case "b.claim":
            let n = claimProperty()
            toast(.form, n > 0 ? "Property returned (\(n))" : "Nothing to claim")
            bubble(.pruitt, [.form, .check])
        case "b.sleep":
            if canSleepNow() { goToSleep() }
        case "b.hide":
            if case .object(let id) = t { enterHide(id) }
        case "b.unhide":
            exitHide()
        case "b.stash", "b.locker":
            if case .object(let id) = t {
                if let d = stashByObject[id], let need = d.needs, s.inventory.count(need) == 0 {
                    toast(.tools, "Needs a \(Items.def(need).name.lowercased())")
                    return
                }
                ui.modal = .stash(id)
                ui.stashSelection = nil
                if !privateStash(id) { witnessCheckSoft() }
            }
        case "b.peek":
            if case .object(let id) = t { ui.modal = .stash(id); ui.stashSelection = nil }
        case "b.change":
            ui.modal = .outfit
        case "b.wash":
            let soap = s.inventory.count(.soap) > 0
            s.player.outfitCondition = min(100, s.player.outfitCondition + (soap ? 40 : 15))
            s.player.energy = min(100, s.player.energy + 2)
            toast(.soap, soap ? "Freshened up (soap)" : "Splashed some water")
            sound(.splash)
        case "b.tv":
            sound(.tvMumble)
            if Systems.flavor(day: s.day, seed: s.seed) == .movieNight && activity == .freeTime && !s.usedInteractions.contains("movie.d\(s.day)") {
                s.usedInteractions.insert("movie.d\(s.day)")
                s.player.energy = min(100, s.player.energy + 10)
                for n in s.npcs where n.present && Cast.def(n.id).role == .peer && n.pos.distance(to: s.player.pos) < 8 { adjustPeer(n.id, 1, silent: true) }
                toast(.tv, "Movie night: a heist film. Everyone roots for the wrong people.")
                return
            }
            s.player.energy = min(100, s.player.energy + 2)
            toast(.tv, ["Game show reruns", "Weather: more weather", "A cooking show about soup"][Int(s.minute) % 3])
        case "b.phone":
            ui.modal = .phone
        case "b.med":
            ui.modal = .choice(.medPass)
        case "b.shop":
            ui.modal = .commissary
        case "b.board":
            openDoc(.handbook)
        case "b.drink":
            s.player.energy = min(100, s.player.energy + 1)
            sound(.splash, volume: 0.5)
        case "b.piano":
            sound(.whistle)
            toast(.music, "A few bars of something hopeful")
            adjustPeer(.theo, 1, silent: true)
        case "b.climb":
            if case .object(let id) = t { climbHatch(id) }
        case "b.shift":
            if let job = s.player.job { startShift(job) }
        default:
            break
        }
        processEvents()
    }

    func privateStash(_ objectID: String) -> Bool {
        stashByObject[objectID]?.legal ?? false
    }

    /// Using a concealed stash in view of staff is suspicious (but not theft).
    func witnessCheckSoft() {
        for i in s.npcs.indices where s.npcs[i].present {
            let def = Cast.def(s.npcs[i].id)
            if def.role.isStaff && npcCanSeePlayer(s.npcs[i], def) {
                s.npcs[i].suspicion = min(100, s.npcs[i].suspicion + 30)
                s.npcs[i].questionReason = s.npcs[i].questionReason ?? .contraband
            }
        }
    }

    func talk(_ id: NPCID) {
        emit(.talked(id))
        let def = Cast.def(id)
        var icons: [Icon] = []
        var caption = ""
        if let line = Dialogue.line(for: id, game: self) {
            icons = line.icons
            caption = line.caption
        } else if def.role.isStaff {
            icons = [Schedule.icon(activity), .clock]
            caption = "\(activity.title) until \(Schedule.clockString(Double(currentBlock.end)))."
        } else {
            if let w = def.wants.first { icons = [Items.def(w).icon, .question] ; caption = "\(def.short) could use \(Items.def(w).name.lowercased())." }
            else { icons = [.happy]; caption = "\(def.short) nods." }
        }
        bubble(id, icons, seconds: 3, caption: caption)
        mumble(id)
        if settings.captions { ui.caption = "\(def.short): \(caption)"; ui.captionTime = 0 }
        if !def.role.isStaff { adjustPeer(id, (s.usedInteractions.contains("talk.\(id).\(s.day)") ? 0 : 1), silent: true) }
        s.usedInteractions.insert("talk.\(id).\(s.day)")
    }

    func climbHatch(_ objectID: String) {
        guard let (link, sideA) = Hatches.objects[objectID], let h = map.hatches.first(where: { $0.id == link }) else { return }
        guard ruleAllowsPlayer(h.rule) || s.player.escortedBy != nil else { toast(.key, "Locked — needs the utility key"); return }
        if s.player.vehicle != nil { parkVehicle() }
        let dest = sideA ? h.b : h.a
        s.player.pos = dest.center
        s.player.path = []
        ui.cameraSnap = true
        ui.districtFade = settings.reducedMotion ? 0 : 1
        sound(.hatch)
        outfitThroughHatch(objectID)
        makeNoise(at: dest.center, loudness: 3, suspicious: true, source: .player)
        if let z = map.zone(at: dest.center) { s.player.lastZone = z.id; s.player.lastDistrict = z.district; emit(.zoneEntered(z.id)) }
        stat("hatches")
    }

    // MARK: Context button target

    func updateInteractTarget() {
        if let q = ui.questionedBy { ui.contextTarget = .npc(q); return }
        if let h = s.player.hiddenIn { ui.contextTarget = .object(h); return }
        var best: (TargetRef, Double)?
        let facing = Vec2.fromAngle(s.player.heading)
        func consider(_ t: TargetRef, _ p: Vec2) {
            let d = targetDistance(t)
            guard d <= Game.interactRadius else { return }
            let dir = (p - s.player.pos).normalized
            let score = d - 0.6 * dir.dot(facing)
            if best == nil || score < best!.1 {
                if canInteract(with: t) { best = (t, score) }
            }
        }
        for n in s.npcs where n.present && n.pos.distance(to: s.player.pos) < 2 { consider(.npc(n.id), n.pos) }
        let pt = s.player.pos.tile
        for dy in -2...2 {
            for dx in -2...2 {
                if let o = map.object(at: TilePos(pt.x + dx, pt.y + dy)), isInteractable(o) {
                    consider(.object(o.id), o.center)
                }
            }
        }
        ui.contextTarget = best?.0
    }

    func isInteractable(_ o: WorldObject) -> Bool {
        if hideSpotByObject[o.id] != nil || stashByObject[o.id] != nil { return true }
        if Interactions.hasAny(for: o, map: map) { return true }
        switch o.kind {
        case .bunk, .locker, .shower, .sink, .tv, .phone, .medWindow, .commissary, .noticeBoard, .donationBox, .waterCooler, .piano:
            return true
        case .hatch, .culvert:
            if let (link, _) = Hatches.objects[o.id], let h = map.hatches.first(where: { $0.id == link }) { return h.discoveredBy.map { has($0) } ?? true }
            return false
        default:
            if let job = s.player.job, Jobs.def(job).stationObject == o.id { return true }
            return false
        }
    }
}

extension Game {
    /// Today's open appointment with this person, during its window (15 minutes early is fine).
    func appointmentFor(_ id: NPCID) -> Appointment? {
        let m = Int(s.minute)
        return s.appointments.first { $0.npc == id && $0.day == s.day && !$0.attended && m >= $0.start - 15 && m < $0.end }
    }
}
