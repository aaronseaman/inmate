import XCTest
@testable import FPodCore

final class WatchRoundsTests: XCTestCase {
    /// 13:20 on day one, after staff have walked in to their afternoon posts.
    func settledAfternoon() -> Game {
        let g = makeGame()
        setClock(g, 740)
        g.s.player.pos = Vec2(44.5, 62.5)
        sim(g, seconds: 60)
        return g
    }

    /// Yellow watch: an officer walks over, sees the player, and the check passes.
    func testYellowWatchSendsAnOfficerToCheck() {
        let g = settledAfternoon()
        g.s.player.pos = Vec2(44.5, 62.5)
        XCTAssertEqual(g.map.zone(at: g.s.player.pos)?.id, "fpod.dayroom")
        g.setWatch(.yellow, hours: 24, reason: "Test")
        var checker: NPCID?
        sim(g, seconds: 90, until: { gg in
            if let b = gg.s.watchCheck?.by { checker = b }
            return (gg.s.watchCheck?.passed ?? 0) >= 1
        })
        XCTAssertNotNil(checker, "a floor officer should come in person")
        XCTAssertEqual(g.s.watchCheck?.passed, 1)
        XCTAssertEqual(g.s.watchCheck?.missed, 0)
        XCTAssertNil(g.s.watchCheck?.by)
        XCTAssertFalse(g.s.incidents.contains { $0.kind == .missedWatchCheck })
    }

    /// Hiding through a check is a miss: the checker goes looking, the watch is extended,
    /// and a second miss raises it to red.
    func testHidingThroughWatchChecksEscalates() {
        let g = settledAfternoon()
        g.s.player.pos = Vec2(44.5, 71.5)
        g.enterHide("fpod.shower2")
        g.setWatch(.yellow, hours: 2, reason: "Test")
        var checker: NPCID?
        sim(g, seconds: 120, until: { gg in
            if let b = gg.s.watchCheck?.by { checker = b }
            return (gg.s.watchCheck?.missed ?? 0) >= 1 || gg.transition != nil
        })
        XCTAssertEqual(g.s.watchCheck?.missed, 1)
        XCTAssertTrue(g.s.incidents.contains { $0.kind == .missedWatchCheck })
        XCTAssertGreaterThan(g.watchHoursLeft, 5.5, "a missed check extends yellow watch")
        XCTAssertEqual(g.s.watch, .yellow)
        if let c = checker, let n = g.npc(c) {
            XCTAssertTrue([.investigate, .search, .inspect, .pursue].contains(n.mode), "the checker goes looking")
        } else {
            XCTFail("a checker should have been sent")
        }
        g.missWatchCheck(by: nil)
        XCTAssertEqual(g.s.watch, .red)
        sim(g, seconds: 0.1)
        XCTAssertNil(g.s.watchCheck, "checks belong to yellow watch only")
    }

    /// Green watch never schedules checks; escorts, counts and scenes pause them.
    func testChecksOnlyRunOnYellowAndPauseForCounts() {
        let g = makeGame()
        setClock(g, 800)
        sim(g, seconds: 30)
        XCTAssertNil(g.s.watchCheck)
        g.setWatch(.yellow, hours: 24, reason: "Test")
        sim(g, seconds: 1)
        let now = g.s.absMinute
        g.s.watchCheck?.nextAt = now
        g.s.player.escortedBy = .haskins
        g.updateWatchChecks()
        XCTAssertNil(g.s.watchCheck?.by, "no check while being escorted")
        XCTAssertGreaterThan(g.s.watchCheck?.nextAt ?? 0, g.s.absMinute)
    }

    /// Dirt, tears and stains wear a disguise; washing restores it; own scrubs never wear.
    func testDisguisesPickUpDirtTearsAndStains() {
        let g = makeGame()
        g.s.player.outfit = .maintenance
        g.s.player.outfitCondition = 100
        g.outfitThroughHatch("culvert.out")
        XCTAssertEqual(g.s.player.outfitCondition, 82, accuracy: 0.01)
        g.outfitAfterHide("yard.dumpster")
        XCTAssertEqual(g.s.player.outfitCondition, 60, accuracy: 0.01)
        g.outfitAtMeal(soup: true)
        XCTAssertEqual(g.s.player.outfitCondition, 40, accuracy: 0.01)

        // Walking a service tunnel.
        g.s.player.outfitCondition = 100
        let trunk = g.map.zones.first { $0.id == "tunnels.trunk" }!.rects[0]
        let a = Vec2(Double(trunk.x) + 0.5, Double(trunk.y) + 0.5)
        let b = trunk.w >= trunk.h ? Vec2(Double(trunk.x + trunk.w) - 0.5, a.y) : Vec2(a.x, Double(trunk.y + trunk.h) - 0.5)
        g.s.player.pos = a
        XCTAssertTrue(walkAndWait(g, to: b))
        let walked = a.distance(to: b)
        XCTAssertLessThan(g.s.player.outfitCondition, 100 - walked * Game.grimeWearPerTile * 0.8)

        // Own clothes don't wear.
        g.s.player.outfit = .tanScrubs
        g.s.player.outfitCondition = 100
        g.outfitThroughHatch("culvert.out")
        g.outfitAfterHide("yard.dumpster")
        g.outfitAtMeal(soup: true)
        XCTAssertEqual(g.s.player.outfitCondition, 100)
    }

    /// A worn disguise is easier to see through.
    func testWornDisguiseIsRecognizedFromFurther() {
        let g = makeGame()
        g.s.player.outfit = .maintenance
        g.s.player.outfitCondition = 100
        let fresh = g.recognitionRange(observer: Cast.def(.haskins))
        g.s.player.outfitCondition = 30
        XCTAssertGreaterThan(g.recognitionRange(observer: Cast.def(.haskins)), fresh + 0.9)
    }
}

final class ArtSalesTests: XCTestCase {
    /// Art therapy records the piece's value; the craft sale pays it, best piece first.
    func testCraftSalePaysTheArtTherapyValue() {
        let g = makeGame()
        g.apply([.minigame(.art, key: "art.test", pass: 0.4, onPass: [.give(.drawing, 1)], onFail: [])])
        guard let mg = g.minigame, let art = mg.game as? ArtGame else { return XCTFail("no art session") }
        g.minigameAction(.minigameStart)
        let canvas = g.minigameCanvas
        var t = 0.0, last = -1.0
        while mg.phase == .playing && t < 300 {
            g.update(dt: 1.0 / 30.0)
            if t - last > 0.16, let p = mg.game.botTap(canvas: canvas) { g.tap(p); last = t }
            t += 1.0 / 30.0
        }
        let value = art.saleValue
        g.minigameAction(.minigameContinue)
        g.update(dt: 1.0 / 30.0)
        XCTAssertTrue(mg.passed, "the bot should pass art therapy")
        XCTAssertEqual(g.s.inventory.count(.drawing), 1)
        XCTAssertEqual(g.s.artValues, [value])

        // A second drawing from a friend has no recorded value.
        g.apply([.give(.drawing, 1)])
        let c0 = g.s.credits
        g.apply([.sellDrawing(fallback: 4, reason: "Craft sale")])
        XCTAssertEqual(g.s.credits - c0, value, "best piece sells first, at its value")
        g.apply([.sellDrawing(fallback: 4, reason: "Craft sale")])
        XCTAssertEqual(g.s.credits - c0, value + 4)
        XCTAssertEqual(g.s.inventory.count(.drawing), 0)
        XCTAssertNil(g.s.artValues)
    }

    /// Giving a drawing away keeps the better pieces' values for sale.
    func testGiftingKeepsTheBetterPiece() {
        let g = makeGame()
        g.apply([.give(.drawing, 1)]); g.recordArtPiece(3)
        g.apply([.give(.drawing, 1)]); g.recordArtPiece(6)
        g.apply([.take(.drawing, 1)])
        let c0 = g.s.credits
        g.apply([.sellDrawing(fallback: 4, reason: "Craft sale")])
        XCTAssertEqual(g.s.credits - c0, 6)
    }
}
