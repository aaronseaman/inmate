import XCTest
@testable import FPodCore

/// Scenario: an honest full first day, driven through the same entry points the UI uses.
final class DayOneTests: XCTestCase {
    func waitUntilMinute(_ g: Game, _ m: Double) {
        // Skip idle time quickly but let the world tick.
        if g.s.minute < m - 2 { g.s.minute = m - 2 }
        sim(g, seconds: 200, until: { $0.s.minute >= m })
    }

    func perform(_ g: Game, _ target: TargetRef, option: String, file: StaticString = #file, line: UInt = #line) {
        engageAndWait(g, target, timeout: 120)
        if option == "b.shift" && g.minigame != nil { return }   // single option auto-runs
        let ids = g.fanOptionIDs()
        if ids.isEmpty, case .choice? = g.ui.modal { return }
        XCTAssertTrue(ids.contains(option), "expected \(option) in \(ids) for \(target) at \(Schedule.clockString(g.s.minute)) pos \(g.s.player.pos)", file: file, line: line)
        guard ids.contains(option) else { return }
        g.perform(option, on: target)
        sim(g, seconds: 0.2)
    }

    func solveMop(_ g: Game) {
        guard let mg = g.minigame, let mop = mg.game as? MopGame else { XCTFail("no mop game"); return }
        g.minigameAction(.minigameStart)
        let canvas = g.minigameCanvas
        let (o, size) = mop.layout(canvas)
        for idx in mop.solution.dropFirst() {
            let x = idx % mop.cols, y = idx / mop.cols
            g.tap(o + Vec2((Double(x) + 0.5) * size, (Double(y) + 0.5) * size))
            if mop.isOver { break }
        }
        sim(g, seconds: 0.5)
        XCTAssertEqual(mg.phase, .result)
        XCTAssertGreaterThan(mop.score, 0.75, mop.summary)
        g.minigameAction(.minigameContinue)
        sim(g, seconds: 0.3)
    }

    func testHonestFullDay() {
        let g = makeGame(seed: 1234)
        let startCredits = g.s.credits
        // 1. Bunk
        perform(g, .object("fpod.cell3.bunk"), option: "c.intake.claimBunk")
        XCTAssertTrue(g.has(.claimedBunk))
        // 2. Count (stay in the cell)
        waitUntilMinute(g, 373)
        XCTAssertTrue(g.has(.firstCountDone))
        // 3. Med pass
        waitUntilMinute(g, 392)
        engageAndWait(g, .object("fpod.medwindow"), timeout: 120)
        if case .choice(.medPass)? = g.ui.modal {} else { XCTFail("med pass choice should open, modal=\(String(describing: g.ui.modal))") }
        g.choose(.medPass, option: 1)
        XCTAssertTrue(g.has(.medDiscussRequested))
        XCTAssertTrue(g.s.appointments.contains { $0.id == "sato.meds" })
        // 4. Breakfast trade with Dutch
        waitUntilMinute(g, 430)
        sim(g, seconds: 20)
        perform(g, .npc(.dutch), option: "c.dutch.meet")
        XCTAssertTrue(g.has(.metDutch))
        let welcome = Trades.byID["dutch.welcome"]!
        XCTAssertTrue(g.confirmTrade(g.quote(welcome)))
        XCTAssertEqual(g.s.inventory.count(.coffee), 1)
        XCTAssertTrue(g.has(.firstTrade))
        // 5. Trial shift
        waitUntilMinute(g, 485)
        sim(g, seconds: 5)
        perform(g, .npc(.haskins), option: "c.haskins.trial")
        XCTAssertEqual(g.s.player.job, .janitorial)
        perform(g, .object("fpod.closet.mop"), option: "b.shift")
        solveMop(g)
        XCTAssertTrue(g.has(.trialDone))
        XCTAssertGreaterThan(g.s.credits, startCredits)
        XCTAssertNil(g.s.player.job, "trial returns the job")
        // 6. Group: chart
        waitUntilMinute(g, 665)
        sim(g, seconds: 25)
        perform(g, .npc(.cole), option: "c.cole.chart")
        XCTAssertTrue(g.has(.readChart))
        g.perform(.closeModal)
        sim(g, seconds: 0.5)
        XCTAssertEqual(g.s.quests[.m01Intake]?.status, .done)
        XCTAssertEqual(g.s.quests[.m02Ally]?.status, .active)
        // 7. Mouse's favor: decline (the honest route)
        waitUntilMinute(g, 790)
        sim(g, seconds: 10)
        perform(g, .npc(.mouse), option: "c.mouse.errand")
        if case .choice(.mouseErrand)? = g.ui.modal {} else { XCTFail("mouse choice") }
        g.choose(.mouseErrand, option: 1)
        XCTAssertTrue(g.has(.mouseErrandDeclined))
        // 8. Rec yard: choose Lou
        waitUntilMinute(g, 905)
        sim(g, seconds: 30)
        perform(g, .npc(.lou), option: "c.ally.lou")
        XCTAssertTrue(g.has(.allyLou), "flags: \(g.s.flags.map { $0.rawValue }.sorted()) stage: \(String(describing: g.s.quests[.m02Ally]))")
        XCTAssertTrue(walkAndWait(g, to: g.map.spot("fpod.center")!.pos, timeout: 120), "back to the pod after rec")
        // 9. Evening count
        waitUntilMinute(g, 1240)
        XCTAssertTrue(walkAndWait(g, to: g.map.spot("fpod.cell3.bunkA")!.pos, timeout: 120), "walk back to cell")
        waitUntilMinute(g, 1263)
        XCTAssertTrue(g.has(.firstEveningCount))
        XCTAssertTrue(g.s.missedCounts.isEmpty)
        // 10. Lights out and sleep
        waitUntilMinute(g, 1325)
        perform(g, .object("fpod.cell3.bunk"), option: "b.sleep")
        finishTransition(g)
        XCTAssertEqual(g.s.day, 2)
        sim(g, seconds: 1)
        XCTAssertEqual(g.s.quests[.m02Ally]?.status, .done)
        XCTAssertTrue(g.s.incidents.isEmpty, "honest day should have no incidents: \(g.s.incidents)")
        XCTAssertEqual(g.s.ledger.reduce(0) { $0 + $1.delta }, g.s.credits)
    }
}
