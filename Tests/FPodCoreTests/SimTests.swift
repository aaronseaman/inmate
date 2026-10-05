import XCTest
@testable import FPodCore

final class SimTests: XCTestCase {
    func testIntakeClaimBunkAndFirstCount() {
        let g = makeGame()
        XCTAssertEqual(g.s.quests[.m01Intake]?.status, .active)
        engageAndWait(g, .object("fpod.cell3.bunk"))
        XCTAssertTrue(g.fanOptionIDs().contains("c.intake.claimBunk"), "fan: \(g.fanOptionIDs())")
        g.perform("c.intake.claimBunk", on: .object("fpod.cell3.bunk"))
        XCTAssertTrue(g.has(.claimedBunk))
        sim(g, seconds: 1)
        XCTAssertEqual(g.s.quests[.m01Intake]?.stage, 1)
        // Wait in the cell through count.
        sim(g, seconds: 30 * 60, until: { $0.s.minute >= 373 })
        XCTAssertTrue(g.has(.firstCountDone), "count should clear while in own cell")
        XCTAssertEqual(g.s.missedCounts, [])
        XCTAssertEqual(g.s.quests[.m01Intake]?.stage, 2)
    }

    func testMissedCountHasGraceThenLateReturn() {
        let g = makeGame()
        // Stand in the dayroom through the start of count.
        XCTAssertTrue(walkAndWait(g, to: g.map.spot("fpod.center")!.pos))
        sim(g, seconds: 20 * 60, until: { $0.s.minute >= 371.5 })
        XCTAssertFalse(g.has(.firstCountDone))
        XCTAssertTrue(g.s.missedCounts.isEmpty, "grace period must apply")
        sim(g, seconds: 60, until: { $0.s.minute >= 372.2 })
        XCTAssertEqual(g.s.missedCounts, [1])
        // Returning to the cell during the search records a late count instead.
        g.s.player.caughtImmunity = 999
        _ = walkAndWait(g, to: g.map.spot("fpod.cell3.bunkA")!.pos)
        sim(g, seconds: 2)
        XCTAssertTrue(g.has(.firstCountDone))
        XCTAssertTrue(g.s.incidents.contains { $0.kind == .lateCount } || g.transition != nil || g.s.incidents.contains { $0.kind == .missedCount })
    }

    func testScheduleDoorsAndDisguiseNeverOpensLocks() {
        let g = makeGame()
        let di = g.map.doorByID["fpod.main"]!
        setClock(g, 375) // wake count: pod locked
        XCTAssertFalse(g.playerCanPass(doorIndex: di))
        g.s.player.outfit = .co
        XCTAssertFalse(g.playerCanPass(doorIndex: di), "a costume must not open a locked door")
        setClock(g, 430) // breakfast: movement
        g.s.player.outfit = .tanScrubs
        XCTAssertTrue(g.playerCanPass(doorIndex: di))
        let control = g.map.doorByID["control.door"]!
        g.s.player.outfit = .co
        XCTAssertFalse(g.playerCanPass(doorIndex: control))
    }

    func testTradeIsAtomicAndQuoteFrozen() {
        let g = makeGame()
        let t = Trades.byID["dutch.coffee"]!
        g.s.flags.insert(.firstTrade)
        let q = g.quote(t)
        XCTAssertEqual(q.give.first?.qty, 2)
        let before = g.s.inventory
        XCTAssertFalse(g.confirmTrade(q), "needs two snacks")
        XCTAssertEqual(g.s.inventory, before, "failed trade must not change inventory")
        _ = g.addItem(.snack, 1)
        XCTAssertTrue(g.confirmTrade(q))
        XCTAssertEqual(g.s.inventory.count(.coffee), 1)
        XCTAssertEqual(g.s.inventory.count(.snack), 0)
    }

    func testRewardAppliesOnce() {
        let g = makeGame()
        let c0 = g.s.credits
        XCTAssertTrue(g.claimReward("test.reward", RewardSpec(credits: 5), reason: "t"))
        XCTAssertFalse(g.claimReward("test.reward", RewardSpec(credits: 5), reason: "t"))
        XCTAssertEqual(g.s.credits, c0 + 5)
        XCTAssertEqual(g.s.ledger.reduce(0) { $0 + $1.delta }, g.s.credits)
    }

    func testHiddenPlayerIsInvisible() {
        let g = makeGame()
        setClock(g, 800)
        g.s.player.pos = g.map.spot("fpod.cell3.bunkA")!.pos
        g.enterHide("fpod.cell3.bunk")
        XCTAssertEqual(g.s.player.hiddenIn, "fpod.cell3.bunk")
        var n = g.npc(.haskins)!
        n.present = true
        n.pos = Vec2(39.5, 50.5)
        n.heading = -Double.pi / 2
        XCTAssertFalse(g.npcCanSeePlayer(n, Cast.def(.haskins)))
        g.exitHide()
        XCTAssertNil(g.s.player.hiddenIn)
        XCTAssertTrue(g.map.walkableStatic(g.s.player.pos.tile))
    }

    func testSaveLoadRoundTrip() throws {
        let g = makeGame()
        sim(g, seconds: 5)
        g.s.flags.insert(.metDutch)
        _ = g.addItem(.coffee, 2)
        let data = try SaveSystem.encode(g.s)
        let st = try SaveSystem.decode(data)
        XCTAssertEqual(st.day, g.s.day)
        XCTAssertEqual(st.minute, g.s.minute, accuracy: 0.0001)
        XCTAssertEqual(st.inventory, g.s.inventory)
        XCTAssertEqual(st.flags, g.s.flags)
        XCTAssertEqual(st.credits, g.s.credits)
        let g2 = Game(state: st)
        XCTAssertEqual(g2.activity, g.activity)
        // Tampered body is rejected.
        var env = try JSONDecoder().decode(SaveSystem.Envelope.self, from: data)
        var body = [UInt8](env.body)
        if let i = body.firstIndex(of: UInt8(ascii: "1")) { body[i] = UInt8(ascii: "2") }
        env.body = Data(body)
        XCTAssertThrowsError(try SaveSystem.decode(try JSONEncoder().encode(env)))
    }

    func testSearchOnlyLosesSearchedContainers() {
        let g = makeGame()
        // Contraband in the vent (low discovery) and the locker (always opened).
        g.s.stashes["fpod.cell3.vent"] = [ItemStack(.cigarettes, 2)]
        g.s.stashes["fpod.cell3.locker"] = [ItemStack(.dice, 1), ItemStack(.book, 1)]
        var lostVent = 0
        for seed in 0..<20 {
            g.s.rng = RNG(seed: UInt64(seed))
            g.s.stashes["fpod.cell3.vent"] = [ItemStack(.cigarettes, 2)]
            g.s.stashes["fpod.cell3.locker"] = [ItemStack(.dice, 1), ItemStack(.book, 1)]
            let r = g.searchCell(3, thorough: false)
            XCTAssertTrue(r.searched.contains("fpod.cell3.locker"))
            XCTAssertEqual(g.s.stashes["fpod.cell3.locker"]?.map { $0.id }, [.book], "legal items stay")
            if r.searched.contains("fpod.cell3.vent") {
                XCTAssertNil(g.s.stashes["fpod.cell3.vent"])
                lostVent += 1
            } else {
                XCTAssertEqual(g.s.stashes["fpod.cell3.vent"]?.first?.qty, 2, "unsearched stash must keep its items")
            }
        }
        XCTAssertLessThan(lostVent, 15)
    }

    func testRecoveryPossibleAtZeroCredits() {
        let g = makeGame()
        _ = g.creditDelta(-g.s.credits, "test")
        XCTAssertEqual(g.s.credits, 0)
        // A job shift pays from zero.
        g.assignJob(.janitorial)
        setClock(g, 500)
        g.startShift(.janitorial)
        XCTAssertNotNil(g.minigame)
        g.minigameAction(.minigameStart)
        sim(g, seconds: 120, until: { $0.minigame?.phase == .result })
        g.minigameAction(.minigameContinue)
        sim(g, seconds: 0.2)
        XCTAssertNil(g.minigame)
        XCTAssertGreaterThan(g.s.credits, 0)
    }

    func testMinigamePausesClock() {
        let g = makeGame()
        g.assignJob(.janitorial)
        setClock(g, 500)
        g.startShift(.janitorial)
        let m0 = g.s.minute
        g.minigameAction(.minigameStart)
        sim(g, seconds: 10)
        XCTAssertEqual(g.s.minute, m0, accuracy: 0.0001)
    }

    /// Minigames never start in the minutes before count unless you're already in your cell.
    func testCountGuardBlocksMinigamesNearCount() {
        let g = makeGame()
        g.s.flags.formUnion([.claimedBunk, .firstCountDone])
        g.assignJob(.janitorial)
        g.s.player.pos = g.map.spot("fpod.center")!.pos
        setClock(g, 1258)   // two minutes before evening count
        g.startShift(.janitorial)
        XCTAssertNil(g.minigame, "a shift must not start right before count")
        setClock(g, 800)
        g.startShift(.janitorial)
        XCTAssertNotNil(g.minigame)
    }

    /// The weekday schedule follows the spec's table.
    func testWeekdayScheduleMatchesSpec() {
        let expect: [(Int, Activity)] = [(360, .wakeCount), (380, .medPass), (420, .breakfast), (480, .work), (660, .therapy),
                                         (720, .chow), (780, .afternoon), (900, .rec), (1020, .dinner), (1080, .freeTime),
                                         (1260, .eveningCount), (1280, .settle), (1320, .lightsOut)]
        for (start, act) in expect {
            XCTAssertTrue(Schedule.weekday.contains { $0.start == start && $0.activity == act }, "\(act) should start at \(Schedule.clockString(Double(start)))")
        }
        XCTAssertNotEqual(Schedule.weekend.map { $0.activity }, Schedule.weekday.map { $0.activity }, "weekends vary")
    }

    /// Trust: a daily cap on gains, and one minor mistake never drops a tier.
    func testTrustTierHysteresisAndDailyCap() {
        let g = makeGame()
        for _ in 0..<10 { g.adjustTrust(5, "farm") }
        XCTAssertEqual(g.s.trust, 12, "daily gain is capped")
        g.s.trust = 45; g.s.trustGainedToday = 0; g.adjustTrust(1, "x")
        XCTAssertEqual(g.trustTier, 2)
        g.adjustTrust(-8, "minor slip")
        XCTAssertEqual(g.trustTier, 2, "a single minor mistake keeps the tier")
    }
}
