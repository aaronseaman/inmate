import XCTest
@testable import FPodCore

/// The spec's tunable starting values, and two perception rules stated in it.
final class SpecValuesTests: XCTestCase {
    func testMovementAndVisionValues() {
        XCTAssertEqual(Game.walkSpeed, 2.5)
        XCTAssertEqual(Game.sneakSpeed, 1.4)
        XCTAssertEqual(Game.runSpeed, 4.2)
        XCTAssertEqual(Game.interactRadius, 1.25)
        XCTAssertEqual(Game.changeSeconds, 2.5)
        XCTAssertEqual(Role.co.vision.range, 7)
        XCTAssertEqual(Role.co.vision.fov, 65 * .pi / 180, accuracy: 1e-9)
        XCTAssertEqual(Role.tech.vision.range, 4.5)
        XCTAssertEqual(Role.tech.vision.fov, 110 * .pi / 180, accuracy: 1e-9)
        let defaults = WorldShared.map.cameras.filter { $0.range == 8 }
        XCTAssertFalse(defaults.isEmpty, "cameras default to 8 tiles")
        XCTAssertTrue(WorldShared.map.cameras.contains { $0.sweep > 0 } && WorldShared.map.cameras.contains { $0.sweep == 0 }, "fixed and sweeping cameras")
        for c in WorldShared.map.cameras { XCTAssertEqual(c.fov, 70 * .pi / 180, accuracy: 1e-6) }
    }

    /// Changing clothes in view of staff is itself suspicious.
    func testChangingInViewIsSuspicious() {
        let g = makeGame()
        g.s.player.changing = 1
        var n = NPCState(id: .haskins, pos: g.s.player.pos + Vec2(2, 0), heading: .pi)
        let o = g.observe(&n, Cast.def(.haskins), dist: 2)
        XCTAssertEqual(o.kind, .changingWatched)
        XCTAssertGreaterThan(o.bump, 0)
    }

    /// Ordinary presence in an allowed room builds no suspicion.
    func testAllowedPresenceIsNotSuspicious() {
        let g = makeGame()
        g.s.flags.formUnion([.claimedBunk, .firstCountDone])
        g.s.minute = 1100
        g.s.player.pos = g.map.spot("fpod.center")!.pos
        var n = NPCState(id: .haskins, pos: g.s.player.pos + Vec2(2, 0), heading: .pi)
        let o = g.observe(&n, Cast.def(.haskins), dist: 2)
        XCTAssertEqual(o.bump, 0)
        XCTAssertEqual(o.rate, 0)
    }

    /// Red watch removes private changing everywhere.
    func testRedWatchRemovesPrivacy() {
        let g = makeGame()
        g.s.player.pos = g.map.spot("fpod.cell3.bunkA")!.pos
        XCTAssertTrue(g.privateForChanging())
        g.apply([.watch(.red, hours: 12, reason: "test")])
        XCTAssertFalse(g.privateForChanging())
    }
}
