import Foundation

public struct RecoveryTask: Codable, Hashable {
    public var text: String
    public var npc: NPCID
    public var icon: Icon
    public var fromIncident: IncidentKind
    public var day: Int
}

public struct CaptureReport: Hashable {
    public var witness: NPCID
    public var reason: IncidentKind
    public var searched: [String]
    public var confiscated: [ItemStack]
    public var consequence: String
    public var recovery: String
}

extension Game {
    /// A staff member who can currently see the player witnesses an act.
    func witnessCheck(_ kind: IncidentKind, item: ItemID? = nil) {
        var any = false
        for i in s.npcs.indices where s.npcs[i].present {
            let def = Cast.def(s.npcs[i].id)
            guard def.role.isStaff, npcCanSeePlayer(s.npcs[i], def) else { continue }
            any = true
            s.npcs[i].suspicion = 100
            s.npcs[i].questionReason = kind
            s.npcs[i].lastKnown = s.player.pos
            s.npcs[i].reacting = Game.reactionDelay
            s.npcs[i].bubble = [.exclaim, .hand]
            s.npcs[i].bubbleTimer = 2
        }
        if any {
            haptic(.error)
            sound(.alert)
            log("Witnessed: \(kind.title)")
        } else {
            // Cameras catch acts too, with less certainty.
            for c in map.cameras {
                let d = s.player.pos - c.pos
                if d.length <= c.range && abs(angleDiff(d.angle, cameraHeading(c))) <= c.fov / 2 && Sight.clear(map, c.pos, s.player.pos, opaque: { self.opaque($0) }) {
                    cameraSuspicion[c.id] = min(100, (cameraSuspicion[c.id] ?? 0) + 45)
                    cameraLastKnown = s.player.pos
                }
            }
        }
    }

    func logIncident(_ kind: IncidentKind, witness: NPCID?, outcome: String) {
        let zone = map.zone(at: s.player.pos)?.id ?? s.player.lastZone
        s.incidents.append(Incident(kind: kind, day: s.day, minute: Int(s.minute), witness: witness, zone: zone, outcome: outcome))
        if s.incidents.count > 120 { s.incidents.removeFirst(s.incidents.count - 120) }
        stat("incident.\(kind.rawValue)")
    }

    func recentIncidents(minSeverity: Int, days: Int = 3) -> Int {
        s.incidents.filter { $0.kind.severity >= minSeverity && $0.day > s.day - days }.count
    }

    /// Full capture: search, confiscate only what was found where they looked, consequence, recovery.
    public func captured(by witness: NPCID, reason: IncidentKind) {
        guard transition == nil else { return }
        stopWalking()
        if s.player.hiddenIn != nil { exitHide() }
        ui.questionedBy = nil
        ui.modal = nil
        s.player.escortedBy = nil
        s.player.changing = 0
        let level = reason.severity >= 2 || reason == .contraband ? 2 : 1
        var found = searchPerson(level: level)
        var searchedPlaces = ["Pockets", "Carried items"]
        if level >= 2 { searchedPlaces.append("Sock") }
        var effective = reason
        if found.contains(where: { Items.def($0.id).legality == .dangerous }) { effective = .dangerousItem } else if found.contains(where: { Items.def($0.id).legality >= .contraband }) && reason.severity < 2 {
            effective = .contraband
        }
        var stashSearched: [String] = []
        if effective.severity >= 2 || !found.isEmpty {
            let r = searchCell(s.player.cell, thorough: effective.severity >= 3)
            stashSearched = r.searched
            found += r.found
        }
        s.lastSearch = stashSearched
        searchedPlaces += stashSearched.compactMap { stashByObject[$0]?.title }
        confiscate(found)
        let consequence = applyConsequence(for: effective, witness: witness, searched: true)
        logIncident(effective, witness: witness, outcome: consequence)
        emit(.caught(effective))
        stat("captures")
        // Critical items lost: open a recovery route.
        let criticalLost = found.filter { Items.def($0.id).critical }
        for st in criticalLost { Story.criticalItemLost(self, st.id) }
        let recovery = assignRecovery(for: effective)
        let report = CaptureReport(witness: witness, reason: effective, searched: searchedPlaces, confiscated: found,
                                   consequence: consequence, recovery: recovery)
        haptic(.error)
        transition = Scenes.capture(self, report)
    }

    /// Proportionate consequence. Returns a concise description.
    @discardableResult
    func applyConsequence(for kind: IncidentKind, witness: NPCID?, searched: Bool) -> String {
        let repeatCount = recentIncidents(minSeverity: max(1, kind.severity))
        var parts: [String] = []
        let w = witness ?? .haskins
        let abusive = Cast.def(w).abusive
        switch kind.severity {
        case 0:
            adjustStaff(w, -2)
            parts.append("Warning")
        case 1:
            adjustTrust(-2, kind.title)
            adjustStaff(w, -2)
            parts.append("Warning, escorted back")
            if repeatCount >= 2 {
                s.restrictions[.noYard] = s.absMinute + 24 * 60
                parts.append("No yard 24h")
            }
        case 2:
            if kind == .missedCount {
                let misses = s.missedCounts.filter { $0 > s.day - 3 }.count
                adjustTrust(-6, "Missed count")
                if misses >= 3 { setWatch(.red, hours: 24, reason: "Repeatedly missed count"); parts.append("Red watch 24h") } else if misses >= 2 {
                    setWatch(.yellow, hours: 24, reason: "Missed count twice"); parts.append("Yellow watch 24h")
                } else { parts.append("Warning on record") }
            } else {
                adjustTrust(-8, kind.title)
                adjustStaff(w, -4)
                if s.player.job != nil {
                    s.restrictions[.noJob] = Double(s.day + 1) * 1440 + 360
                    parts.append("Lost today's shift")
                }
                if repeatCount >= 2 || abusive && kind == .contraband {
                    setWatch(.red, hours: 24, reason: kind.title)
                    parts.append("Red watch 24h")
                } else {
                    setWatch(.yellow, hours: 24, reason: kind.title)
                    parts.append("Yellow watch 24h")
                }
                s.restrictions[.noCommissary] = s.absMinute + 24 * 60
            }
        default:
            adjustTrust(-15, kind.title)
            adjustStaff(w, -8)
            s.watch72 = true
            s.flags.remove(.watch72Reviewed)
            setWatch(.red, hours: 72, reason: kind.title)
            setFlag(.watch72Assigned)
            parts.append("72-hour watch (review available)")
            parts.append("Seclusion")
        }
        return parts.joined(separator: " · ")
    }

    func assignRecovery(for kind: IncidentKind) -> String {
        let task: RecoveryTask
        switch kind.severity {
        case 0, 1:
            task = RecoveryTask(text: "Check in with Tech Cole about it", npc: .cole, icon: .favor, fromIncident: kind, day: s.day)
        case 2:
            task = RecoveryTask(text: "Talk it through with Tech Cole", npc: .cole, icon: .favor, fromIncident: kind, day: s.day)
        default:
            task = RecoveryTask(text: "Watch review: group, a clean shift, then Dr. Sato", npc: .sato, icon: .eye, fromIncident: kind, day: s.day)
        }
        s.recovery = task
        return task.text
    }

    /// Called when the player completes the recovery conversation.
    func completeRecovery() {
        guard let r = s.recovery else { return }
        s.recovery = nil
        adjustTrust(2, "Owned the incident")
        if s.watch != .green && !s.watch72 {
            // Early review halves what remains.
            let remaining = s.watchUntil - s.absMinute
            s.watchUntil = s.absMinute + remaining / 2
            toast(.eye, "Watch time halved after review")
        }
        log("Recovery: \(r.text)")
    }

    /// After a capture scene: place the player safely and calm everyone down.
    func afterCapture(_ report: CaptureReport) {
        let severe = report.reason.severity >= 3
        if let sp = map.spot("fpod.cell\(s.player.cell).bunkA") { s.player.pos = sp.pos }
        s.player.path = []
        s.player.vehicle = nil
        s.player.caughtImmunity = 180
        s.player.lastZone = "fpod.cell\(s.player.cell)"
        for i in s.npcs.indices {
            s.npcs[i].suspicion = 0
            s.npcs[i].questionReason = nil
            s.npcs[i].lastKnown = nil
            s.npcs[i].radioed = false
            s.npcs[i].sawPlayerEnterHide = nil
            if s.npcs[i].mode != .scripted { s.npcs[i].mode = .resume; s.npcs[i].postKey = ""; s.npcs[i].path = [] }
        }
        cameraSuspicion = [:]
        s.facilityAlert = 0
        if s.player.outfit != .tanScrubs {
            // Unauthorized clothing is taken; the player gets scrubs back.
            s.confiscated.append(ItemStack(s.player.outfit.item, 1))
            s.player.outfit = .tanScrubs
            s.player.outfitCondition = 100
        }
        audioCommands.append(.music(.quiet))
        if severe { setFlag(.seclusionEventSeen) }
        refreshDoors(instant: true)
        ui.camera = s.player.pos
        saveRequested = true
    }

    // MARK: Relationship helpers

    func adjustTrust(_ delta: Int, _ reason: String) {
        var d = delta
        if d > 0 {
            // Cap repetitive farming per day.
            let cap = 12
            d = min(d, max(0, cap - s.trustGainedToday))
            s.trustGainedToday += d
        }
        guard d != 0 else { return }
        let before = trustTier
        s.trust = max(0, s.trust + d)
        // A single minor mistake never drops a whole tier: floor follows the highest tier reached minus hysteresis.
        let reached = Game.tier(for: s.trust)
        if reached > s.trustTierFloor { s.trustTierFloor = reached }
        if d < 0 && s.trust < Game.tierThresholds[s.trustTierFloor - 1] - 30 {
            s.trustTierFloor = max(1, Game.tier(for: s.trust))
        }
        let after = trustTier
        if after > before { toast(.trust, "Trust tier \(after) — new eligibility"); sound(.success) } else if after < before {
            toast(.trust, "Trust tier dropped to \(after)", danger: true)
        }
    }

    func adjustStaff(_ id: NPCID, _ delta: Int) {
        s.staffOpinion[id] = clamp((s.staffOpinion[id] ?? 0) + delta, -100, 100)
    }

    func adjustPeer(_ id: NPCID, _ delta: Int, silent: Bool = false) {
        let before = s.peerRep[id] ?? 0
        s.peerRep[id] = clamp(before + delta, -100, 100)
        if !silent && delta != 0 {
            toast(delta > 0 ? .heart : .thumbsDown, "\(Cast.def(id).short) \(delta > 0 ? "+" : "")\(delta)")
        }
    }
}
