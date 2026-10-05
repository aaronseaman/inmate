import Foundation

/// Grounds: keep the beds alive. Plants ask for water, weeding or a stake. Pick the
/// tool, then tap the plant. Wrong tool on a plant sets it back a little.
public final class GardenGame: MinigameBase, Minigame {
    public let id = MinigameID.garden
    public let title = "Tend the beds"
    public let icon = Icon.seed
    public var controls: [(Icon, String)] {
        [(.water, "Pick a tool at the bottom"), (.hand, "Tap a plant that is asking for it"),
         (.weed, "Water, pull weeds, or stake tall plants"), (.heart, "Healthy beds at the end of the shift pay best")]
    }

    enum Need: Int, CaseIterable { case water, weeds, stake
        var icon: Icon { [Icon.water, .weed, .stake][rawValue] }
        var title: String { ["Water", "Weed", "Stake"][rawValue] }
    }

    struct Plant {
        var health: Double = 0.85
        var growth: Double
        var need: Need?
        var waited: Double = 0
        var staked = false
        var flash: Double = 0
        var flashOK = true
    }

    let cols: Int
    let rows = 2
    var plants: [Plant] = []
    var tool: Need = .water
    var clock: RunClock
    var healthIntegral = 0.0
    var mistakes = 0
    var tended = 0
    let needRate: Double
    let decay: Double

    public init(_ cfg: MinigameConfig) {
        cols = cfg.level >= 2 ? 5 : 4
        clock = RunClock(45)
        needRate = 0.055 * (1 + 0.15 * Double(cfg.level - 1))
        decay = 0.07 / cfg.difficulty.window
        super.init(cfg, salt: "garden")
        for _ in 0..<(cols * rows) { plants.append(Plant(growth: rng.double(0.3, 0.55))) }
        // Start with one obvious job.
        plants[rng.int(0, plants.count - 1)].need = .water
    }

    var averageHealth: Double { healthIntegral / max(0.001, elapsed) }

    public var score: Double {
        guard elapsed > 0 else { return 0 }
        return clamp((averageHealth - 0.4) / 0.52 - 0.02 * Double(mistakes), 0, 1)
    }

    public var summary: String {
        let pct = Int((averageHealth * 100).rounded())
        return "Beds at \(pct)% health · \(tended) jobs done\(mistakes > 0 ? " · \(mistakes) wrong tool" : "")"
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        var sum = 0.0
        for i in plants.indices {
            var p = plants[i]
            p.flash = max(0, p.flash - dt)
            p.growth = min(1, p.growth + dt * 0.012)
            if let _ = p.need {
                p.waited += dt
                p.health = max(0, p.health - decay * dt)
            } else {
                p.health = min(1, p.health + 0.03 * dt)
                // Tall plants need a stake once; otherwise water and weeds come and go.
                if rng.chance(needRate * dt) {
                    if p.growth > 0.7 && !p.staked { p.need = .stake } else { p.need = rng.chance(0.55) ? .water : .weeds }
                    p.waited = 0
                }
            }
            plants[i] = p
            sum += p.health
        }
        healthIntegral += sum / Double(plants.count) * dt
        if clock.tick(dt) { isOver = true }
    }

    // MARK: Layout

    func plantRects(_ c: Rect) -> [Rect] {
        let area = Rect(c.x + 10, c.y + 44, c.w - 20, c.h - 44 - 76)
        let gap = 10.0
        let w = min(120, (area.w - Double(cols - 1) * gap) / Double(cols))
        let h = min(110, (area.h - gap) / 2)
        let gw = Double(cols) * w + Double(cols - 1) * gap
        let x0 = area.midX - gw / 2, y0 = area.midY - (2 * h + gap) / 2
        return (0..<plants.count).map { Rect(x0 + Double($0 % cols) * (w + gap), y0 + Double($0 / cols) * (h + gap), w, h) }
    }

    func toolRects(_ c: Rect) -> [Rect] {
        let bw = 128.0, bh = 58.0, gap = 12.0
        let x0 = c.midX - (3 * bw + 2 * gap) / 2
        return (0..<3).map { Rect(x0 + Double($0) * (bw + gap), c.maxY - bh - 6, bw, bh) }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        if let t = toolRects(canvas).firstIndex(where: { UIBuilder.touchTarget($0).contains(p) }) {
            tool = Need(rawValue: t)!
            cue(.tap)
            return
        }
        guard let i = plantRects(canvas).firstIndex(where: { $0.contains(p) }) else { return }
        var pl = plants[i]
        if let need = pl.need, need == tool {
            pl.need = nil
            if need == .stake { pl.staked = true }
            pl.health = min(1, pl.health + 0.08)
            pl.flash = 0.35; pl.flashOK = true
            tended += 1
            cue(need == .water ? .splash : .swish)
        } else {
            // Watering a happy plant drowns it a bit; pulling at nothing tramples it.
            mistakes += 1
            pl.health = max(0, pl.health - 0.08)
            pl.flash = 0.35; pl.flashOK = false
            cue(.error)
        }
        plants[i] = pl
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard elapsed > 0.25 else { return nil }
        let needy = plants.indices.filter { plants[$0].need != nil }.sorted { plants[$0].waited > plants[$1].waited }
        guard let i = needy.first, let need = plants[i].need else { return nil }
        if need != tool { return toolRects(canvas)[need.rawValue].center }
        return plantRects(canvas)[i].center
    }

    // MARK: Render

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("gd", "Beds \(Int((plants.map { $0.health }.reduce(0, +) / Double(plants.count) * 100).rounded()))% healthy", canvas: c)
        ui.mgTimer("gd", clock.fraction, canvas: c)
        for (i, r) in plantRects(c).enumerated() {
            let p = plants[i]
            let id = "gd.p\(i)"
            var soil = Palette.wood.darker(0.15)
            if p.flash > 0 { soil = p.flashOK ? Palette.statusGreen : Palette.coral }
            ui.shape(id, ShapeSpec(.rect, w: r.w, h: r.h, radius: 12, fill: Palette.grass.lighter(0.15)), at: r.origin)
            ui.shape(id + ".soil", ShapeSpec(.rect, w: r.w - 16, h: 18, radius: 9, fill: soil), at: Vec2(r.x + 8, r.maxY - 26))
            let leaf = Palette.grassDark.darker(0.25 * (1 - p.health)).mix(Palette.ochre, 1 - p.health)
            let hgt = (r.h - 40) * (0.35 + 0.65 * p.growth)
            let stemX = r.midX - 3
            ui.shape(id + ".stem", ShapeSpec(.rect, w: 6, h: hgt, radius: 3, fill: leaf.darker(0.15)), at: Vec2(stemX, r.maxY - 22 - hgt))
            let lw = 18 + 10 * p.growth
            for k in 0..<3 {
                let ly = r.maxY - 22 - hgt * (0.35 + 0.3 * Double(k))
                let side = k % 2 == 0 ? -1.0 : 1.0
                ui.shape("\(id).lf\(k)", ShapeSpec(.circle, w: lw, h: lw * 0.55, fill: leaf), at: Vec2(r.midX + side * lw * 0.45 - lw / 2, ly - lw * 0.27))
            }
            if p.growth > 0.75 {
                ui.shape(id + ".fruit", ShapeSpec(.circle, w: 14, h: 14, fill: Palette.coral), at: Vec2(r.midX - 7, r.maxY - 22 - hgt - 6))
            }
            if p.staked {
                ui.shape(id + ".stake", ShapeSpec(.rect, w: 4, h: hgt + 8, radius: 2, fill: Palette.wood), at: Vec2(stemX + 12, r.maxY - 24 - hgt))
            }
            if let need = p.need {
                let urgent = p.waited > 6
                ui.badge(id + ".need", need.icon, center: Vec2(r.maxX - 18, r.y + 18), size: 28, bg: urgent ? Palette.coral : Palette.navy, fg: Palette.paper)
            }
            let state = p.need.map { "needs: \($0.title.lowercased())" } ?? "fine"
            ui.mgTarget(id + ".t", r, ax: "Plant \(i + 1), \(state), health \(Int(p.health * 100)) percent")
        }
        for (t, r) in toolRects(c).enumerated() {
            let need = Need(rawValue: t)!
            ui.mgButton("gd.tool\(t)", r, icon: need.icon, label: need.title, style: tool == need ? .tileSelected : .tile, ax: "Tool: \(need.title)")
        }
    }
}
