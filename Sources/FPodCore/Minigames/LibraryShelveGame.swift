import Foundation

/// Library: shelve returned books by call number. Tap the gap on the shelf where the
/// book on the cart belongs. Later shifts bring decimals (364.12 comes before 364.2).
public final class LibraryShelveGame: MinigameBase, Minigame {
    public let id = MinigameID.libraryShelve
    public let title = "Shelve the returns"
    public let icon = Icon.book
    public var controls: [(Icon, String)] {
        [(.book, "The cart shows the next returned book"), (.hand, "Tap the gap where its number belongs"),
         (.list, "Numbers go smallest to largest, left to right"), (.info, "Decimals compare digit by digit: 364.12 before 364.2")]
    }

    /// Call numbers are stored as fixed-point: whole part and a decimal string.
    struct CallNumber: Equatable {
        let whole: Int
        let decimals: String
        var text: String { decimals.isEmpty ? "\(whole)" : "\(whole).\(decimals)" }
        static func < (a: CallNumber, b: CallNumber) -> Bool {
            if a.whole != b.whole { return a.whole < b.whole }
            return a.decimals.lexicographicallyPrecedes(b.decimals)
        }
    }

    let total: Int
    var round = 0
    var shelf: [CallNumber] = []
    var book = CallNumber(whole: 0, decimals: "")
    var firstTry = 0
    var placed = 0
    var mistakes = 0
    var mistakesThisBook = 0
    var clock: RunClock
    var flash: (gap: Int, ok: Bool, t: Double)?
    var spines: [RGBA] = []

    public init(_ cfg: MinigameConfig) {
        total = 9 + 2 * (cfg.level - 1)
        clock = RunClock((52 + 6 * Double(cfg.level - 1)) * cfg.difficulty.window)
        super.init(cfg, salt: "library")
        newRound()
    }

    func makeNumber(base: Int) -> CallNumber {
        if cfg.level < 2 || rng.chance(0.3) { return CallNumber(whole: base + rng.int(0, 60), decimals: "") }
        let digits = rng.int(1, cfg.level >= 3 ? 3 : 2)
        var d = ""
        for k in 0..<digits { d += String(rng.int(k == digits - 1 ? 1 : 0, 9)) }
        return CallNumber(whole: base + rng.int(0, 6), decimals: d)
    }

    func newRound() {
        let base = 100 + rng.int(0, 8) * 100
        var set: [CallNumber] = []
        while set.count < 8 {
            let n = makeNumber(base: base)
            if !set.contains(n) { set.append(n) }
        }
        set.sort(by: <)
        // The returned book is one of the eight; the shelf holds the other seven.
        let pick = rng.int(0, 7)
        book = set[pick]
        set.remove(at: pick)
        shelf = set
        spines = (0..<7).map { _ in rng.pick([Palette.coral, Palette.turquoise, Palette.ochre, Palette.slate, Palette.navy, Palette.wood]) ?? Palette.slate }
        mistakesThisBook = 0
    }

    /// Gap g sits before shelf[g]; gap 7 is after the last book.
    var correctGap: Int { shelf.firstIndex(where: { book < $0 }) ?? shelf.count }

    public var score: Double {
        let acc = Double(firstTry) / Double(max(1, total))
        let done = Double(placed) / Double(max(1, total))
        return clamp(0.55 * acc + 0.35 * done + 0.1 * clock.fraction * done, 0, 1)
    }

    public var summary: String {
        "Shelved \(placed)/\(total) · \(firstTry) on the first try"
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let f = flash { flash = f.t - dt > 0 ? (f.gap, f.ok, f.t - dt) : nil }
        if clock.tick(dt) { isOver = true }
    }

    // MARK: Layout

    struct Layout { var shelf: Rect; var books: [Rect]; var gaps: [Rect]; var cart: Rect }

    func layout(_ c: Rect) -> Layout {
        let shelf = Rect(c.x + 16, c.y + 50, c.w - 32, min(150, c.h * 0.5))
        let n = 7
        let gapW = 30.0
        let bookW = min(78, (shelf.w - Double(n + 1) * gapW) / Double(n))
        let rowW = Double(n) * bookW + Double(n + 1) * gapW
        let x0 = shelf.midX - rowW / 2
        var books: [Rect] = [], gaps: [Rect] = []
        for g in 0...n {
            let gx = x0 + Double(g) * (bookW + gapW)
            gaps.append(Rect(gx, shelf.y + 8, gapW, shelf.h - 16))
            if g < n { books.append(Rect(gx + gapW, shelf.y + 14, bookW, shelf.h - 28)) }
        }
        let cart = Rect(c.midX - 90, shelf.maxY + 12, 180, min(84, c.maxY - shelf.maxY - 18))
        return Layout(shelf: shelf, books: books, gaps: gaps, cart: cart)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        let L = layout(canvas)
        guard let g = L.gaps.firstIndex(where: { $0.insetBy(dx: -8, dy: 0).contains(p) }) else { return }
        if g == correctGap {
            placed += 1
            if mistakesThisBook == 0 { firstTry += 1 }
            cue(.paper)
            flash = (g, true, 0.3)
            if placed >= total { isOver = true } else { newRound() }
        } else {
            mistakes += 1
            mistakesThisBook += 1
            cue(.error)
            flash = (g, false, 0.35)
        }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard elapsed > 0.4, flash == nil else { return nil }
        return layout(canvas).gaps[correctGap].center
    }

    // MARK: Render

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        let L = layout(c)
        ui.mgHeader("lb", "Shelved \(placed) of \(total)", canvas: c)
        ui.mgTimer("lb", clock.fraction, canvas: c)
        ui.shape("lb.shelf", ShapeSpec(.rect, w: L.shelf.w, h: L.shelf.h, radius: 10, fill: Palette.wood.lighter(0.25), shadow: true), at: L.shelf.origin)
        ui.shape("lb.board", ShapeSpec(.rect, w: L.shelf.w, h: 10, radius: 4, fill: Palette.wood.darker(0.12)), at: Vec2(L.shelf.x, L.shelf.maxY - 10))
        for (i, r) in L.books.enumerated() where i < shelf.count {
            ui.shape("lb.b\(i)", ShapeSpec(.rect, w: r.w, h: r.h, radius: 5, fill: spines[i % spines.count]), at: r.origin)
            ui.shape("lb.lbl\(i)", ShapeSpec(.rect, w: r.w - 8, h: 24, radius: 4, fill: Palette.paper), at: Vec2(r.x + 4, r.y + 10))
            ui.text("lb.n\(i)", shelf[i].text, Vec2(r.midX, r.y + 13), size: 12.5, weight: .bold, align: .center, width: r.w - 8)
        }
        let hint = mistakesThisBook >= 2 ? correctGap : -1
        for (g, r) in L.gaps.enumerated() {
            var stroke = Palette.navy.alpha(0.25)
            var fill = Palette.paper.alpha(0.35)
            if let f = flash, f.gap == g { fill = f.ok ? Palette.statusGreen.alpha(0.6) : Palette.coral.alpha(0.6); stroke = fill }
            if g == hint { stroke = Palette.ochre; fill = Palette.ochre.alpha(0.3) }
            ui.shape("lb.g\(g)", ShapeSpec(.rect, w: r.w - 8, h: r.h, radius: 6, fill: fill, stroke: stroke, lineWidth: 2), at: Vec2(r.x + 4, r.y))
            let left = g == 0 ? "the start" : shelf[g - 1].text
            let right = g == shelf.count ? "the end" : shelf[g].text
            ui.mgTarget("lb.gt\(g)", r, ax: "Gap between \(left) and \(right)")
        }
        // The cart with the returned book.
        let cr = L.cart
        ui.shape("lb.cart", ShapeSpec(.rect, w: cr.w, h: cr.h, radius: 12, fill: Palette.metal.alpha(0.5)), at: cr.origin)
        ui.icon("lb.carti", .cart, center: Vec2(cr.x + 26, cr.midY), size: 30, color: Palette.slate)
        let br = Rect(cr.x + 52, cr.y + 8, cr.w - 62, cr.h - 16)
        ui.shape("lb.book", ShapeSpec(.rect, w: br.w, h: br.h, radius: 6, fill: Palette.coral, shadow: true), at: br.origin)
        ui.shape("lb.booklbl", ShapeSpec(.rect, w: br.w - 14, h: br.h - 18, radius: 5, fill: Palette.paper), at: Vec2(br.x + 7, br.y + 9))
        ui.text("lb.booknum", book.text, Vec2(br.midX, br.midY - 11), size: 18, weight: .bold, align: .center, width: br.w - 14)
    }
}
