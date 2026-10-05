import Foundation

/// A compact, complete chess rules engine (castling, en passant, promotion, check,
/// mate, stalemate) with a small alpha-beta opponent. Squares: index = rank * 8 + file,
/// rank 0 is White's back rank. Pieces: 1 pawn, 2 knight, 3 bishop, 4 rook, 5 queen,
/// 6 king; positive = White, negative = Black.
public struct ChessMove: Hashable {
    public var from: Int
    public var to: Int
    public var promo: Int = 0
    public init(_ from: Int, _ to: Int, promo: Int = 0) { self.from = from; self.to = to; self.promo = promo }
}

public struct ChessBoard: Hashable {
    public var sq: [Int]
    public var whiteToMove = true
    /// Bits: 1 White O-O, 2 White O-O-O, 4 Black O-O, 8 Black O-O-O.
    public var castle = 15
    public var ep = -1

    public static let initial: ChessBoard = {
        var sq = [Int](repeating: 0, count: 64)
        let back = [4, 2, 3, 5, 6, 3, 2, 4]
        for f in 0..<8 {
            sq[f] = back[f]; sq[8 + f] = 1
            sq[48 + f] = -1; sq[56 + f] = -back[f]
        }
        return ChessBoard(sq: sq)
    }()

    static let knightJumps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    static let kingSteps = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    static let diag = [(1, 1), (-1, 1), (1, -1), (-1, -1)]
    static let orth = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    @inline(__always) static func at(_ f: Int, _ r: Int) -> Int? { (f >= 0 && f < 8 && r >= 0 && r < 8) ? r * 8 + f : nil }

    /// Is square `s` attacked by the given side?
    public func attacked(_ s: Int, byWhite w: Bool) -> Bool {
        let f = s % 8, r = s / 8
        let sign = w ? 1 : -1
        // Pawns attack diagonally forward (from the attacker's point of view).
        let pr = r - sign
        for df in [-1, 1] { if let t = ChessBoard.at(f + df, pr), sq[t] == sign { return true } }
        for (df, dr) in ChessBoard.knightJumps { if let t = ChessBoard.at(f + df, r + dr), sq[t] == 2 * sign { return true } }
        for (df, dr) in ChessBoard.kingSteps { if let t = ChessBoard.at(f + df, r + dr), sq[t] == 6 * sign { return true } }
        for (df, dr) in ChessBoard.diag {
            var x = f + df, y = r + dr
            while let t = ChessBoard.at(x, y) {
                let p = sq[t]
                if p != 0 { if p == 3 * sign || p == 5 * sign { return true }; break }
                x += df; y += dr
            }
        }
        for (df, dr) in ChessBoard.orth {
            var x = f + df, y = r + dr
            while let t = ChessBoard.at(x, y) {
                let p = sq[t]
                if p != 0 { if p == 4 * sign || p == 5 * sign { return true }; break }
                x += df; y += dr
            }
        }
        return false
    }

    public func king(white: Bool) -> Int { sq.firstIndex(of: white ? 6 : -6) ?? 0 }
    public func inCheck(white: Bool) -> Bool { attacked(king(white: white), byWhite: !white) }
    public var sideInCheck: Bool { inCheck(white: whiteToMove) }

    func pseudoMoves(capturesOnly: Bool = false) -> [ChessMove] {
        var out: [ChessMove] = []
        out.reserveCapacity(48)
        let w = whiteToMove
        let sign = w ? 1 : -1
        func enemy(_ p: Int) -> Bool { p * sign < 0 }
        for s in 0..<64 {
            let p = sq[s] * sign
            guard p > 0 else { continue }
            let f = s % 8, r = s / 8
            switch p {
            case 1:
                let dir = sign, startRank = w ? 1 : 6, lastRank = w ? 7 : 0
                if !capturesOnly, let t = ChessBoard.at(f, r + dir), sq[t] == 0 {
                    if r + dir == lastRank { out.append(ChessMove(s, t, promo: 5)) } else {
                        out.append(ChessMove(s, t))
                        if r == startRank, let t2 = ChessBoard.at(f, r + 2 * dir), sq[t2] == 0 { out.append(ChessMove(s, t2)) }
                    }
                }
                for df in [-1, 1] {
                    guard let t = ChessBoard.at(f + df, r + dir) else { continue }
                    if enemy(sq[t]) || t == ep {
                        out.append(ChessMove(s, t, promo: r + dir == lastRank ? 5 : 0))
                    }
                }
            case 2, 6:
                for (df, dr) in (p == 2 ? ChessBoard.knightJumps : ChessBoard.kingSteps) {
                    guard let t = ChessBoard.at(f + df, r + dr) else { continue }
                    if sq[t] == 0 { if !capturesOnly { out.append(ChessMove(s, t)) } } else if enemy(sq[t]) { out.append(ChessMove(s, t)) }
                }
                if p == 6 && !capturesOnly { castling(from: s, into: &out) }
            default:
                let dirs = p == 3 ? ChessBoard.diag : (p == 4 ? ChessBoard.orth : ChessBoard.diag + ChessBoard.orth)
                for (df, dr) in dirs {
                    var x = f + df, y = r + dr
                    while let t = ChessBoard.at(x, y) {
                        if sq[t] == 0 { if !capturesOnly { out.append(ChessMove(s, t)) } } else {
                            if enemy(sq[t]) { out.append(ChessMove(s, t)) }
                            break
                        }
                        x += df; y += dr
                    }
                }
            }
        }
        return out
    }

    func castling(from s: Int, into out: inout [ChessMove]) {
        let w = whiteToMove
        let home = w ? 4 : 60
        guard s == home, !attacked(home, byWhite: !w) else { return }
        let kBit = w ? 1 : 4, qBit = w ? 2 : 8
        if castle & kBit != 0, sq[home + 1] == 0, sq[home + 2] == 0, sq[home + 3] == (w ? 4 : -4),
           !attacked(home + 1, byWhite: !w), !attacked(home + 2, byWhite: !w) {
            out.append(ChessMove(home, home + 2))
        }
        if castle & qBit != 0, sq[home - 1] == 0, sq[home - 2] == 0, sq[home - 3] == 0, sq[home - 4] == (w ? 4 : -4),
           !attacked(home - 1, byWhite: !w), !attacked(home - 2, byWhite: !w) {
            out.append(ChessMove(home, home - 2))
        }
    }

    public func applying(_ m: ChessMove) -> ChessBoard {
        var b = self
        let p = sq[m.from]
        let kind = abs(p)
        let sign = p > 0 ? 1 : -1
        // En passant capture removes the pawn behind the target square.
        if kind == 1 && m.to == ep && sq[m.to] == 0 { b.sq[m.to - 8 * sign] = 0 }
        b.sq[m.to] = m.promo != 0 ? m.promo * sign : p
        b.sq[m.from] = 0
        // Castling moves the rook too.
        if kind == 6 && abs(m.to - m.from) == 2 {
            if m.to > m.from { b.sq[m.from + 1] = b.sq[m.from + 3]; b.sq[m.from + 3] = 0 } else { b.sq[m.from - 1] = b.sq[m.from - 4]; b.sq[m.from - 4] = 0 }
        }
        b.ep = (kind == 1 && abs(m.to - m.from) == 16) ? (m.from + m.to) / 2 : -1
        if kind == 6 { b.castle &= sign > 0 ? ~3 : ~12 }
        for (corner, bit) in [(0, 2), (7, 1), (56, 8), (63, 4)] where m.from == corner || m.to == corner { b.castle &= ~bit }
        b.whiteToMove.toggle()
        return b
    }

    public func legalMoves() -> [ChessMove] {
        pseudoMoves().filter { !applying($0).inCheck(white: whiteToMove) }
    }

    public enum Status: Equatable { case playing, checkmate(winnerWhite: Bool), stalemate }
    public var status: Status {
        if !legalMoves().isEmpty { return .playing }
        return sideInCheck ? .checkmate(winnerWhite: !whiteToMove) : .stalemate
    }

    static let value = [0, 100, 320, 330, 500, 900, 0]

    /// Material in pawns, White minus Black.
    public var materialBalance: Double {
        var m = 0
        for p in sq where p != 0 { m += (p > 0 ? 1 : -1) * ChessBoard.value[abs(p)] }
        return Double(m) / 100
    }

    /// Static evaluation from White's point of view (centipawns).
    public func evaluate() -> Int {
        var score = 0
        for s in 0..<64 {
            let p = sq[s]
            guard p != 0 else { continue }
            let sign = p > 0 ? 1 : -1
            let k = abs(p)
            let f = s % 8, r = s / 8
            var v = ChessBoard.value[k]
            let center = 7 - (abs(2 * f - 7) + abs(2 * r - 7)) / 2   // 0 edge ... 6 center
            switch k {
            case 1:
                let adv = sign > 0 ? r - 1 : 6 - r
                v += adv * (f >= 2 && f <= 5 ? 9 : 5)
            case 2, 3: v += center * 5
            case 5: v += center * 2
            case 6: v += (sign > 0 ? (r == 0 ? 12 : -10) : (r == 7 ? 12 : -10))
            default: break
            }
            score += sign * v
        }
        return score
    }
}

/// Small negamax opponent with quiescence. Strength is set by depth and root noise.
public enum ChessAI {
    static func ordered(_ b: ChessBoard, _ moves: [ChessMove]) -> [ChessMove] {
        moves.sorted { a, c in
            let va = abs(b.sq[a.to]) * 10 - abs(b.sq[a.from]) + (a.promo != 0 ? 80 : 0)
            let vc = abs(b.sq[c.to]) * 10 - abs(b.sq[c.from]) + (c.promo != 0 ? 80 : 0)
            return va > vc
        }
    }

    static func quiesce(_ b: ChessBoard, _ alpha0: Int, _ beta: Int, _ qd: Int) -> Int {
        let stand = b.evaluate() * (b.whiteToMove ? 1 : -1)
        if stand >= beta || qd == 0 { return stand }
        var alpha = max(alpha0, stand)
        for m in ordered(b, b.pseudoMoves(capturesOnly: true)) {
            let n = b.applying(m)
            if n.inCheck(white: b.whiteToMove) { continue }
            let v = -quiesce(n, -beta, -alpha, qd - 1)
            if v >= beta { return v }
            alpha = max(alpha, v)
        }
        return alpha
    }

    static func negamax(_ b: ChessBoard, _ depth: Int, _ alpha0: Int, _ beta: Int, ply: Int, quiescence: Bool) -> Int {
        if depth == 0 { return quiescence ? quiesce(b, alpha0, beta, 3) : b.evaluate() * (b.whiteToMove ? 1 : -1) }
        let moves = b.legalMoves()
        if moves.isEmpty { return b.sideInCheck ? -100_000 + ply : 0 }
        var alpha = alpha0
        var best = Int.min + 1
        for m in ordered(b, moves) {
            let v = -negamax(b.applying(m), depth - 1, -beta, -alpha, ply: ply + 1, quiescence: quiescence)
            best = max(best, v)
            alpha = max(alpha, v)
            if alpha >= beta { break }
        }
        return best
    }

    /// Best move for the side to move. `noise` adds up to that many centipawns of
    /// random preference at the root, so weaker settings make human-ish slips.
    public static func bestMove(_ b: ChessBoard, depth: Int, quiescence: Bool, noise: Int, rng: inout RNG) -> ChessMove? {
        let moves = ordered(b, b.legalMoves())
        guard !moves.isEmpty else { return nil }
        var best: ChessMove?
        var bestV = Int.min
        for m in moves {
            var v = -negamax(b.applying(m), depth - 1, -1_000_000, 1_000_000, ply: 1, quiescence: quiescence)
            if noise > 0 { v += rng.int(0, noise) }
            if v > bestV { bestV = v; best = m }
        }
        return best
    }
}
