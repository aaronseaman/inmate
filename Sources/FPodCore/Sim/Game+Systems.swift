import Foundation

extension Vehicle {
    /// Zone classes this equipment may be taken into.
    public var allowed: Set<ZoneClass> {
        switch self {
        case .janitorCart: return [.home, .transit, .closet, .service, .work, .dining, .program, .medical, .adminPublic]
        case .laundryCart: return [.home, .transit, .service, .work, .dining, .closet]
        case .wheelchair: return [.home, .transit, .dining, .program, .medical, .adminPublic, .yard]
        case .floorBuffer: return [.home, .transit, .dining, .closet, .program]
        }
    }
    /// Where it goes back to when parked.
    public var bay: String {
        switch self {
        case .janitorCart: return "cartbay.janitorcart"
        case .laundryCart: return "cartbay.laundrycart"
        case .wheelchair: return "infirmary.ramp"
        case .floorBuffer: return "fpod.closet.mop"
        }
    }
}

extension Game {
    // MARK: Vehicles

    func setVehicle(_ v: Vehicle?) {
        let before = s.player.vehicle
        s.player.vehicle = v
        s.player.mode = .walk
        s.player.sneakToggle = false
        s.player.runToggle = false
        if let v = v {
            toast(v.icon, "\(v.title): tap the floor to steer · Park from the button")
            sound(v == .floorBuffer ? .buzzer : .cartWheels, volume: 0.6)
            stat("vehicles")
        } else if let b = before {
            toast(b.icon, "Parked the \(b.title.lowercased())")
            sound(.clank, volume: 0.5)
            // Overflow items ride back with the cart; nothing is silently lost.
            settleOverflowAfterParking(b)
        }
    }

    public func parkVehicle() {
        guard s.player.vehicle != nil else { return }
        stopWalking()
        setVehicle(nil)
    }

    /// Carts carry extra bulk; parking returns anything that no longer fits to the bay.
    func settleOverflowAfterParking(_ v: Vehicle) {
        var overflow: [ItemStack] = []
        while s.inventory.carriedBulk > carryCapacity, let last = s.inventory.carried.last {
            overflow.append(last)
            s.inventory.carried.removeLast()
        }
        if !overflow.isEmpty {
            s.stashes[v.bay, default: []] += overflow
            toast(.box, "Extra load left on the \(v.title.lowercased()) at its bay")
        }
    }

    /// Equipment stays out of cells, offices and secure rooms.
    func vehicleMayEnter(_ z: ZoneDef?) -> Bool {
        guard let v = s.player.vehicle, let z = z else { return true }
        var cls = z.cls
        if cls == .cell && z.id == "fpod.cell\(s.player.cell)" { cls = .ownCell }
        return v.allowed.contains(cls)
    }

    func vehicleBlocksDoor(_ d: DoorDef) -> Bool {
        guard s.player.vehicle != nil else { return false }
        let (a, b) = doorSides(d)
        return !vehicleMayEnter(a) || !vehicleMayEnter(b)
    }

    /// Floor-buffer and cart collisions: a bump, a stumble, and — if staff see it — an incident.
    func updateVehicleCollisions(_ dt: Double) {
        guard let v = s.player.vehicle, s.player.moving else { return }
        vehicleBumpCooldown = max(0, vehicleBumpCooldown - dt)
        guard vehicleBumpCooldown <= 0 else { return }
        let reach = v == .floorBuffer ? 0.75 : 0.6
        guard let i = s.npcs.indices.first(where: { s.npcs[$0].present && s.npcs[$0].pos.distance(to: s.player.pos) < reach }) else { return }
        vehicleBumpCooldown = 3
        bufferSeconds = 0
        let id = s.npcs[i].id
        let push = (s.npcs[i].pos - s.player.pos).normalized * 0.5
        let dest = s.npcs[i].pos + push
        if map.walkableStatic(dest.tile) { s.npcs[i].pos = dest }
        bubble(id, [.exclaim, .angry], seconds: 2, caption: "Watch it!")
        sound(.thud)
        haptic(.medium)
        makeNoise(at: s.player.pos, loudness: 6, suspicious: true, source: .player)
        stopWalking()
        let def = Cast.def(id)
        if def.role.isStaff {
            adjustStaff(id, -3)
            witnessCheck(.equipmentCollision)
        } else {
            adjustPeer(id, -3)
            if v == .floorBuffer { witnessCheck(.equipmentCollision) }
        }
    }

    // MARK: Meals

    func eatMeal() {
        let key = "meal.d\(s.day).\(activity.rawValue)"
        guard !s.usedInteractions.contains(key) else { toast(.meal, "Already ate this meal"); return }
        s.usedInteractions.insert(key)
        s.mealsToday += 1
        let soup = Systems.flavor(day: s.day, seed: s.seed) == .soupDay && activity == .chow
        s.player.energy = min(100, s.player.energy + (soup ? 30 : 18))
        toast(.meal, ["Oatmeal and an orange", "Soup. Odell is proud of the soup.", "Mystery casserole", "Chili mac"][(s.day + Int(s.minute)) % 4])
        sound(.clank, volume: 0.4)
        outfitAtMeal(soup: soup)
        stat("meals")
    }

    // MARK: Queued decisions

    /// Shows queued choices one at a time once the screen is free.
    func presentPendingChoices() {
        guard ui.modal == nil, transition == nil, minigame == nil, !s.pendingChoices.isEmpty else { return }
        let c = s.pendingChoices.removeFirst()
        ui.modal = .choice(c)
        sound(.question, volume: 0.6)
    }

    // MARK: Appointment staging

    /// Where the other person waits for each appointment (the player's spot is on the appointment).
    static let appointmentStaging: [String: String] = [
        "calloway.visit1": "visit.t1.out", "calloway.visit2": "visit.t1.out", "nadia.visit": "visit.t2.out",
        "review.hearing": "hearing.panel.1", "release.hearing": "hearing.lawyer", "admin.meeting": "admin.chair",
        "cole.mediate": "group.lead", "sato.meds": "sato.seat", "sato.review": "sato.seat", "pruitt.records": "clerk.pruitt",
    ]

    /// Visitors arrive for their window and leave after; staff walk to the room and resume after.
    func stageAppointments() {
        let m = Int(s.minute)
        var wanted: [NPCID: String] = [:]
        for ap in s.appointments where ap.day == s.day && !ap.attended && m >= ap.start - 15 && m < ap.end {
            if let who = ap.npc, let spot = Game.appointmentStaging[ap.id] { wanted[who] = spot }
        }
        for i in s.npcs.indices {
            let id = s.npcs[i].id
            let def = Cast.def(id)
            let visitor = def.role == .lawyer || def.role == .family
            if let spot = wanted[id] {
                guard s.npcs[i].scriptedSpot != spot, let sp = map.spot(spot) else { continue }
                s.npcs[i].scriptedSpot = spot
                s.npcs[i].mode = .scripted
                s.npcs[i].postKey = ""
                if visitor { s.npcs[i].pos = sp.pos; s.npcs[i].heading = sp.facing.angle; s.npcs[i].present = true; s.npcs[i].path = [] }
            } else if let sp = s.npcs[i].scriptedSpot, Game.appointmentStaging.values.contains(sp), transition == nil {
                s.npcs[i].scriptedSpot = nil
                if visitor { s.npcs[i].present = false; s.npcs[i].mode = .routine } else { s.npcs[i].mode = .resume; s.npcs[i].postKey = "" }
            }
        }
    }

    // MARK: Riders and timed equipment work

    /// Abe rides in his own chair; the player pushes from behind.
    func updateRiders(_ dt: Double) {
        if has(.abeRiding), s.player.vehicle == .wheelchair {
            let ahead = s.player.pos + Vec2.fromAngle(s.player.heading, 0.7)
            withNPC(.abe) { n in
                n.pos = map.walkableStatic(ahead.tile) ? ahead : s.player.pos
                n.heading = s.player.heading
                n.mode = .scripted
                n.scriptedSpot = nil
                n.path = []
                n.moving = s.player.moving
            }
        } else if has(.abeRiding) && s.player.vehicle == nil {
            s.flags.remove(.abeRiding)
            withNPC(.abe) { n in n.mode = .resume; n.postKey = "" }
        }
        // Inspection buffing: twenty clean seconds in the dayroom.
        if s.player.vehicle == .floorBuffer, s.player.moving, map.zone(at: s.player.pos)?.id == "fpod.dayroom", questActive(.sBuffer), !has(.bufferDone) {
            bufferSeconds += dt
            if bufferSeconds >= 20 {
                apply([.set(.bufferDone), .credits(5, "Inspection buffing"), .staff(.haskins, 4), .toast(.buffer, "The dayroom shines. Haskins nods.")])
            }
        }
    }
}
