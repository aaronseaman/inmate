import XCTest
@testable import FPodCore

/// The systems a player lives with after day 1: work, favors, equipment, watch, supplies.
final class SystemsTests: XCTestCase {
    /// Day 2 with intake behind you, at `minute`.
    func day2(_ minute: Double, seed: UInt64 = 42) -> Game {
        let g = makeGame(seed: seed)
        g.s.flags.formUnion([.claimedBunk, .readChart, .firstCountDone, .metDutch, .trialDone, .jobTrialDone])
        g.apply([.completeQuest(.m01Intake), .completeQuest(.m02Ally)])
        g.startNewDay()
        setClock(g, minute)
        sim(g, seconds: 1)
        return g
    }

    /// Plays the open minigame to the end with its bot, then continues.
    @discardableResult
    func playOut(_ g: Game) -> Double {
        guard let mg = g.minigame else { return -1 }
        g.minigameAction(.minigameStart)
        var t = 0.0, last = -1.0
        while mg.phase == .playing && t < 400 {
            g.update(dt: 1.0 / 30.0)
            if t - last > 0.16, let p = mg.game.botTap(canvas: g.minigameCanvas) { g.tap(p); last = t }
            t += 1.0 / 30.0
        }
        let score = mg.finalScore
        g.minigameAction(.minigameContinue)
        g.update(dt: 1.0 / 30.0)
        return score
    }

    /// Walks to a person and checks an option is offered, then performs it.
    @discardableResult
    func use(_ g: Game, _ t: TargetRef, _ option: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        engageAndWait(g, t, timeout: 90)
        let ids = g.fanOptionIDs()
        guard ids.contains(option) || g.options(for: t).contains(where: { $0.id == option && $0.enabled }) else {
            XCTFail("\(option) not offered at \(t); got \(ids.isEmpty ? g.options(for: t).map { $0.id } : ids) at \(Schedule.clockString(g.s.minute)) player \(g.s.player.pos)", file: file, line: line)
            g.ui.modal = nil
            return false
        }
        g.perform(option, on: t)
        return true
    }

    func testEveryJobIsReachableThroughATryout() {
        let jobs: [JobID] = [.kitchen, .laundry, .library, .workshop, .grounds]
        for job in jobs {
            let g = day2(785)
            let d = Jobs.def(job)
            XCTAssertFalse(g.eval(d.eligibility), "\(job) should start closed")
            guard use(g, .npc(d.supervisor), "c.job.\(job.rawValue).tryout") else { continue }
            XCTAssertNotNil(g.minigame, "\(job) tryout should start a minigame")
            playOut(g)
            XCTAssertTrue(g.eval(d.eligibility), "\(job) tryout didn't open eligibility")
            g.perform("c.job.\(job.rawValue).apply", on: .npc(d.supervisor))
            XCTAssertEqual(g.s.player.job, job)
            if let u = d.uniform { XCTAssertGreaterThan(g.s.inventory.count(u.item), 0, "\(job) uniform not issued") }
        }
    }

    func testInfirmaryNeedsTrustBeforeATryout() {
        let g = day2(785)
        XCTAssertFalse(g.options(for: .npc(.okonjo)).contains { $0.id == "c.job.infirmary.tryout" })
        g.s.trust = 45
        XCTAssertTrue(g.options(for: .npc(.okonjo)).contains { $0.id == "c.job.infirmary.tryout" })
    }

    func testJanitorialAfterTrialAndCartAccess() {
        let g = day2(785)
        XCTAssertTrue(use(g, .npc(.haskins), "c.job.janitorial.ask"))
        XCTAssertEqual(g.s.player.job, .janitorial)
        XCTAssertGreaterThan(g.s.inventory.count(.janitorKey), 0)
        // Equipment: mount, steer, park.
        g.apply([.teleport("cartbay.drive")])
        XCTAssertTrue(use(g, .object("cartbay.janitorcart"), "c.vehicle.janitor"))
        XCTAssertEqual(g.s.player.vehicle, .janitorCart)
        XCTAssertEqual(g.carryCapacity, Inventory.carryCapacity + 4)
        g.perform(.park)
        XCTAssertNil(g.s.player.vehicle)
    }

    func testCartsStayOutOfCellsAndOffices() {
        let g = day2(785)
        g.s.player.vehicle = .janitorCart
        let cellDoor = g.map.doors.first { $0.kind == .cell }!
        XCTAssertTrue(g.vehicleBlocksDoor(cellDoor))
        let (icon, text) = g.doorRequirement(cellDoor)
        XCTAssertEqual(icon, .cart)
        XCTAssertTrue(text.contains("Park"))
        g.s.player.vehicle = nil
        XCTAssertFalse(g.vehicleBlocksDoor(cellDoor))
    }

    func testParkingReturnsOverflowToTheBay() {
        let g = day2(785)
        g.s.player.vehicle = .laundryCart
        for _ in 0..<5 { g.addItem(.book, 1, force: true) }   // 10 bulk: only fits with the cart
        let before = g.s.inventory.count(.book)
        g.parkVehicle()
        let after = g.s.inventory.count(.book)
        let bay = g.s.stashes["cartbay.laundrycart"]?.filter { $0.id == .book }.reduce(0) { $0 + $1.qty } ?? 0
        XCTAssertEqual(after + bay, before, "items must not vanish when parking")
        XCTAssertLessThanOrEqual(g.s.inventory.carriedBulk, Inventory.carryCapacity)
    }

    func testFavorsAreEarnedAndSpent() {
        let g = day2(785)
        g.s.favors[.mouse] = 1
        XCTAssertTrue(g.options(for: .npc(.mouse)).contains { $0.id == "c.favor.mouse" })
        g.perform("c.favor.mouse", on: .npc(.mouse))
        XCTAssertTrue(g.has(.tunnelHatchKnown))
        XCTAssertEqual(g.s.favors[.mouse] ?? 0, 0)
        XCTAssertFalse(g.options(for: .npc(.mouse)).contains { $0.id == "c.favor.mouse" }, "a favor is spent once")
    }

    func testEveryOutfitHasTwoRoutes() {
        // Static check of authored sources: job issue, favor, trade/choice, or stocked container.
        var routes: [ItemID: Set<String>] = [:]
        for i in Interactions.all {
            for e in flatten(i.effects) { if case .give(let item, _) = e, Outfit.from(item: item) != nil { routes[item, default: []].insert("i:\(i.id)") } }
        }
        for c in Choices.all { for o in c.options { for e in flatten(o.effects) { if case .give(let item, _) = e, Outfit.from(item: item) != nil { routes[item, default: []].insert("c:\(c.id)") } } } }
        for (container, items) in SupplyStashes.stock { for (item, _) in items where Outfit.from(item: item) != nil { routes[item, default: []].insert("s:\(container)") } }
        for j in JobID.allCases { if let u = Jobs.def(j).uniform { routes[u.item, default: []].insert("job:\(j)") } }
        routes[.laundryWhites, default: []].insert("seed:fpod.hamper")
        routes[.visitorClothes, default: []].insert("seed:donation.box")
        for o in Outfit.allCases where o != .tanScrubs {
            XCTAssertGreaterThanOrEqual(routes[o.item]?.count ?? 0, 2, "\(o) routes: \(routes[o.item] ?? [])")
        }
    }

    func flatten(_ es: [Effect]) -> [Effect] {
        es.flatMap { e -> [Effect] in
            switch e {
            case .minigame(_, _, _, let a, let b): return [e] + flatten(a) + flatten(b)
            case .ifThen(_, let a, let b): return [e] + flatten(a) + flatten(b)
            default: return [e]
            }
        }
    }

    func testRadioIsBuyableDespiteDailyCap() {
        let g = day2(785)
        g.s.trust = 45
        g.creditDelta(40, "test")
        XCTAssertTrue(g.buy(.radio), "the radio is a special order outside the daily cap")
        XCTAssertFalse(g.buy(.headphones), "one special order per day")
        XCTAssertTrue(g.buy(.snack))
    }

    func testCommissaryRequestUnlocksEarly() {
        let g = day2(785)
        XCTAssertFalse(g.commissaryEligible.0)
        g.addItem(.requestForm, 1, force: true)
        XCTAssertTrue(g.options(for: .npc(.pruitt)).contains { $0.id == "c.supply.commissary" })
        g.perform("c.supply.commissary", on: .npc(.pruitt))
        XCTAssertTrue(g.commissaryEligible.0)
    }

    func testSeventyTwoHourWatchHasAnEarlyReviewAndAnEnd() {
        let g = day2(785)
        g.apply([.watch72("Test incident")])
        XCTAssertEqual(g.s.watch, .red)
        XCTAssertFalse(g.watchReviewReady)
        for what in ["count", "group", "shift"] { g.noteWatchProgress(what) }
        XCTAssertTrue(g.watchReviewReady)
        g.ui.modal = nil
        g.perform("c.watch.review", on: .npc(.sato))
        guard case .choice(.watchReview)? = g.ui.modal else { return XCTFail("review choice not shown") }
        g.choose(.watchReview, option: 0)
        XCTAssertEqual(g.s.watch, .yellow)
        XCTAssertFalse(g.s.watch72)
        // Without a review, it still ends on time.
        let h = day2(785, seed: 9)
        h.apply([.watch72("Test incident")])
        h.s.minute += 1
        h.s.day += 3
        h.updateWatchExpiry()
        XCTAssertNotEqual(h.s.watch, .red)
        XCTAssertFalse(h.s.watch72)
    }

    func testYellowWatchKeepsFreeTimeInThePod() {
        let g = day2(1110)   // free time
        let podExit = g.map.door(id: "fpod.main")!
        let i = g.map.doorByID[podExit.id]!
        let open = g.playerHasAccess(doorIndex: i)
        g.apply([.watch(.yellow, hours: 12, reason: "test")])
        XCTAssertFalse(g.playerHasAccess(doorIndex: i), "yellow watch: free time stays in the pod (was open: \(open))")
        XCTAssertEqual(g.doorRequirement(podExit).0, .eye)
    }

    func testAppointmentOpensItsWayNotEverything() {
        let g = day2(1110)
        g.s.appointments.append(Appointment(id: "t", day: g.s.day, start: 1100, end: 1200, title: "Dr. Sato", icon: .stethoscope, spot: "sato.client", npc: .sato, quest: nil))
        let yard = g.map.doors.filter { d in
            let (a, b) = g.doorSides(d)
            return a?.district == .yard || b?.district == .yard
        }
        XCTAssertFalse(yard.isEmpty)
        for y in yard { XCTAssertFalse(g.playerHasAccess(doorIndex: g.map.doorByID[y.id]!), "an appointment in support must not open \(y.id)") }
    }

    func testJobRiskChoiceArrivesOnSecondShift() {
        let g = day2(500)
        g.assignJob(.workshop)
        g.s.shiftsWorked[.workshop] = 2
        Systems.afterShift(g, .workshop, 0.8)
        XCTAssertEqual(g.s.pendingChoices, [.jobWorkshop])
        g.update(dt: 1.0 / 30.0)
        guard case .choice(.jobWorkshop)? = g.ui.modal else { return XCTFail("risk choice not presented") }
        Systems.afterShift(g, .workshop, 0.8)
        XCTAssertTrue(g.s.pendingChoices.isEmpty, "each job's choice happens once")
    }

    func testSuppliesRestockWithoutInflating() {
        let g = day2(785)
        let n0 = g.s.stashes["storage.shelf1"]?.filter { $0.id == .sugar }.reduce(0) { $0 + $1.qty } ?? 0
        Systems.restock(g); Systems.restock(g)
        let n1 = g.s.stashes["storage.shelf1"]?.filter { $0.id == .sugar }.reduce(0) { $0 + $1.qty } ?? 0
        XCTAssertEqual(n0, 3); XCTAssertEqual(n1, 3)
    }

    func testMealOncePerBlock() {
        let g = day2(722)   // lunch
        g.apply([.teleport("dining.post")])
        XCTAssertTrue(use(g, .object("serving.counter"), "c.meal.tray"))
        let e = g.s.player.energy
        g.eatMeal()
        XCTAssertEqual(g.s.player.energy, e)
        XCTAssertEqual(g.s.mealsToday, 1)
    }

    func testNightFootageIsReviewedInTheMorning() {
        let g = day2(785)
        g.s.footage = ["Records room"]
        let n = g.s.incidents.count
        g.startNewDay()
        XCTAssertEqual(g.s.incidents.count, n + 1)
        XCTAssertNil(g.s.footage)
    }

    func testConcealedLaundryCartRide() {
        var arrived = 0, caught = 0
        for seed in 0..<6 {
            let g = day2(800, seed: UInt64(300 + seed))
            g.s.peerRep[.dutch] = 20
            g.apply([.teleport("cartbay.drive")])
            g.enterHide("cartbay.laundrycart")
            XCTAssertEqual(g.s.player.hiddenIn, "cartbay.laundrycart")
            XCTAssertTrue(g.options(for: .object("cartbay.laundrycart")).contains { $0.id == "c.ride.laundry" })
            XCTAssertFalse(g.options(for: .object("cartbay.laundrycart")).contains { $0.id == "c.vehicle.laundry" })
            let incidents = g.s.incidents.count
            g.perform("c.ride.laundry", on: .object("cartbay.laundrycart"))
            finishTransition(g)
            XCTAssertNil(g.s.player.hiddenIn)
            if g.s.incidents.count > incidents { caught += 1 } else {
                XCTAssertEqual(g.map.zone(at: g.s.player.pos)?.id, "admin.lobby")
                arrived += 1
            }
        }
        XCTAssertGreaterThan(arrived, 0, "the ride should usually work")
    }

    func testSupervisedVanRunNeedsTierFour() {
        let g = day2(800)
        g.assignJob(.grounds)
        XCTAssertFalse(g.options(for: .object("transport.van")).contains { $0.id == "c.vehicle.van" })
        g.s.trustTierFloor = 4
        XCTAssertTrue(g.options(for: .object("transport.van")).contains { $0.id == "c.vehicle.van" })
        g.perform("c.vehicle.van", on: .object("transport.van"))
        XCTAssertEqual(g.minigame?.game.id, .vanDrive)
        playOut(g)
        XCTAssertNil(g.minigame)
    }
}
