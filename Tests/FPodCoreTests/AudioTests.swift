import XCTest
@testable import FPodCore

final class AudioTests: XCTestCase {
    func testAllEffectsRenderCleanly() {
        for s in SFX.allCases {
            let x = SFXBank.render(s)
            XCTAssertGreaterThan(x.count, 100, "\(s) too short")
            XCTAssertFalse(x.contains { $0.isNaN || $0.isInfinite }, "\(s) has NaN")
            let peak = x.reduce(0) { max($0, abs($1)) }
            XCTAssertLessThanOrEqual(peak, 1.0, "\(s) clips")
            XCTAssertGreaterThan(peak, 0.05, "\(s) is silent")
        }
    }

    func testMumblesVaryByPitch() {
        let a = SFXBank.mumble(pitch: 0.8, seed: 1), b = SFXBank.mumble(pitch: 1.3, seed: 1)
        XCTAssertNotEqual(a.count, 0)
        XCTAssertNotEqual(a.prefix(2000).map { $0 }, b.prefix(2000).map { $0 })
    }

    func testMusicLoopsAreSeamlessAndBounded() {
        for m in [MusicMood.search] {
            let loop = MusicComposer.render(m)
            let beats = loop.seconds * loop.bpm / 60
            XCTAssertEqual(beats, beats.rounded(), accuracy: 0.05, "loop must be whole beats")
            XCTAssertEqual(loop.left.count, loop.right.count)
            let peak = loop.left.reduce(0) { max($0, abs($1)) }
            XCTAssertLessThanOrEqual(peak, 0.81)
            // Seam: the jump between the last and first sample is small.
            XCTAssertLessThan(abs(loop.left.last! - loop.left.first!), 0.35)
        }
    }
}
