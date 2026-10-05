import XCTest
@testable import FPodCore

/// Contract tests run against every implemented minigame: idle play ends with a low
/// score, a competent bot passes, random tapping never breaks invariants, and every
/// render is finite and fits the canvas.
final class MinigameTests: XCTestCase {
    static let canvases = [Rect(59, 56, 726, 303), Rect(12, 56, 643, 290)]
    static let dt = 1.0 / 30.0

    var implemented: [MinigameID] { MinigameID.allCases.filter { Minigames.isImplemented($0) } }

    func run(_ g: Minigame, canvas: Rect, maxSeconds: Double, tapper: (Minigame, Double) -> Vec2?) -> Double {
        var t = 0.0
        while !g.isOver && t < maxSeconds {
            g.update(MinigameTests.dt)
            if let p = tapper(g, t) { g.tap(p, canvas: canvas) }
            _ = g.drainCues()
            t += MinigameTests.dt
        }
        return t
    }

    func testJobMinigamesAreAllImplemented() {
        XCTAssertGreaterThanOrEqual(implemented.count, 7, "implemented: \(implemented)")
        for job in JobID.allCases {
            XCTAssertTrue(Minigames.isImplemented(Jobs.def(job).minigame), "\(job) minigame missing")
        }
    }

    func testIdlePlayEndsWithLowScore() {
        for id in implemented {
            for level in [1, 3] {
                let g = Minigames.make(id, MinigameConfig(seed: 11, difficulty: .standard, level: level))
                let t = run(g, canvas: MinigameTests.canvases[0], maxSeconds: 400) { _, _ in nil }
                XCTAssertTrue(g.isOver, "\(id) L\(level) never ended when idle")
                XCTAssertLessThan(t, 400)
                XCTAssertLessThan(g.score, 0.4, "\(id) L\(level) idle score too high: \(g.score)")
                XCTAssertFalse(g.summary.isEmpty)
            }
        }
    }

    func isContest(_ id: MinigameID) -> Bool { Minigames.make(id, MinigameConfig(seed: 1, difficulty: .standard)).isContest }

    /// Games against an opponent: the bot must finish every game, win at least once
    /// and average a pass — a competent player is not guaranteed a win.
    func testContestBotIsCompetitive() {
        for id in implemented where isContest(id) {
            var scores: [Double] = []
            for seed in 0..<6 {
                let canvas = MinigameTests.canvases[seed % 2]
                let g = Minigames.make(id, MinigameConfig(seed: 900 + UInt64(seed), difficulty: .standard, level: 1))
                var lastTap = -1.0
                _ = run(g, canvas: canvas, maxSeconds: 600) { g, t in
                    guard t - lastTap >= 0.16, let p = g.botTap(canvas: canvas) else { return nil }
                    lastTap = t
                    return p
                }
                XCTAssertTrue(g.isOver, "\(id) seed \(seed) never finished")
                scores.append(g.score)
            }
            let avg = scores.reduce(0, +) / Double(scores.count)
            // Chance games: a competent player wins a fair share, not every hand.
            XCTAssertGreaterThanOrEqual(avg, 0.35, "\(id) bot average \(scores)")
            XCTAssertTrue(scores.contains { $0 >= 0.75 }, "\(id) bot never won: \(scores)")
        }
    }

    func testBotPasses() {
        for id in implemented where !isContest(id) {
            for level in [1, 2, 4] {
                for diff in Difficulty.allCases {
                    for (ci, canvas) in MinigameTests.canvases.enumerated() {
                        let g = Minigames.make(id, MinigameConfig(seed: 100 + UInt64(level * 7 + ci), difficulty: diff, level: level))
                        var lastTap = -1.0
                        _ = run(g, canvas: canvas, maxSeconds: 400) { g, t in
                            // Human-ish reaction: at most ~6 taps a second.
                            guard t - lastTap >= 0.16, let p = g.botTap(canvas: canvas) else { return nil }
                            lastTap = t
                            return p
                        }
                        XCTAssertTrue(g.isOver, "\(id) L\(level) \(diff) bot never finished")
                        XCTAssertGreaterThanOrEqual(g.score, 0.75, "\(id) L\(level) \(diff) canvas\(ci) bot scored \(g.score): \(g.summary)")
                    }
                }
            }
        }
    }

    func testRandomTapsKeepInvariants() {
        for id in implemented {
            var rng = RNG(seed: stableHash(id.rawValue))
            for canvas in MinigameTests.canvases {
                let g = Minigames.make(id, MinigameConfig(seed: rng.next(), difficulty: .standard, level: rng.int(1, 4)))
                _ = run(g, canvas: canvas, maxSeconds: 200) { _, _ in
                    rng.chance(0.3) ? Vec2(rng.double(canvas.x - 20, canvas.maxX + 20), rng.double(canvas.y - 20, canvas.maxY + 20)) : nil
                }
                XCTAssertTrue((0...1).contains(g.score), "\(id) score out of range \(g.score)")
            }
        }
    }

    func testRendersAreFiniteAndInsideCanvas() {
        for id in implemented {
            for canvas in MinigameTests.canvases {
                let g = Minigames.make(id, MinigameConfig(seed: 5, difficulty: .standard, level: 2))
                for step in 0..<120 {
                    g.update(MinigameTests.dt * 5)
                    if step % 3 == 0, let p = g.botTap(canvas: canvas) { g.tap(p, canvas: canvas) }
                    var ui = UIBuilder(z: 6000)
                    g.render(&ui, canvas: canvas, time: Double(step))
                    XCTAssertFalse(ui.items.isEmpty, "\(id) rendered nothing")
                    let bounds = canvas.insetBy(-130)
                    for it in ui.items {
                        XCTAssertTrue(it.pos.x.isFinite && it.pos.y.isFinite, "\(id) non-finite item \(it.id)")
                        XCTAssertTrue(bounds.contains(it.pos), "\(id) item \(it.id) at \(it.pos) far outside the canvas")
                    }
                    if g.isOver { break }
                }
            }
        }
    }

    func testShiftThroughGamePaysOnceAndFeedsPerformance() {
        let g = makeGame()
        g.assignJob(.kitchen)
        g.s.minute = 500
        let before = g.s.credits
        g.startShift(.kitchen)
        guard let mg = g.minigame else { return XCTFail("no shift started") }
        XCTAssertEqual(mg.game.id, .kitchenLine)
        g.minigameAction(.minigameStart)
        let canvas = g.minigameCanvas
        var t = 0.0, last = -1.0
        while mg.phase == .playing && t < 300 {
            g.update(dt: MinigameTests.dt)
            if t - last > 0.16, let p = mg.game.botTap(canvas: canvas) { g.tap(p); last = t }
            t += MinigameTests.dt
        }
        XCTAssertEqual(mg.phase, .result)
        g.minigameAction(.minigameContinue)
        g.update(dt: MinigameTests.dt)
        XCTAssertNil(g.minigame)
        XCTAssertGreaterThan(g.s.credits, before)
        XCTAssertEqual(g.s.shiftsWorked[.kitchen], 1)
        // Same block again: no second pay.
        let paid = g.s.credits
        g.settings.assistMinigames = true
        g.startShift(.kitchen)
        g.minigameAction(.minigameAssist)
        g.minigameAction(.minigameContinue)
        g.update(dt: MinigameTests.dt)
        XCTAssertEqual(g.s.credits, paid)
    }
}
