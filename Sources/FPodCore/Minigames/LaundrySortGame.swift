import Foundation

/// Laundry: garments land on the folding table one at a time. Tap the matching bin
/// before the pile backs up. Check bulging pockets first — the owner will want it back.
public final class LaundrySortGame: MinigameBase, Minigame {
    public let id = MinigameID.laundrySort
    public let title = "Sort the wash"
    public let icon = Icon.laundry
    public var controls: [(Icon, String)] {
        [(.shirt, "A garment lands on the table"), (.hand, "Tap the bin with the matching color"),
         (.note, "Bulging pocket? Tap the garment first to check it"), (.clock, "Keep up — the pile backs up")]
    }

    struct Bin { let title: String; let icon: Icon; let color: RGBA }
    static let allBins: [Bin] = [
        Bin(title: "Tan scrubs", icon: .shirt, color: Palette.tan),
        Bin(title: "Whites", icon: .coat, color: RGBA(hex: 0xF4F2EC)),
        Bin(title: "Linens", icon: .sheet, color: Palette.blueGray),
        Bin(title: "Staff navy", icon: .shirt, color: Palette.navy),
    ]

    struct Garment {
        let bin: Int
        let icon: Icon
        let pocket: Bool
        var checked = false
    }

    let bins: [Bin]
    let total: Int
    var queue: [Garment] = []
    var index = 0
    var garmentTime: Double
    let perGarment: Double
    var correct = 0
    var wrong = 0
    var late = 0
    var pocketsTotal = 0
    var pocketsChecked = 0
    var pocketsLost = 0
    var flash: (bin: Int, ok: Bool, t: Double)?
    var found: [Icon] = []

    public init(_ cfg: MinigameConfig) {
        let nb = cfg.level >= 2 ? 4 : 3
        bins = Array(LaundrySortGame.allBins.prefix(nb))
        total = 14 + 2 * (cfg.level - 1)
        perGarment = 3.4 * cfg.difficulty.window * (1 - 0.07 * Double(cfg.level - 1))
        garmentTime = perGarment
        super.init(cfg, salt: "laundry")
        let shapes: [[Icon]] = [[.shirt], [.coat, .gown], [.sheet], [.shirt]]
        for _ in 0..<total {
            let b = rng.int(0, nb - 1)
            let ic = rng.pick(shapes[b]) ?? .shirt
            let pocket = (b == 0 || b == 3) && rng.chance(0.28)
            if pocket { pocketsTotal += 1 }
            queue.append(Garment(bin: b, icon: ic, pocket: pocket))
        }
    }

    var current: Garment? { index < queue.count ? queue[index] : nil }

    public var score: Double {
        let base = Double(correct) / Double(max(1, total))
        let pockets = pocketsTotal == 0 ? 1 : Double(pocketsChecked) / Double(pocketsTotal)
        return clamp(base * 0.88 + pockets * 0.12 - 0.04 * Double(wrong), 0, 1)
    }

    public var summary: String {
        var s = "Sorted \(correct)/\(total)"
        if wrong > 0 { s += " · \(wrong) wrong bin\(wrong == 1 ? "" : "s")" }
        if pocketsTotal > 0 { s += " · pockets checked \(pocketsChecked)/\(pocketsTotal)" }
        return s
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let f = flash { flash = f.t - dt > 0 ? (f.bin, f.ok, f.t - dt) : nil }
        garmentTime -= dt
        if garmentTime <= 0 {
            late += 1
            if let g = current, g.pocket && !g.checked { pocketsLost += 1 }
            cue(.error)
            advance()
        }
    }

    func advance() {
        index += 1
        garmentTime = perGarment
        if index >= queue.count { isOver = true }
    }

    // MARK: Layout

    func tableRect(_ c: Rect) -> Rect {
        let w = min(220, c.w * 0.32), h = min(150, c.h * 0.5)
        return Rect(c.midX - w / 2, c.y + 48, w, h)
    }

    func binRects(_ c: Rect) -> [Rect] {
        let n = bins.count
        let bw = min(150, (c.w - 40 - Double(n - 1) * 12) / Double(n))
        let bh = min(86, c.maxY - tableRect(c).maxY - 18)
        let x0 = c.midX - (Double(n) * bw + Double(n - 1) * 12) / 2
        return (0..<n).map { Rect(x0 + Double($0) * (bw + 12), c.maxY - bh - 6, bw, bh) }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, var g = current else { return }
        if tableRect(canvas).contains(p) {
            if g.pocket && !g.checked {
                g.checked = true
                queue[index] = g
                pocketsChecked += 1
                found.append(rng.pick([.photo, .letter, .note, .card, .pencil]) ?? .note)
                cue(.paper)
            }
            return
        }
        guard let b = binRects(canvas).firstIndex(where: { UIBuilder.touchTarget($0).contains(p) }) else { return }
        if b == g.bin {
            correct += 1
            cue(.swish)
            flash = (b, true, 0.25)
        } else {
            wrong += 1
            cue(.error)
            flash = (b, false, 0.35)
        }
        if g.pocket && !g.checked { pocketsLost += 1 }
        advance()
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard let g = current, elapsed > 0.3 else { return nil }
        if g.pocket && !g.checked { return tableRect(canvas).center }
        return binRects(canvas)[g.bin].center
    }

    // MARK: Render

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("ls", "Sorted \(correct + wrong) of \(total)", canvas: c)
        ui.mgPips("ls", total: total, good: correct, bad: wrong + late, center: Vec2(c.maxX - 150, c.y + 26))
        let tr = tableRect(c)
        ui.shape("ls.table", ShapeSpec(.rect, w: tr.w, h: tr.h, radius: 14, fill: Palette.wood.lighter(0.35), shadow: true), at: tr.origin)
        // The waiting pile.
        let pile = min(5, queue.count - index - 1)
        for k in 0..<max(0, pile) {
            let g = queue[index + 1 + k]
            ui.shape("ls.pile\(k)", ShapeSpec(.rect, w: 46, h: 14, radius: 6, fill: bins[g.bin].color, stroke: Palette.wallEdge),
                     at: Vec2(tr.x - 64, tr.maxY - 22 - Double(k) * 15))
        }
        if let g = current {
            let col = bins[g.bin].color
            let sz = min(tr.h - 30, 104)
            ui.icon("ls.gline", g.icon, center: tr.center + Vec2(0, 2), size: sz * 1.06, color: Palette.ink.alpha(0.18))
            ui.icon("ls.gfill", g.icon, center: tr.center, size: sz, color: col)
            if g.pocket && !g.checked {
                ui.badge("ls.pocket", .note, center: Vec2(tr.midX + sz * 0.26, tr.midY + sz * 0.12), size: 26, bg: Palette.ochre, fg: Palette.paper)
                ui.mgTarget("ls.check", tr, ax: "Check the pocket")
            }
            // Per-garment timer ring under the table.
            let f = clamp(garmentTime / perGarment, 0, 1)
            ui.shape("ls.gtbg", ShapeSpec(.rect, w: tr.w - 24, h: 6, radius: 3, fill: Palette.blueGray), at: Vec2(tr.x + 12, tr.maxY - 12))
            ui.shape("ls.gt", ShapeSpec(.rect, w: max(6, (tr.w - 24) * f), h: 6, radius: 3, fill: f < 0.3 ? Palette.coral : Palette.slate), at: Vec2(tr.x + 12, tr.maxY - 12))
        }
        // Lost & found tray.
        if !found.isEmpty {
            let lx = tr.maxX + 26
            ui.text("ls.lf", "Lost & found", Vec2(lx, tr.y + 4), size: 11, weight: .bold, color: Palette.slate, width: 120)
            for (k, ic) in found.suffix(6).enumerated() {
                ui.badge("ls.f\(k)", ic, center: Vec2(lx + 14 + Double(k % 3) * 32, tr.y + 36 + Double(k / 3) * 32), size: 26, bg: Palette.ivory, fg: Palette.ink)
            }
        }
        for (b, r) in binRects(c).enumerated() {
            var style: ButtonStyle = .tile
            if let f = flash, f.bin == b { style = f.ok ? .tileSelected : .danger }
            ui.mgButton("ls.bin\(b)", r, style: style, ax: "Bin: \(bins[b].title)")
            let sw = min(34, r.h * 0.42)
            ui.shape("ls.sw\(b)", ShapeSpec(.circle, w: sw, h: sw, fill: bins[b].color, stroke: Palette.wallEdge, lineWidth: 1.5),
                     at: Vec2(r.midX - sw / 2, r.y + 8))
            ui.icon("ls.si\(b)", bins[b].icon, center: Vec2(r.midX, r.y + 8 + sw / 2), size: sw * 0.6, color: b == 3 ? Palette.paper : Palette.ink.alpha(0.6))
            ui.text("ls.bt\(b)", bins[b].title, Vec2(r.midX, r.maxY - 22), size: 12.5, weight: .semibold,
                    color: UIBuilder.foreground(style), align: .center, width: r.w - 8)
        }
    }
}
