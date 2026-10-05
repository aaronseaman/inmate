import Foundation

/// Dayroom chess against Theo. Full rules (pawns promote to queens). Tap a piece, then
/// a dot. Rec time is limited: if your clock runs out you lose; at the move limit the
/// game is scored on material.
public final class ChessGame: MinigameBase, Minigame {
    public let id = MinigameID.chess
    public let title = "Chess with Theo"
    public let icon = Icon.chess
    public var isContest: Bool { true }
    public var controls: [(Icon, String)] {
        [(.hand, "Tap one of your pieces (White), then a dot"), (.eye, "Dots show every legal move"),
         (.clock, "Your clock only runs on your turn"), (.flag, "At move 40 the game is scored on material")]
    }

    public enum Outcome { case win, loss, draw, timeout, adjudicatedWin, adjudicatedLoss, adjudicatedDraw }

    public private(set) var board = ChessBoard.initial
    var legal: [ChessMove] = []
    var selected: Int?
    var lastMove: ChessMove?
    var thinkDelay: Double = 0
    var clock: RunClock
    public private(set) var outcome: Outcome?
    var fullMoves = 1
    let moveLimit = 40
    let aiDepth: Int
    let aiNoise: Int
    let aiQuiescence: Bool
    var botCache: (key: Int, move: ChessMove?)?
    var captured: [Int] = []

    public init(_ cfg: MinigameConfig) {
        clock = RunClock(200 * cfg.difficulty.window)
        switch cfg.difficulty {
        case .gentle: aiDepth = 1; aiNoise = 90; aiQuiescence = false
        case .standard: aiDepth = cfg.level >= 3 ? 2 : 1; aiNoise = 30; aiQuiescence = true
        case .sharp: aiDepth = 2; aiNoise = 10; aiQuiescence = true
        }
        super.init(cfg, salt: "chess")
        legal = board.legalMoves()
    }

    public var score: Double {
        switch outcome {
        case .win?: return 1
        case .adjudicatedWin?: return 0.85
        case .draw?, .adjudicatedDraw?: return 0.5
        case .adjudicatedLoss?: return 0.2
        case .loss?: return 0.05
        case .timeout?: return 0.05
        case nil: return 0
        }
    }

    public var summary: String {
        switch outcome {
        case .win?: return "Checkmate — Theo tips his king"
        case .loss?: return "Checkmated — Theo resets the board, grinning"
        case .draw?: return "Stalemate — nobody wins"
        case .timeout?: return "Your clock ran out"
        case .adjudicatedWin?: return "Rec over — ahead on material (\(materialText))"
        case .adjudicatedLoss?: return "Rec over — behind on material (\(materialText))"
        case .adjudicatedDraw?: return "Rec over — even game (\(materialText))"
        case nil: return "Unfinished"
        }
    }

    var materialText: String {
        let m = board.materialBalance
        return m == 0 ? "level" : String(format: "%+.0f", m)
    }

    func finish(_ o: Outcome) {
        outcome = o
        isOver = true
        cue(o == .win || o == .adjudicatedWin ? .success : (o == .draw || o == .adjudicatedDraw ? .confirm : .fail))
    }

    func play(_ m: ChessMove) {
        if board.sq[m.to] != 0 { captured.append(board.sq[m.to]) } else if abs(board.sq[m.from]) == 1 && m.to == board.ep { captured.append(board.whiteToMove ? -1 : 1) }
        let wasCapture = board.sq[m.to] != 0
        board = board.applying(m)
        lastMove = m
        selected = nil
        if board.whiteToMove { fullMoves += 1 }
        legal = board.legalMoves()
        cue(wasCapture ? .thud : .tap)
        switch board.status {
        case .checkmate(let whiteWon): finish(whiteWon ? .win : .loss)
        case .stalemate: finish(.draw)
        case .playing:
            if fullMoves > moveLimit {
                let m = board.materialBalance
                finish(m >= 2 ? .adjudicatedWin : (m <= -2 ? .adjudicatedLoss : .adjudicatedDraw))
            } else if board.sideInCheck { cue(.alert) }
        }
        if !board.whiteToMove { thinkDelay = 0.7 }
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if board.whiteToMove {
            if clock.tick(dt) { finish(.timeout) }
        } else {
            thinkDelay -= dt
            if thinkDelay <= 0, let m = ChessAI.bestMove(board, depth: aiDepth, quiescence: aiQuiescence, noise: aiNoise, rng: &rng) {
                play(m)
            }
        }
    }

    // MARK: Layout

    struct Layout { var board: Rect; var cell: Double; var panel: Rect }

    func layout(_ c: Rect) -> Layout {
        let size = min(c.h - 8, c.w * 0.6)
        let cell = (size / 8).rounded(.down)
        let b = Rect(c.x + 12, c.y + (c.h - cell * 8) / 2, cell * 8, cell * 8)
        return Layout(board: b, cell: cell, panel: Rect(b.maxX + 20, c.y, c.maxX - b.maxX - 24, c.h))
    }

    /// Screen rect of a square (White at the bottom).
    func rect(_ s: Int, _ L: Layout) -> Rect {
        Rect(L.board.x + Double(s % 8) * L.cell, L.board.y + Double(7 - s / 8) * L.cell, L.cell, L.cell)
    }

    func square(at p: Vec2, _ L: Layout) -> Int? {
        guard L.board.contains(p) else { return nil }
        let f = Int((p.x - L.board.x) / L.cell), r = 7 - Int((p.y - L.board.y) / L.cell)
        return ChessBoard.at(f, r)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, board.whiteToMove else { return }
        let L = layout(canvas)
        guard let s = square(at: p, L) else { selected = nil; return }
        if let from = selected, let m = legal.first(where: { $0.from == from && $0.to == s }) {
            play(m)
            return
        }
        if board.sq[s] > 0 && legal.contains(where: { $0.from == s }) {
            selected = s
            cue(.tap)
        } else {
            selected = nil
        }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard board.whiteToMove, !isOver, elapsed > 0.2 else { return nil }
        let key = board.hashValue
        if botCache?.key != key {
            var r = RNG(seed: UInt64(fullMoves))
            botCache = (key, ChessAI.bestMove(board, depth: 2, quiescence: true, noise: 0, rng: &r))
        }
        guard let m = botCache?.move else { return nil }
        let L = layout(canvas)
        return rect(selected == m.from ? m.to : m.from, L).center
    }

    // MARK: Render

    static let files = ["a", "b", "c", "d", "e", "f", "g", "h"]

    func squareName(_ s: Int) -> String { "\(ChessGame.files[s % 8])\(s / 8 + 1)" }

    static let pieceNames = ["", "pawn", "knight", "bishop", "rook", "queen", "king"]

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        let L = layout(c)
        ui.shape("ch.frame", ShapeSpec(.rect, w: L.board.w + 10, h: L.board.h + 10, radius: 8, fill: Palette.wood.darker(0.1), shadow: true),
                 at: L.board.origin - Vec2(5, 5))
        let targets = Set(legal.filter { $0.from == selected }.map { $0.to })
        let checkSq = board.sideInCheck ? board.king(white: board.whiteToMove) : -1
        for s in 0..<64 {
            let r = rect(s, L)
            let light = (s % 8 + s / 8) % 2 == 1
            var fill = light ? Palette.ivory : Palette.turquoise.darker(0.12)
            if let lm = lastMove, lm.from == s || lm.to == s { fill = fill.mix(Palette.ochre, 0.45) }
            if s == selected { fill = Palette.ochre }
            if s == checkSq { fill = Palette.coral }
            ui.shape("ch.sq\(s)", ShapeSpec(.rect, w: r.w, h: r.h, fill: fill), at: r.origin)
            let p = board.sq[s]
            if p != 0 {
                ui.art("ch.p\(s)", .named("chess", p, Int(L.cell * 0.9)), at: r.origin + Vec2(L.cell * 0.05, L.cell * 0.04))
            }
            if targets.contains(s) {
                let d = p != 0 ? L.cell * 0.9 : L.cell * 0.3
                ui.shape("ch.t\(s)", ShapeSpec(p != 0 ? .ring : .circle, w: d, h: d, fill: p != 0 ? nil : Palette.navy.alpha(0.55),
                                               stroke: p != 0 ? Palette.navy.alpha(0.7) : nil, lineWidth: 3), at: r.center - Vec2(d / 2, d / 2))
            }
            let name = p == 0 ? "empty" : "\(p > 0 ? "white" : "black") \(ChessGame.pieceNames[abs(p)])"
            ui.mgTarget("ch.ax\(s)", r, ax: "\(squareName(s)), \(name)\(targets.contains(s) ? ", move here" : "")")
        }
        // Side panel.
        let P = L.panel
        ui.text("ch.turn", board.whiteToMove ? (board.sideInCheck ? "Your move — check!" : "Your move") : "Theo is thinking…",
                Vec2(P.x, P.y + 8), size: 16, weight: .bold, color: board.sideInCheck ? Palette.coral : Palette.ink, width: P.w)
        ui.text("ch.moveno", "Move \(min(fullMoves, moveLimit)) of \(moveLimit)", Vec2(P.x, P.y + 34), size: 12.5, color: Palette.inkSoft, width: P.w)
        ui.icon("ch.clk", .clock, center: Vec2(P.x + 8, P.y + 66), size: 16, color: Palette.slate)
        let bw = min(150, P.w - 30)
        ui.shape("ch.cbg", ShapeSpec(.rect, w: bw, h: 10, radius: 5, fill: Palette.blueGray), at: Vec2(P.x + 22, P.y + 61))
        ui.shape("ch.cf", ShapeSpec(.rect, w: max(10, bw * clock.fraction), h: 10, radius: 5, fill: clock.fraction < 0.2 ? Palette.coral : Palette.turquoise),
                 at: Vec2(P.x + 22, P.y + 61))
        let mb = board.materialBalance
        ui.text("ch.mat", mb == 0 ? "Material: even" : "Material: \(mb > 0 ? "you +" : "Theo +")\(Int(abs(mb)))", Vec2(P.x, P.y + 84), size: 12.5,
                weight: .semibold, color: Palette.inkSoft, width: P.w)
        let tookWhite = captured.filter { $0 < 0 }.sorted(), tookBlack = captured.filter { $0 > 0 }.sorted()
        let cs = 22.0
        for (k, p) in tookWhite.prefix(15).enumerated() {
            ui.art("ch.cw\(k)", .named("chess", p, Int(cs)), at: Vec2(P.x + Double(k % 8) * (cs - 4), P.y + 108 + Double(k / 8) * cs))
        }
        for (k, p) in tookBlack.prefix(15).enumerated() {
            ui.art("ch.cb\(k)", .named("chess", p, Int(cs)), at: Vec2(P.x + Double(k % 8) * (cs - 4), P.y + 160 + Double(k / 8) * cs))
        }
        if let lm = lastMove {
            ui.text("ch.last", "Last: \(squareName(lm.from))–\(squareName(lm.to))", Vec2(P.x, P.maxY - 26), size: 12, color: Palette.inkSoft, width: P.w)
        }
    }
}
