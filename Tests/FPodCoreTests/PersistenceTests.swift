import XCTest
@testable import FPodCore

final class PersistenceTests: XCTestCase {
    /// A v1 save written before the optional fields existed must still load.
    func testOlderSaveWithoutNewOptionalFieldsLoads() throws {
        let g = makeGame(seed: 5)
        sim(g, seconds: 20)
        g.s.footage = ["Records room"]
        g.s.bigOrderDay = 2
        let data = try SaveSystem.encode(g.s, label: "test")
        var env = try JSONDecoder().decode(SaveSystem.Envelope.self, from: data)
        var body = try JSONSerialization.jsonObject(with: env.body) as! [String: Any]
        for k in ["footage", "parkedVehicles", "bigOrderDay"] { body.removeValue(forKey: k) }
        env.body = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        env.checksum = SaveSystem.stableHashData(env.body)
        env.version = 1
        let old = try JSONEncoder().encode(env)
        let loaded = try SaveSystem.decode(old)
        XCTAssertNil(loaded.footage)
        XCTAssertNil(loaded.bigOrderDay)
        XCTAssertEqual(loaded.day, g.s.day)
        XCTAssertEqual(loaded.credits, g.s.credits)
    }

    func testCorruptAndFutureSavesAreRejected() throws {
        let g = makeGame(seed: 6)
        var env = try JSONDecoder().decode(SaveSystem.Envelope.self, from: try SaveSystem.encode(g.s))
        env.checksum &+= 1
        XCTAssertThrowsError(try SaveSystem.decode(try JSONEncoder().encode(env)))
        env.checksum &-= 1
        env.version = SaveSystem.currentVersion + 1
        XCTAssertThrowsError(try SaveSystem.decode(try JSONEncoder().encode(env)))
    }

    func testBackupIsUsedWhenTheMainFileIsDamaged() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fpod-\(UUID().uuidString)")
        let url = dir.appendingPathComponent("save.json")
        let g = makeGame(seed: 7)
        try SaveSystem.write(g.s, to: url)
        g.s.minute = 700
        try SaveSystem.write(g.s, to: url)          // previous file becomes the backup
        try Data("garbage".utf8).write(to: url)     // main file damaged
        let loaded = SaveSystem.load(from: url)
        XCTAssertNotNil(loaded)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Mid-story states (quests, appointments, vehicles, watch) survive a round trip.
    func testStoryStateRoundTrip() throws {
        let g = makeGame(seed: 8)
        g.apply([.completeQuest(.m01Intake), .completeQuest(.m02Ally)])
        g.startNewDay(); g.processEvents()
        g.assignJob(.laundry)
        g.s.player.vehicle = .laundryCart
        g.apply([.watch72("test"), .set(.lawyerNumberKnown)])
        g.s.appointments.append(Appointment(id: "x", day: g.s.day + 1, start: 600, end: 660, title: "X", icon: .clock, spot: "sato.client", npc: .sato, quest: nil))
        g.s.footage = ["Records room"]
        let back = try SaveSystem.decode(try SaveSystem.encode(g.s))
        XCTAssertEqual(back.player.job, .laundry)
        XCTAssertEqual(back.player.vehicle, .laundryCart)
        XCTAssertTrue(back.watch72)
        XCTAssertEqual(back.appointments.count, g.s.appointments.count)
        XCTAssertEqual(back.quests[.m03Work]?.status, .active)
        XCTAssertEqual(back.footage ?? [], ["Records room"])
        // A game resumed from it keeps running.
        let h = Game(state: back, settings: .default)
        sim(h, seconds: 5)
    }
}

final class PerformanceTests: XCTestCase {
    /// Frame cost in a busy scene (all staff and peers on schedule, cones on).
    func testFrameBudgetInTheDayroom() {
        let g = makeGame(seed: 9)
        g.s.flags.formUnion([.claimedBunk, .firstCountDone])
        g.s.minute = 1100
        g.s.player.pos = g.map.spot("fpod.center")!.pos
        g.s.player.sneakToggle = true
        sim(g, seconds: 5)
        let frames = 300
        let start = Date()
        for _ in 0..<frames {
            g.update(dt: 1.0 / 60.0)
            _ = g.buildFrame()
        }
        let ms = Date().timeIntervalSince(start) * 1000 / Double(frames)
        print("PERF dayroom: \(String(format: "%.2f", ms)) ms/frame (update + display list, debug build)")
        XCTAssertLessThan(ms, 40, "frame budget blown in a debug build")
    }
}
