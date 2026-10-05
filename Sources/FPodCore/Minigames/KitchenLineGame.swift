import Foundation

/// Kitchen: trays ride the line past the serving window. Tap the bins to put the
/// right things on the front tray before it slides past. Diet trays never get sugar.
public final class KitchenLineGame: MinigameBase, Minigame {
    public let id = MinigameID.kitchenLine
    public let title = "Tray line"
    public let icon = Icon.pan
    public var controls: [(Icon, String)] {
        [(.list, "Each tray shows its ticket"), (.hand, "Tap a bin to add that to the tray at the window"),
         (.heart, "Diet trays (heart card) never get sugar"), (.clock, "Finish the tray before it slides past")]
    }

    static let foods: [(icon: Icon, label: String)] = [(.plate, "Main"), (.cup, "Milk"), (.tomato, "Salad"), (.snack, "Bread"), (.sugar, "Sweet")]

    struct Tray {
        var order: [Int]
        var placed: Set<Int> = []
        var pos: Double
        var diet: Bool
        var state: State = .waiting
        enum State { case waiting, served, missed }
        var complete: Bool { Set(order) == placed }
    }

    var trays: [Tray] = []
    let total: Int
    var spawned = 0
    var served = 0
    var missed = 0
    var mixups = 0
    var dietErrors = 0
    let speed: Double
    let spacing = 0.34
    var flashBin: (Int, Double, Bool)?
    static let windowStart = 0.36
    static let missAt = 0.9

    public init(_ cfg: MinigameConfig) {
        total = 9 + 2 * (cfg.level - 1)
        speed = 0.078 * (1 + 0.1 * Double(cfg.level - 1)) / cfg.difficulty.window
        super.init(cfg, salt: "kitchen")
        spawn(at: 0.12)
    }

    func spawn(at pos: Double) {
        guard spawned < total else { return }
        spawned += 1
        let diet = rng.chance(0.25)
        let count = min(4, 2 + rng.int(0, cfg.level >= 2 ? 2 : 1))
        var pool = Array(0..<(diet ? 4 : 5))
        rng.shuffle(&pool)
        var order = Array(pool.prefix(count))
        order.sort()
        trays.append(Tray(order: order, pos: pos, diet: diet))
    }

    /// The tray at the window that bins currently serve.
    var activeIndex: Int? {
        trays.indices.first { trays[$0].state == .waiting && trays[$0].pos >= KitchenLineGame.windowStart - 0.02 }
    }

    public var score: Double {
        clamp((Double(served) - 0.25 * Double(mixups)) / Double(max(1, total)), 0, 1)
    }

    public var summary: String {
        var s = "Served \(served)/\(total) trays"
        if mixups > 0 { s += " · \(mixups) mix-up\(mixups == 1 ? "" : "s")" }
        if dietErrors > 0 { s += " · sugar on a diet tray" }
        return s
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let f = flashBin { flashBin = f.1 - dt > 0 ? (f.0, f.1 - dt, f.2) : nil }
        // An empty window hurries the line along.
        let idle = activeIndex == nil ? 3.0 : 1.0
        for i in trays.indices {
            let fast = trays[i].state == .served ? 4.0 : idle
            trays[i].pos += speed * fast * dt
            if trays[i].state == .waiting && trays[i].pos > KitchenLineGame.missAt {
                trays[i].state = .missed
                missed += 1
                cue(.error)
            }
        }
        // Keep the line fed: a new tray enters once the last one has moved along.
        if let last = trays.last, spawned < total, last.pos - 0.12 >= spacing || !trays.contains(where: { $0.state == .waiting }) {
            spawn(at: min(0.12, last.pos - spacing))
        }
        trays.removeAll { $0.pos > 1.25 }
        if spawned >= total && !trays.contains(where: { $0.state == .waiting }) { isOver = true }
    }

    // MARK: Layout

    struct Layout {
        var belt: Rect
        var window: Rect
        var bins: [Rect]
        var trayW: Double
        var trayH: Double
    }

    func layout(_ c: Rect) -> Layout {
        let belt = Rect(c.x + 10, c.y + 50, c.w - 20, min(136, c.h * 0.45))
        let wx0 = belt.x + KitchenLineGame.windowStart * belt.w
        let wx1 = belt.x + KitchenLineGame.missAt * belt.w
        let window = Rect(wx0 - 52, belt.y - 6, wx1 - wx0 + 104, belt.h + 12)
        let n = KitchenLineGame.foods.count
        let bw = min(104, (c.w - 40 - Double(n - 1) * 10) / Double(n))
        let bh = min(80, c.maxY - belt.maxY - 18)
        let x0 = c.midX - (Double(n) * bw + Double(n - 1) * 10) / 2
        let bins = (0..<n).map { Rect(x0 + Double($0) * (bw + 10), c.maxY - bh - 8, bw, bh) }
        return Layout(belt: belt, window: window, bins: bins, trayW: min(112, belt.w * 0.15), trayH: belt.h - 20)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        let L = layout(canvas)
        guard let b = L.bins.firstIndex(where: { UIBuilder.touchTarget($0).contains(p) }) else { return }
        guard let ai = activeIndex else { cue(.cancel); return }
        var t = trays[ai]
        if t.order.contains(b) && !t.placed.contains(b) {
            t.placed.insert(b)
            cue(.pickup)
            flashBin = (b, 0.25, true)
            if t.complete {
                t.state = .served
                served += 1
                cue(.coin)
            }
        } else {
            mixups += 1
            if t.diet && b == 4 { dietErrors += 1 }
            cue(.error)
            flashBin = (b, 0.35, false)
        }
        trays[ai] = t
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard let ai = activeIndex, trays[ai].pos > KitchenLineGame.windowStart + 0.02 else { return nil }
        let t = trays[ai]
        guard let need = t.order.first(where: { !t.placed.contains($0) }) else { return nil }
        return layout(canvas).bins[need].center
    }

    // MARK: Render

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        let L = layout(c)
        ui.mgHeader("kl", "Trays served: \(served) of \(total)", canvas: c)
        ui.mgPips("kl", total: total, good: served, bad: missed, center: Vec2(c.maxX - 150, c.y + 26))
        // Serving window and belt.
        ui.shape("kl.win", ShapeSpec(.rect, w: L.window.w, h: L.window.h, radius: 14, fill: Palette.ochre.alpha(0.18), stroke: Palette.ochre, lineWidth: 2),
                 at: L.window.origin)
        ui.shape("kl.belt", ShapeSpec(.rect, w: L.belt.w, h: L.belt.h, radius: 10, fill: Palette.metal.alpha(0.55)), at: L.belt.origin)
        let stripe = 36.0
        let offset = (elapsed * speed * L.belt.w).truncatingRemainder(dividingBy: stripe)
        var k = 0
        var x = L.belt.x + offset
        while x < L.belt.maxX - 4 {
            ui.shape("kl.st\(k)", ShapeSpec(.rect, w: 3, h: L.belt.h - 16, radius: 1.5, fill: Palette.slate.alpha(0.18)), at: Vec2(x, L.belt.y + 8))
            k += 1; x += stripe
        }
        let active = activeIndex
        for (i, t) in trays.enumerated() {
            let cx = L.belt.x + t.pos * L.belt.w
            guard cx > L.belt.x - L.trayW, cx < L.belt.maxX + L.trayW else { continue }
            let r = Rect(cx - L.trayW / 2, L.belt.y + 10, L.trayW, L.trayH)
            let tid = "kl.t\(i)"
            let isActive = i == active
            let alpha = t.state == .waiting ? 1.0 : 0.55
            ui.shape(tid, ShapeSpec(.rect, w: r.w, h: r.h, radius: 10, fill: t.state == .missed ? Palette.coral.lighter(0.4) : Palette.paper,
                                   stroke: isActive ? Palette.navy : Palette.wallEdge, lineWidth: isActive ? 3 : 1.5, shadow: true), at: r.origin, alpha: alpha)
            if t.diet {
                ui.badge(tid + ".diet", .heart, center: Vec2(r.maxX - 10, r.y + 10), size: 20, bg: Palette.coral, fg: Palette.paper, alpha: alpha)
            }
            let cell = min((r.w - 12) / 2, (r.h - 12) / 2)
            let rows = (t.order.count + 1) / 2
            for (j, f) in t.order.enumerated() {
                let gx = r.midX + (Double(j % 2) - 0.5) * cell
                let gy = r.midY + (Double(j / 2) - Double(rows - 1) / 2) * cell
                let done = t.placed.contains(f)
                ui.icon("\(tid).f\(j)", KitchenLineGame.foods[f].icon, center: Vec2(gx, gy), size: cell * 0.7,
                        color: done ? Palette.ink : Palette.inkSoft.alpha(0.3), alpha: alpha)
            }
            if t.state == .served { ui.badge(tid + ".ok", .check, center: r.center, size: 30, bg: Palette.statusGreen, fg: Palette.paper) }
        }
        for (b, r) in L.bins.enumerated() {
            var style: ButtonStyle = .tile
            if let f = flashBin, f.0 == b { style = f.2 ? .tileSelected : .danger }
            ui.mgButton("kl.bin\(b)", r, icon: KitchenLineGame.foods[b].icon, label: KitchenLineGame.foods[b].label, style: style,
                        ax: "Add \(KitchenLineGame.foods[b].label.lowercased()) to the tray")
        }
    }
}
