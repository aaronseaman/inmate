import Foundation

/// Double-six dominoes with Dutch. Match an open end; if you can't, draw from the
/// boneyard; if it's empty, pass. First to empty their hand wins; a blocked game goes
/// to the lower pip count.
public final class DominoesGame: MinigameBase, Minigame {
    public let id = MinigameID.dominoes
    public let title = "Dominoes with Dutch"
    public let icon = Icon.domino
    public var isContest: Bool { true }
    public var controls: [(Icon, String)] {
        [(.hand, "Tap a tile that matches an open end"), (.swap, "Fits both ends? Tap the end you want"),
         (.box, "No match: draw from the boneyard"), (.stop, "Boneyard empty: pass")]
    }

    public struct Tile: Equatable { let a: Int; let b: Int; var pips: Int { a + b }; var isDouble: Bool { a == b } }
    enum Side { case left, right }
    public enum Outcome { case win, loss, draw }

    var hand: [Tile] = []
    var opp: [Tile] = []
    var boneyard: [Tile] = []
    /// Oriented so line[i].b == line[i+1].a.
    var line: [Tile] = []
    var playerTurn = true
    var selected: Int?
    var oppDelay: Double = 0
    var turnTimer: Double
    let turnLimit: Double
    var passes = 0
    var outcome: Outcome?
    var shake: (Int, Double)?
    let sloppy: Double

    public init(_ cfg: MinigameConfig) {
        turnLimit = 20 * cfg.difficulty.window
        turnTimer = turnLimit
        sloppy = cfg.difficulty == .sharp ? 0.05 : (cfg.difficulty == .standard ? 0.4 : 0.6)
        super.init(cfg, salt: "dominoes")
        var all: [Tile] = []
        for a in 0...6 { for b in a...6 { all.append(Tile(a: a, b: b)) } }
        rng.shuffle(&all)
        hand = Array(all[0..<7]); opp = Array(all[7..<14]); boneyard = Array(all[14...])
    }

    var leftEnd: Int? { line.first?.a }
    var rightEnd: Int? { line.last?.b }

    func sides(_ t: Tile) -> [Side] {
        guard let l = leftEnd, let r = rightEnd else { return [.right] }
        var out: [Side] = []
        if t.a == r || t.b == r { out.append(.right) }
        if t.a == l || t.b == l { out.append(.left) }
        return out
    }

    func place(_ t: Tile, _ side: Side) {
        if line.isEmpty { line = [t]; return }
        switch side {
        case .right:
            let r = rightEnd!
            line.append(t.a == r ? t : Tile(a: t.b, b: t.a))
        case .left:
            let l = leftEnd!
            line.insert(t.b == l ? t : Tile(a: t.b, b: t.a), at: 0)
        }
    }

    var myPips: Int { hand.reduce(0) { $0 + $1.pips } }
    var oppPips: Int { opp.reduce(0) { $0 + $1.pips } }

    public var score: Double {
        switch outcome {
        case .win?: return clamp(0.78 + 0.22 * Double(oppPips) / 20, 0, 1)
        case .draw?: return 0.5
        case .loss?: return clamp(0.3 * (1 - Double(myPips) / 30), 0, 0.3)
        case nil: return 0
        }
    }

    public var summary: String {
        switch outcome {
        case .win?: return "Domino! Dutch is left holding \(oppPips) pips"
        case .loss?: return "Dutch went out — you held \(myPips) pips"
        case .draw?: return "Blocked game, even pips"
        case nil: return "Unfinished"
        }
    }

    func finish(_ o: Outcome) { outcome = o; isOver = true; cue(o == .win ? .success : (o == .draw ? .confirm : .fail)) }

    func endTurn(byPlayer: Bool, passed: Bool) {
        passes = passed ? passes + 1 : 0
        if byPlayer && hand.isEmpty { finish(.win); return }
        if !byPlayer && opp.isEmpty { finish(.loss); return }
        if passes >= 2 {
            finish(myPips < oppPips ? .win : (myPips > oppPips ? .loss : .draw))
            return
        }
        playerTurn = !byPlayer
        selected = nil
        if !playerTurn { oppDelay = 0.8 } else { turnTimer = turnLimit }
    }

    func opponentMove() {
        while true {
            let playable = opp.indices.filter { !sides(opp[$0]).isEmpty }
            if !playable.isEmpty {
                var pick = playable.max { opp[$0].pips + (opp[$0].isDouble ? 4 : 0) < opp[$1].pips + (opp[$1].isDouble ? 4 : 0) }!
                if rng.chance(sloppy), let r = rng.pick(playable) { pick = r }
                let t = opp.remove(at: pick)
                place(t, sides(t)[0])
                cue(.clank)
                endTurn(byPlayer: false, passed: false)
                return
            }
            if boneyard.isEmpty { endTurn(byPlayer: false, passed: true); return }
            opp.append(boneyard.removeLast())
        }
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let s = shake { shake = s.1 - dt > 0 ? (s.0, s.1 - dt) : nil }
        if playerTurn {
            turnTimer -= dt
            if turnTimer <= 0 { cue(.error); endTurn(byPlayer: true, passed: true) }
        } else {
            oppDelay -= dt
            if oppDelay <= 0 { opponentMove() }
        }
    }

    var canPlayAny: Bool { hand.contains { !sides($0).isEmpty } }

    // MARK: Layout

    struct Layout { var hand: [Rect]; var lineArea: Rect; var leftTarget: Rect; var rightTarget: Rect; var draw: Rect; var pass: Rect; var tileH: Double }

    func layout(_ c: Rect) -> Layout {
        let n = max(1, hand.count)
        let tileH = min(50, (c.w - 170) / Double(n) - 8) * 2 > 0 ? min(50, ((c.w - 170) / Double(n) - 8) * 2) : 30
        let tw = tileH / 2
        let handY = c.maxY - tileH - 8
        let total = Double(n) * tw + Double(n - 1) * 8
        let x0 = c.x + 10 + (c.w - 170 - total) / 2
        let hand = (0..<hand.count).map { Rect(x0 + Double($0) * (tw + 8), handY, tw, tileH) }
        let lineArea = Rect(c.x + 10, c.y + 70, c.w - 20, 60)
        let draw = Rect(c.maxX - 150, max(c.y + 140, c.maxY - 96), 140, 40)
        let pass = Rect(c.maxX - 150, c.maxY - 48, 140, 40)
        return Layout(hand: hand, lineArea: lineArea, leftTarget: Rect(lineArea.x, lineArea.y - 6, 60, lineArea.h + 12),
                      rightTarget: Rect(lineArea.maxX - 60, lineArea.y - 6, 60, lineArea.h + 12), draw: draw, pass: pass, tileH: tileH)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, playerTurn else { return }
        let L = layout(canvas)
        if let i = selected {
            if L.leftTarget.contains(p) { play(i, .left); return }
            if L.rightTarget.contains(p) { play(i, .right); return }
        }
        if let i = L.hand.firstIndex(where: { $0.insetBy(-4).contains(p) }) {
            let s = sides(hand[i])
            if s.isEmpty { shake = (i, 0.3); cue(.error); return }
            if s.count == 1 || leftEnd == rightEnd { play(i, s[0]); return }
            selected = i
            cue(.tap)
            return
        }
        if UIBuilder.touchTarget(L.draw).contains(p) && !canPlayAny && !boneyard.isEmpty {
            hand.append(boneyard.removeLast())
            cue(.pickup)
            return
        }
        if UIBuilder.touchTarget(L.pass).contains(p) && !canPlayAny && boneyard.isEmpty {
            endTurn(byPlayer: true, passed: true)
        }
    }

    func play(_ i: Int, _ side: Side) {
        let t = hand.remove(at: i)
        place(t, side)
        cue(.clank)
        endTurn(byPlayer: true, passed: false)
    }

    /// Bot: heaviest playable tile (doubles first), keeping the numbers it holds most of open.
    public func botTap(canvas: Rect) -> Vec2? {
        guard playerTurn, !isOver, elapsed > 0.3 else { return nil }
        let L = layout(canvas)
        if let i = selected {
            let held = hand.filter { $0 != hand[i] }
            let count = { (v: Int) in held.filter { $0.a == v || $0.b == v }.count }
            let t = hand[i]
            let rightNew = t.a == rightEnd ? t.b : t.a
            let leftNew = t.b == leftEnd ? t.a : t.b
            return count(rightNew) >= count(leftNew) ? L.rightTarget.center : L.leftTarget.center
        }
        let playable = hand.indices.filter { !sides(hand[$0]).isEmpty }
        if let best = playable.max(by: { hand[$0].pips + (hand[$0].isDouble ? 6 : 0) < hand[$1].pips + (hand[$1].isDouble ? 6 : 0) }) {
            return L.hand[best].center
        }
        return boneyard.isEmpty ? L.pass.center : L.draw.center
    }

    // MARK: Render

    func drawTile(_ ui: inout UIBuilder, _ id: String, _ t: Tile, _ r: Rect, vertical: Bool, faceUp: Bool = true, highlight: Bool = false, alpha: Double = 1) {
        ui.shape(id, ShapeSpec(.rect, w: r.w, h: r.h, radius: min(r.w, r.h) * 0.16, fill: faceUp ? Palette.paper : Palette.navy,
                               stroke: highlight ? Palette.ochre : Palette.ink.alpha(0.5), lineWidth: highlight ? 3 : 1.2, shadow: true), at: r.origin, alpha: alpha)
        guard faceUp else { return }
        let half = vertical ? Rect(r.x, r.y, r.w, r.h / 2) : Rect(r.x, r.y, r.w / 2, r.h)
        let other = vertical ? Rect(r.x, r.midY, r.w, r.h / 2) : Rect(r.midX, r.y, r.w / 2, r.h)
        if vertical { ui.shape(id + ".div", ShapeSpec(.rect, w: r.w * 0.7, h: 1.5, fill: Palette.ink.alpha(0.4)), at: Vec2(r.x + r.w * 0.15, r.midY - 0.75)) }
        else { ui.shape(id + ".div", ShapeSpec(.rect, w: 1.5, h: r.h * 0.7, fill: Palette.ink.alpha(0.4)), at: Vec2(r.midX - 0.75, r.y + r.h * 0.15)) }
        pips(&ui, id + ".a", t.a, half, alpha)
        pips(&ui, id + ".b", t.b, other, alpha)
    }

    static let pipLayout: [[(Double, Double)]] = [
        [], [(0.5, 0.5)], [(0.25, 0.25), (0.75, 0.75)], [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)],
        [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)], [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)],
        [(0.25, 0.2), (0.75, 0.2), (0.25, 0.5), (0.75, 0.5), (0.25, 0.8), (0.75, 0.8)],
    ]

    func pips(_ ui: inout UIBuilder, _ id: String, _ n: Int, _ r: Rect, _ alpha: Double) {
        let d = max(3, min(r.w, r.h) * 0.17)
        for (k, (x, y)) in DominoesGame.pipLayout[n].enumerated() {
            ui.shape("\(id)\(k)", ShapeSpec(.circle, w: d, h: d, fill: Palette.ink), at: Vec2(r.x + r.w * x - d / 2, r.y + r.h * y - d / 2), alpha: alpha)
        }
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        let L = layout(c)
        ui.mgHeader("dm", playerTurn ? "Your turn" : "Dutch is thinking…", canvas: c)
        ui.text("dm.opp", "Dutch: \(opp.count) tile\(opp.count == 1 ? "" : "s") · Boneyard: \(boneyard.count)", Vec2(c.maxX - 270, c.y + 18), size: 12.5, weight: .semibold,
                color: Palette.inkSoft, width: 250)
        // Opponent's hand, face down.
        for k in 0..<min(opp.count, 12) {
            drawTile(&ui, "dm.o\(k)", Tile(a: 0, b: 0), Rect(c.x + 20 + Double(k) * 16, c.y + 40, 13, 24), vertical: true, faceUp: false)
        }
        // The line: compress the middle if it grows long.
        let th = L.lineArea.h * 0.62, tw = th * 2
        var shown: [(Int, Tile)] = line.enumerated().map { ($0.offset, $0.element) }
        var gapAfter: Int? = nil
        let fit = Int((L.lineArea.w - 130) / (tw + 4))
        if shown.count > fit {
            let keep = max(2, fit / 2)
            gapAfter = keep - 1
            shown = Array(shown.prefix(keep)) + Array(shown.suffix(keep))
        }
        let totalW = Double(shown.count) * (tw + 4) + (gapAfter != nil ? 24 : 0)
        var x = L.lineArea.midX - totalW / 2
        for (k, pair) in shown.enumerated() {
            drawTile(&ui, "dm.l\(pair.0)", pair.1, Rect(x, L.lineArea.midY - th / 2, tw, th), vertical: false)
            x += tw + 4
            if k == gapAfter { ui.text("dm.gap", "…", Vec2(x + 6, L.lineArea.midY - 10), size: 18, weight: .bold, color: Palette.inkSoft, width: 20); x += 24 }
        }
        if line.isEmpty { ui.text("dm.start", "Play any tile to start", Vec2(L.lineArea.midX, L.lineArea.midY - 8), size: 13, color: Palette.inkSoft, align: .center, width: 240) }
        if selected != nil {
            for (name, r, end) in [("left", L.leftTarget, leftEnd), ("right", L.rightTarget, rightEnd)] {
                ui.shape("dm.t\(name)", ShapeSpec(.rect, w: r.w, h: r.h, radius: 10, fill: Palette.ochre.alpha(0.25), stroke: Palette.ochre, lineWidth: 2), at: r.origin)
                ui.text("dm.tl\(name)", "\(end ?? 0)", Vec2(r.midX, r.midY - 10), size: 18, weight: .bold, align: .center, width: r.w)
                ui.mgTarget("dm.tt\(name)", r, ax: "Play on the \(name) end (\(end ?? 0))")
            }
        }
        for (i, r) in L.hand.enumerated() {
            let t = hand[i]
            let playable = playerTurn && !sides(t).isEmpty
            let dx = shake.map { $0.0 == i ? sin($0.1 * 60) * 3 : 0 } ?? 0
            drawTile(&ui, "dm.h\(i)", t, r.offsetBy(Vec2(dx, playable ? -6 : 0)), vertical: true, highlight: selected == i, alpha: playable || !playerTurn ? 1 : 0.55)
            ui.mgTarget("dm.ht\(i)", r, ax: "Tile \(t.a)–\(t.b)\(playable ? ", playable" : "")")
        }
        let needDraw = playerTurn && !canPlayAny
        ui.mgButton("dm.draw", L.draw, icon: .box, label: "Draw", style: .pill, ax: "Draw from the boneyard", enabled: needDraw && !boneyard.isEmpty)
        ui.mgButton("dm.pass", L.pass, icon: .stop, label: "Pass", style: .pill, ax: "Pass", enabled: needDraw && boneyard.isEmpty)
    }
}
