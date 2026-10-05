import Foundation

/// Infirmary orderly: restock the supply cabinet. Cards are face down — flip two at a
/// time to pair each supply with its shelf label. Fewer wrong flips, better count.
public final class SupplyMatchGame: MinigameBase, Minigame {
    public let id = MinigameID.supplyMatch
    public let title = "Restock the cabinet"
    public let icon = Icon.stethoscope
    public var controls: [(Icon, String)] {
        [(.hand, "Tap a card to turn it over"), (.swap, "Turn two: a match stays open"),
         (.eye, "Remember where things are"), (.clock, "Finish before the supply run")]
    }

    static let supplies: [(Icon, String)] = [(.soap, "Soap"), (.cup, "Cups"), (.sheet, "Linens"), (.box, "Gloves"), (.gown, "Gowns"),
                                            (.clipboard, "Forms"), (.envelope, "Envelopes"), (.battery, "Batteries"), (.plate, "Trays")]

    let cols: Int
    let rows: Int
    var cards: [Int] = []
    var open: Set<Int> = []
    var matched: Set<Int> = []
    var pending: [Int] = []
    var hideTimer: Double = 0
    var wrongFlips = 0
    var seen: Set<Int> = []
    var clock: RunClock
    var pairs: Int { cards.count / 2 }

    public init(_ cfg: MinigameConfig) {
        cols = 4
        rows = cfg.level >= 2 ? 4 : 3
        clock = RunClock((60 + 14 * Double(cfg.level - 1)) * cfg.difficulty.window)
        super.init(cfg, salt: "supply")
        let n = cols * rows / 2
        var kinds = Array(0..<SupplyMatchGame.supplies.count)
        rng.shuffle(&kinds)
        var deck: [Int] = []
        for k in kinds.prefix(n) { deck += [k, k] }
        rng.shuffle(&deck)
        cards = deck
    }

    public var score: Double {
        let found = Double(matched.count / 2) / Double(max(1, pairs))
        let slack = Double(pairs) * 1.6
        let acc = clamp(1 - Double(max(0, wrongFlips - pairs / 2)) / slack, 0, 1)
        return clamp(found * (0.7 + 0.3 * acc) + (found >= 1 ? 0.05 * clock.fraction : 0), 0, 1)
    }

    public var summary: String {
        "Matched \(matched.count / 2)/\(pairs) · \(wrongFlips) wrong flip\(wrongFlips == 1 ? "" : "s")"
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if hideTimer > 0 {
            hideTimer -= dt
            if hideTimer <= 0 { for i in pending { open.remove(i) }; pending = [] }
        }
        if clock.tick(dt) { isOver = true }
    }

    func cardRects(_ c: Rect) -> [Rect] {
        let area = Rect(c.x + 10, c.y + 46, c.w - 20, c.h - 52)
        let gap = 10.0
        let cw = min(96, (area.w - Double(cols - 1) * gap) / Double(cols))
        let ch = min(cw * 0.92, (area.h - Double(rows - 1) * gap) / Double(rows))
        let gw = Double(cols) * cw + Double(cols - 1) * gap
        let gh = Double(rows) * ch + Double(rows - 1) * gap
        let x0 = area.midX - gw / 2, y0 = area.midY - gh / 2
        return (0..<cards.count).map { Rect(x0 + Double($0 % cols) * (cw + gap), y0 + Double($0 / cols) * (ch + gap), cw, ch) }
    }

    func flip(_ i: Int) {
        guard !matched.contains(i), !open.contains(i) else { return }
        if pending.count == 2 { for k in pending { open.remove(k) }; pending = []; hideTimer = 0 }
        open.insert(i)
        pending.append(i)
        cue(.paper)
        if pending.count == 2 {
            let a = pending[0], b = pending[1]
            if cards[a] == cards[b] {
                matched.formUnion([a, b])
                pending = []
                cue(.confirm)
                if matched.count == cards.count { isOver = true }
            } else {
                wrongFlips += 1
                hideTimer = 0.75
                cue(.cancel)
            }
        }
        seen.insert(i)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        if let i = cardRects(canvas).firstIndex(where: { $0.contains(p) }) { flip(i) }
    }

    /// The bot plays with perfect memory of cards it has seen.
    public func botTap(canvas: Rect) -> Vec2? {
        guard elapsed > 0.3, hideTimer <= 0 else { return nil }
        let rects = cardRects(canvas)
        let closed = (0..<cards.count).filter { !matched.contains($0) && !open.contains($0) }
        if let first = pending.first {
            if let mate = closed.first(where: { seen.contains($0) && cards[$0] == cards[first] }) { return rects[mate].center }
            if let fresh = closed.first(where: { !seen.contains($0) }) { return rects[fresh].center }
            return closed.first.map { rects[$0].center }
        }
        for a in closed where seen.contains(a) {
            if closed.contains(where: { $0 != a && seen.contains($0) && cards[$0] == cards[a] }) { return rects[a].center }
        }
        if let fresh = closed.first(where: { !seen.contains($0) }) { return rects[fresh].center }
        return closed.first.map { rects[$0].center }
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("sm", "Pairs \(matched.count / 2) of \(pairs)", canvas: c)
        ui.mgTimer("sm", clock.fraction, canvas: c)
        for (i, r) in cardRects(c).enumerated() {
            let faceUp = open.contains(i) || matched.contains(i)
            let id = "sm.c\(i)"
            if faceUp {
                let (ic, name) = SupplyMatchGame.supplies[cards[i]]
                let isMatched = matched.contains(i)
                ui.shape(id, ShapeSpec(.rect, w: r.w, h: r.h, radius: 10, fill: isMatched ? Palette.turquoise.lighter(0.55) : Palette.paper,
                                       stroke: isMatched ? Palette.turquoise : Palette.navy, lineWidth: 2, shadow: !isMatched), at: r.origin)
                ui.icon(id + ".ic", ic, center: Vec2(r.midX, r.y + r.h * 0.42), size: min(r.w, r.h) * 0.46, color: Palette.ink)
                ui.text(id + ".t", name, Vec2(r.midX, r.maxY - 19), size: 11, weight: .semibold, color: Palette.inkSoft, align: .center, width: r.w - 6)
                ui.hit(r, .minigameButton(-1), label: name + (isMatched ? ", matched" : ", face up"), id: id)
            } else {
                ui.shape(id, ShapeSpec(.rect, w: r.w, h: r.h, radius: 10, fill: Palette.slate, shadow: true), at: r.origin)
                ui.shape(id + ".in", ShapeSpec(.rect, w: r.w - 12, h: r.h - 12, radius: 7, stroke: Palette.paper.alpha(0.35), lineWidth: 1.5), at: Vec2(r.x + 6, r.y + 6))
                ui.icon(id + ".ic", .plus, center: r.center, size: min(r.w, r.h) * 0.3, color: Palette.paper.alpha(0.5))
                ui.mgTarget(id, r, ax: "Card \(i + 1), face down")
            }
        }
    }
}
