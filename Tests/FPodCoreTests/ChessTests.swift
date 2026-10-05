import XCTest
@testable import FPodCore

final class ChessTests: XCTestCase {
    func perft(_ b: ChessBoard, _ d: Int) -> Int {
        if d == 0 { return 1 }
        let moves = b.legalMoves()
        if d == 1 { return moves.count }
        return moves.reduce(0) { $0 + perft(b.applying($1), d - 1) }
    }

    /// Minimal FEN reader (placement, side, castling, en passant).
    func fen(_ s: String) -> ChessBoard {
        let parts = s.split(separator: " ")
        var sq = [Int](repeating: 0, count: 64)
        let map: [Character: Int] = ["p": 1, "n": 2, "b": 3, "r": 4, "q": 5, "k": 6]
        for (i, row) in parts[0].split(separator: "/").enumerated() {
            var f = 0
            for ch in row {
                if let n = ch.wholeNumberValue { f += n; continue }
                let v = map[Character(ch.lowercased())]!
                sq[(7 - i) * 8 + f] = ch.isUppercase ? v : -v
                f += 1
            }
        }
        var b = ChessBoard(sq: sq)
        b.whiteToMove = parts[1] == "w"
        var c = 0
        for ch in parts[2] { c |= ["K": 1, "Q": 2, "k": 4, "q": 8][ch] ?? 0 }
        b.castle = c
        if parts[3] != "-" {
            let chars = Array(parts[3])
            b.ep = (Int(String(chars[1]))! - 1) * 8 + Int(chars[0].asciiValue! - 97)
        }
        return b
    }

    func testPerftInitial() {
        XCTAssertEqual(perft(.initial, 1), 20)
        XCTAssertEqual(perft(.initial, 2), 400)
        XCTAssertEqual(perft(.initial, 3), 8902)
    }

    func testPerftKiwipete() {
        // Castling, en passant, pins and checks all appear here.
        let b = fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
        XCTAssertEqual(perft(b, 1), 48)
        XCTAssertEqual(perft(b, 2), 2039)
    }

    func testPerftEnPassantAndPins() {
        // Position 3 from the standard perft suite (no promotions at these depths).
        let b = fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
        XCTAssertEqual(perft(b, 1), 14)
        XCTAssertEqual(perft(b, 2), 191)
        XCTAssertEqual(perft(b, 3), 2812)
    }

    func testMateAndStalemate() {
        // Fool's mate.
        var b = ChessBoard.initial
        for (f, t) in [(13, 21), (52, 36), (14, 30), (59, 31)] { b = b.applying(ChessMove(f, t)) }
        XCTAssertEqual(b.status, .checkmate(winnerWhite: false))
        let stale = fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
        XCTAssertEqual(stale.status, .stalemate)
    }

    func testAIFindsMateInOneAndTakesFreeQueen() {
        var rng = RNG(seed: 1)
        let mate = fen("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")
        let m = ChessAI.bestMove(mate, depth: 2, quiescence: true, noise: 0, rng: &rng)
        XCTAssertEqual(m, ChessMove(0, 56))
        let free = fen("4k3/8/8/3q4/8/8/3R4/4K3 w - - 0 1")
        XCTAssertEqual(ChessAI.bestMove(free, depth: 1, quiescence: true, noise: 0, rng: &rng)?.to, 35)
    }
}
