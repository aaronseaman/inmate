import XCTest
@testable import FPodCore

/// Mistakes are recoverable: lost critical items have a way back, and every ending
/// stays reachable after a capture.
final class RecoveryTests: XCTestCase {
    func day(_ n: Int, seed: UInt64 = 21) -> Game {
        let g = makeGame(seed: seed)
        g.s.flags.formUnion([.claimedBunk, .readChart, .firstCountDone, .metDutch, .trialDone])
        g.apply([.completeQuest(.m01Intake), .completeQuest(.m02Ally)])
        while g.s.day < n { g.startNewDay(); g.processEvents() }
        finishTransition(g)
        return g
    }

    /// A disguise errand, start to finish: Ada's letter, a PPE gown, the isolation room.
    func testDisguiseErrandIsolationLetter() {
        let g = day(4)
        g.s.minute = 800
        g.setFlag(.ppeRouteKnown)
        g.perform("c.side.start.sIsolationLetter", on: .npc(.ada))
        XCTAssertTrue(g.questActive(.sIsolationLetter))
        g.perform("c.side.iso.take", on: .npc(.ada)); g.processEvents()
        XCTAssertGreaterThan(g.s.inventory.count(.letter), 0)
        // Gown up in the anteroom (a private place), with a delivery box as the prop.
        g.addItem(.ppeGown, 1, force: true)
        g.addItem(.deliveryBox, 1, force: true)
        g.apply([.teleport("infirmary.station")])
        g.s.player.pos = g.map.spot("infirmary.orderly")!.pos
        let ante = g.map.zone(id: "support.ante")!
        g.s.player.pos = ante.rects[0].rect.center
        XCTAssertTrue(g.privateForChanging())
        g.beginChange(to: .ppe)
        sim(g, seconds: 4)
        XCTAssertEqual(g.s.player.outfit, .ppe)
        let iso = g.map.zone(id: "support.isolation")!
        XCTAssertFalse(g.patientAllowed(iso), "scrubs alone don't belong in isolation")
        XCTAssertTrue(g.disguisePlausible(iso), "a gown on the delivery route does")
        g.perform("c.side.iso.deliver", on: .object("isolation.bed")); g.processEvents()
        XCTAssertTrue(g.has(.isolationLetterDelivered))
        XCTAssertTrue(g.questDone(.sIsolationLetter))
    }

    /// Caught with the escape kit: the key and map are confiscated, and both come back.
    func testEscapeKitConfiscatedThenRecovered() {
        let g = day(6, seed: 22)
        g.apply([.set(.tunnelHatchKnown), .startQuest(.m12Escape)])
        g.addItem(.mapScrapA, 1, force: true); g.addItem(.mapScrapB, 1, force: true); g.addItem(.mapScrapC, 1, force: true)
        g.s.minute = 1110
        g.perform("c.esc.map", on: .npc(.mouse)); g.processEvents()
        g.addItem(.copperWire, 1, force: true)
        g.perform("c.esc.key.static", on: .npc(.staticFell)); g.processEvents()
        XCTAssertGreaterThan(g.s.inventory.count(.tunnelMap), 0)
        XCTAssertGreaterThan(g.s.inventory.count(.utilityKey), 0)
        // Searched after a witnessed theft.
        g.captured(by: .strick, reason: .theft)
        finishTransition(g)
        XCTAssertEqual(g.s.inventory.count(.tunnelMap), 0, "contraband map is confiscated")
        XCTAssertEqual(g.s.inventory.count(.utilityKey), 0, "contraband key is confiscated")
        XCTAssertNotNil(g.s.recoveryHints[.tunnelMap])
        // Recovery: Mouse redraws; Static recuts with more copper.
        g.ui.modal = nil
        g.s.minute = 1110
        XCTAssertTrue(g.options(for: .npc(.mouse)).contains { $0.id == "c.esc.redraw" })
        g.perform("c.esc.redraw", on: .npc(.mouse)); g.processEvents()
        g.addItem(.copperWire, 1, force: true)
        g.perform("c.esc.key.static", on: .npc(.staticFell)); g.processEvents()
        XCTAssertGreaterThan(g.s.inventory.count(.tunnelMap), 0)
        XCTAssertGreaterThan(g.s.inventory.count(.utilityKey), 0)
        // The ending is still reachable.
        g.addItem(.fenceTool, 1, force: true); g.processEvents()
        g.s.minute = 1400
        g.s.player.pos = g.map.spot("tunnels.patrol.3")!.pos
        g.emit(.zoneEntered("tunnels.a")); g.processEvents(); finishTransition(g)
        g.emit(.zoneEntered("perimeter.woods")); g.processEvents(); finishTransition(g)
        XCTAssertTrue(g.has(.endingEscape))
    }

    /// Caught in the records room: the authorized request still gets the log.
    func testRecordsRoomCaptureStillLeavesTheAuthorizedRoute() {
        let g = day(5, seed: 23)
        g.apply([.completeQuest(.m03Work), .completeQuest(.m06Lawyer), .set(.contradictionFound), .set(.contradictionReported)])
        g.processEvents()
        XCTAssertTrue(g.questActive(.m08Records))
        g.s.minute = 800
        g.captured(by: .gaines, reason: .restrictedArea)
        finishTransition(g)
        g.ui.modal = nil
        g.s.minute = 800
        g.perform("c.pruitt.recordsform", on: .npc(.pruitt)); g.processEvents()
        g.perform("c.pruitt.records", on: .npc(.pruitt)); g.processEvents()
        XCTAssertTrue(g.has(.recordsRequested))
        g.startNewDay(); g.processEvents(); finishTransition(g)
        g.ui.modal = nil
        XCTAssertTrue(g.has(.recordsApproved))
        g.s.minute = 800
        g.perform("c.pruitt.collect", on: .npc(.pruitt)); g.processEvents()
        XCTAssertGreaterThan(g.s.inventory.count(.transportLog), 0)
    }

    /// A severe incident mid-story: 72 hours of watch, then the story continues.
    func testSevereIncidentDoesNotBlockTheStory() {
        let g = day(5, seed: 24)
        g.apply([.completeQuest(.m03Work), .completeQuest(.m06Lawyer)])
        g.processEvents()
        g.captured(by: .strick, reason: .assault)
        finishTransition(g)
        XCTAssertTrue(g.s.watch72)
        XCTAssertTrue(g.questActive(.m07Contradiction), "watch never cancels legal progress")
        for _ in 0..<4 { g.startNewDay(); g.processEvents(); finishTransition(g); g.ui.modal = nil }
        sim(g, seconds: 1)
        XCTAssertFalse(g.s.watch72, "the 72-hour watch ends on time")
        XCTAssertNotEqual(g.s.watch, .red)
    }
}
