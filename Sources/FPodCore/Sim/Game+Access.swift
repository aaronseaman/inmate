import Foundation

extension Game {
    // MARK: Doors

    func ruleAllowsPlayer(_ rule: AccessRule, door: DoorDef? = nil) -> Bool {
        switch rule {
        case .open: return true
        case .never: return false
        case .staff: return false
        case .schedule(let acts):
            if s.lockdown { return false }
            if acts.contains(activity) { return watchAllows(door) }
            // An appointment opens the way to it — not every scheduled door on campus.
            if let ap = appointmentActive, let d = door { return appointmentOpens(d, ap) }
            return false
        case .key(let item): return s.inventory.count(item) > 0
        case .flag(let f): return has(f)
        case .job(let j): return playerOnShift(j)
        case .trust(let n): return trustTier >= n
        case .any(let rs): return rs.contains { ruleAllowsPlayer($0, door: door) }
        case .all(let rs): return rs.allSatisfy { ruleAllowsPlayer($0, door: door) }
        }
    }

    /// Free periods when watch limits movement to the pod.
    static let freeMovement: Set<Activity> = [.afternoon, .freeTime]

    /// Behavioral watch narrows scheduled movement: yellow keeps free periods in the pod;
    /// red also closes the yard. Programs, meals, work and appointments stay reachable.
    func watchAllows(_ door: DoorDef?) -> Bool {
        guard s.watch != .green, let d = door else { return true }
        let (a, b) = doorSides(d)
        if s.watch == .red && (a?.district == .yard || b?.district == .yard) { return false }
        if Game.freeMovement.contains(activity) && appointmentActive == nil {
            let inPod = (a?.district ?? .fpod) == .fpod && (b?.district ?? .fpod) == .fpod
            return inPod
        }
        return true
    }

    /// Does any schedule clause in this rule cover the current block?
    func scheduleOpenNow(_ r: AccessRule) -> Bool {
        switch r {
        case .schedule(let acts): return acts.contains(activity)
        case .any(let rs), .all(let rs): return rs.contains { scheduleOpenNow($0) }
        default: return false
        }
    }

    func appointmentOpens(_ d: DoorDef, _ ap: Appointment) -> Bool {
        let target = map.spot(ap.spot).flatMap { map.zone(at: $0.pos) }
        let (a, b) = doorSides(d)
        for z in [a, b].compactMap({ $0 }) {
            if z.cls == .transit || isPodHome(z) || z.district == target?.district { continue }
            return false
        }
        return true
    }

    func ruleAllowsNPC(_ rule: AccessRule, _ def: NPCDef) -> Bool {
        if def.role.isStaff || def.role == .lawyer || def.role == .family {
            if case .never = rule { return false }
            return true
        }
        // Peers follow their own routines; a door that patients ever use on schedule
        // never traps them (staff let them through). Staff-only and keyed doors stay shut.
        return patientUsable(rule, def)
    }

    func patientUsable(_ rule: AccessRule, _ def: NPCDef) -> Bool {
        switch rule {
        case .open, .schedule, .trust: return true
        case .never, .staff, .key: return false
        case .flag(let f): return has(f)
        case .job(let j): return def.job == j
        case .any(let rs): return rs.contains { patientUsable($0, def) }
        case .all(let rs): return rs.allSatisfy { patientUsable($0, def) }
        }
    }

    /// Zones on either side of a door.
    func doorSides(_ d: DoorDef) -> (ZoneDef?, ZoneDef?) {
        let a = d.vertical ? TilePos(d.tile.x - 1, d.tile.y) : TilePos(d.tile.x, d.tile.y - 1)
        let b = d.vertical ? TilePos(d.tile.x + 1, d.tile.y) : TilePos(d.tile.x, d.tile.y + 1)
        return (map.zone(at: a), map.zone(at: b))
    }

    func isPodHome(_ z: ZoneDef?) -> Bool {
        guard let z = z else { return false }
        return z.district == .fpod && z.cls == .home
    }

    /// Doors never trap the player: you can always head back into F-Pod (staff buzz you in),
    /// always step into your own cell, and always leave a restricted room you are standing in.
    /// Confinement still applies to the pod and to cells. Suspicion, not locks, polices presence.
    func doorExitException(_ d: DoorDef) -> Bool {
        if d.id == "fence.gap" || d.kind == .gate && d.id.hasPrefix("gate.") { return false }
        let (a, b) = doorSides(d)
        let here = map.zone(at: s.player.pos) ?? map.zone(id: s.player.lastZone)
        if d.kind == .cell {
            let own = "fpod.cell\(s.player.cell)"
            return (a?.id == own || b?.id == own) && here?.id != own
        }
        let hereHome = isPodHome(here)
        if !hereHome && (isPodHome(a) || isPodHome(b)) { return true }
        if let h = here, h.id == a?.id || h.id == b?.id {
            switch h.cls {
            case .home, .ownCell, .cell, .transit: return false
            default: return true
            }
        }
        return false
    }

    public func playerCanPass(doorIndex d: Int) -> Bool {
        let door = map.doors[d]
        if door.id == "fence.gap" { return ruleAllowsPlayer(door.rule, door: door) }
        if s.player.escortedBy != nil { return true }
        return ruleAllowsPlayer(door.rule, door: door) || doorExitException(door)
    }

    /// Strict rule check (no exit/homeward exception) — used for "is this open to you" displays.
    public func playerHasAccess(doorIndex d: Int) -> Bool { ruleAllowsPlayer(map.doors[d].rule, door: map.doors[d]) }

    func playerCanPassTile(_ i: Int) -> Bool {
        let d = map.doorAt[i]
        guard d >= 0 else { return true }
        if vehicleBlocksDoor(map.doors[Int(d)]) { return false }
        return playerCanPass(doorIndex: Int(d))
    }

    func npcCanPassTile(_ i: Int, _ def: NPCDef) -> Bool {
        let d = map.doorAt[i]
        if d < 0 { return true }
        let door = map.doors[Int(d)]
        if door.id == "fence.gap" { return false }
        return ruleAllowsNPC(door.rule, def)
    }

    /// Human-readable requirement for a locked door (icon + concise text).
    public func doorRequirement(_ door: DoorDef) -> (Icon, String) {
        func describe(_ r: AccessRule) -> [(Icon, String)] {
            switch r {
            case .open: return []
            case .never: return [(.lock, "Sealed")]
            case .staff: return [(.badge, "Staff credential")]
            case .schedule(let acts):
                let names = acts.prefix(3).map { $0.title }.joined(separator: ", ")
                return [(.clock, "Open during: \(names)\(acts.count > 3 ? "…" : "")")]
            case .key(let i): return [(.key, Items.def(i).name)]
            case .flag(let f): return [(.flag, FlagText.requirement(f))]
            case .job(let j): return [(.work, "\(Jobs.def(j).title) shift")]
            case .trust(let n): return [(.trust, "Trust tier \(n)")]
            case .any(let rs): return rs.flatMap { describe($0) }.filter { $0.1 != "Staff credential" || rs.count == 1 }
            case .all(let rs): return rs.flatMap { describe($0) }
            }
        }
        if let v = s.player.vehicle, vehicleBlocksDoor(door) { return (v.icon, "Park the \(v.title.lowercased()) first") }
        if scheduleOpenNow(door.rule), !s.lockdown, !watchAllows(door) {
            return (.eye, s.watch == .red ? "Red watch: no yard, free time in the pod" : "Yellow watch: free time in the pod")
        }
        let parts = describe(door.rule)
        if parts.isEmpty { return (.lock, "Locked") }
        let joiner: String
        if case .all = door.rule { joiner = " + " } else { joiner = " or " }
        return (parts[0].0, parts.map { $0.1 }.joined(separator: joiner))
    }

    func refreshDoors(instant: Bool, dt: Double = 0) {
        for (i, d) in map.doors.enumerated() {
            let c = d.tile.center
            var want = false
            let pd = s.player.pos.distance(to: c)
            if pd < 1.25 && s.player.hiddenIn == nil && playerCanPass(doorIndex: i) && (s.player.moving || pd < 0.75) { want = true }
            if !want {
                for n in s.npcs where n.present {
                    let dd = n.pos.distance(to: c)
                    if dd < 1.25 && (n.moving || dd < 0.75) {
                        if npcCanPassTile(map.idx(d.tile), Cast.def(n.id)) { want = true; break }
                    }
                }
            }
            if d.kind == .gate && d.id == "yard.gate" && activity == .rec && !s.lockdown { want = true }
            let target = want ? 1.0 : 0.0
            let before = doorOpen[i]
            doorOpen[i] = instant ? target : approach(doorOpen[i], target, dt * 4)
            let opaque = doorOpen[i] < 0.5 && d.kind != .gate
            dynamicOpaque[map.idx(d.tile)] = opaque
            if !instant && before < 0.05 && doorOpen[i] >= 0.05 && s.player.pos.distance(to: c) < 12 {
                sound(d.kind == .secure || d.kind == .cell ? .doorLock : .door, at: c, volume: 0.5)
            }
        }
    }

    func doorClosed(_ tileIndex: Int) -> Bool {
        let d = map.doorAt[tileIndex]
        return d >= 0 && doorOpen[Int(d)] < 0.5
    }

    func opaque(_ i: Int) -> Bool {
        let k = map.kinds[i]
        if k == .wall || k == .void { return true }
        if k == .woods { return false }
        return dynamicOpaque[i]
    }

    // MARK: Jobs & appointments

    func playerOnShift(_ j: JobID) -> Bool {
        guard s.player.job == j, s.restrictions[.noJob].map({ $0 <= s.absMinute }) ?? true else { return false }
        switch activity {
        case .work, .afternoon: return true
        case .breakfast, .chow, .dinner, .brunch: return j == .kitchen
        default: return false
        }
    }

    public var appointmentActive: Appointment? {
        let m = Int(s.minute)
        return s.appointments.first { $0.day == s.day && m >= $0.start - 10 && m < $0.end && !$0.attended }
    }

    static func jobForZone(_ id: String) -> JobID? {
        if id.hasPrefix("kitchen.") && id != "kitchen.dining" { return .kitchen }
        switch id {
        case "voc.laundry", "voc.cartbay", "voc.cold": return .laundry
        case "voc.workshop", "voc.sewing": return .workshop
        case "support.library", "support.lawlib": return .library
        case "support.infirmary", "support.ante": return .infirmary
        case "grounds.lawn", "yard": return .grounds
        case "fpod.closet": return .janitorial
        default: return nil
        }
    }

    // MARK: Presence

    /// Whether a patient in tan scrubs is allowed in this zone right now.
    public func patientAllowed(_ z: ZoneDef) -> Bool {
        let a = activity
        if z.id == "fpod.cell\(s.player.cell)" { return true }
        if s.player.escortedBy != nil { return true }
        if let ap = appointmentActive, let sp = map.spot(ap.spot), let az = map.zone(at: sp.pos) {
            if az.id == z.id || z.cls == .transit || z.cls == .adminPublic { return true }
        }
        if a == .lightsOut || a == .sleep { return false }
        let job = s.player.job
        let zoneJob = Game.jobForZone(z.id)
        if let zj = zoneJob, zj == job, playerOnShift(zj) { return true }
        if job == .janitorial && playerOnShift(.janitorial) && (z.cls == .transit || z.cls == .home || z.cls == .closet || z.cls == .dining || z.cls == .adminPublic) { return true }
        if job == .laundry && playerOnShift(.laundry) && (z.cls == .transit || z.cls == .service) { return true }
        if job == .infirmary && playerOnShift(.infirmary) && (z.cls == .transit || z.cls == .medical) { return true }
        if z.id == "support.lawlib" && has(.libraryCardIssued) && [.afternoon, .freeTime].contains(a) { return true }
        switch z.cls {
        case .ownCell, .home: return true
        case .cell: return false
        case .closet: return false
        case .transit:
            if a.podLocked { return false }
            return true
        case .dining: return [.breakfast, .chow, .dinner, .brunch].contains(a)
        case .yard:
            if let until = s.restrictions[.noYard], until > s.absMinute { return false }
            return a == .rec
        case .work: return false
        case .program:
            if z.id == "support.group" { return [.therapy, .afternoon, .freeTime].contains(a) }
            if z.id == "admin.hearing" { return a == .review || has(.advocacyMeeting) }
            return [.afternoon, .freeTime, .chapel, .visiting].contains(a)
        case .medical: return a == .afternoon || a == .medPass
        case .isolation: return false
        case .adminPublic: return [.afternoon, .freeTime, .visiting, .review].contains(a)
        case .records: return [.afternoon, .freeTime].contains(a)
        case .staffOnly, .secure, .restricted, .service, .perimeter: return false
        }
    }

    /// Whether the worn outfit makes this zone plausible for a stranger.
    public func disguisePlausible(_ z: ZoneDef) -> Bool {
        let o = s.player.outfit
        guard o != .tanScrubs else { return false }
        guard o.plausibleIn.contains(z.cls) else { return false }
        let m = Int(s.minute)
        switch o {
        case .kitchenWhites: return m >= 360 && m < 1140
        case .laundryWhites: return [.work, .afternoon].contains(activity)
        case .visitor: return [.visiting, .freeTime, .afternoon].contains(activity)
        case .whiteCoat: return m >= 480 && m < 1080
        case .chaplain: return m >= 540 && m < 1140
        case .ppe: return has(.ppeRouteKnown)
        default: return true
        }
    }

    static func restrictedRate(_ cls: ZoneClass) -> Double {
        switch cls {
        case .cell: return 3
        case .closet: return 10
        case .transit: return 5
        case .dining, .yard, .adminPublic: return 6
        case .work, .medical: return 8
        case .program: return 5
        case .records: return 10
        case .isolation: return 15
        case .staffOnly: return 15
        case .secure: return 30
        case .restricted: return 25
        case .service: return 18
        case .perimeter: return 40
        case .home, .ownCell: return 25
        }
    }

    func isFamiliar(_ id: NPCID) -> Bool {
        let def = Cast.def(id)
        return def.familiar || s.metStaff.contains(id)
    }

    func recognitionRange(observer: NPCDef) -> Double {
        let o = s.player.outfit
        guard o != .tanScrubs else { return 0 }
        var r = 1.2 + 2.6 * o.inspectionRisk
        r += (100 - s.player.outfitCondition) / 100 * 1.6
        if o.supportingProps.contains(where: { s.inventory.count($0) > 0 }) { r *= 0.7 }
        r *= 0.7 + 0.5 * observer.strictness
        return r
    }
}

public enum FlagText {
    public static func requirement(_ f: Flag) -> String {
        switch f {
        case .libraryCardIssued: return "Library card"
        case .ppeRouteKnown: return "Isolation route authorization"
        case .lawyerVisitScheduled: return "Scheduled appointment"
        case .advocacyMeeting: return "Advocacy meeting"
        case .escapeStarted: return "The escape is underway"
        case .tunnelHatchKnown: return "Know where the hatch leads"
        default: return "Story condition"
        }
    }
}
