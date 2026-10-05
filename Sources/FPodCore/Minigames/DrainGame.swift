import Foundation

/// Mouse's note, down the shower drain. Lower a bent-wire hook past sliding baffles:
/// tap when the gap lines up. A miss clanks (loud) and costs a moment.
public final class DrainGame: MinigameBase, Minigame {
    public let id = MinigameID.drain
    public let title = "Down the drain"
    public let icon = Icon.water
    public var controls: [(Icon, String)] {
        [(.arrowDown, "Tap to drop the hook one level"), (.target, "Drop when the gap lines up with the hook"),
         (.sound, "A miss clanks — loud, and a short wait"), (.note, "Hook the paper at the bottom")]
    }

    struct Baffle { let speed: Double; let phase: Double; let amp: Double }
    let baffles: [Baffle]
    let gap: Double
    var depth = 0
    var clanks = 0
    var stun: Double = 0
    var clock: RunClock
    var hooked = false
    var flash: Double = 0

    public init(_ cfg: MinigameConfig) {
        let n = 3 + min(3, cfg.level)
        gap = 0.2 * cfg.difficulty.window
        clock = RunClock(32 * cfg.difficulty.window + Double(n) * 3)
        var r = RNG(seed: cfg.seed ^ 0xD4A1)
        baffles = (0..<n).map { _ in Baffle(speed: r.double(1.2, 2.2) * (1 + 0.1 * Double(cfg.level - 1)), phase: r.double(0, 6.28), amp: r.double(0.25, 0.38)) }
        super.init(cfg, salt: "drain")
    }

    /// Gap center of baffle i (0...1 across the shaft).
    func gapCenter(_ i: Int) -> Double { 0.5 + baffles[i].amp * sin(elapsed * baffles[i].speed + baffles[i].phase) }
    var aligned: Bool { depth < baffles.count && abs(gapCenter(depth) - 0.5) <= gap / 2 }

    public var score: Double {
        let progress = hooked ? 1 : Double(depth) / Double(baffles.count + 1)
        return clamp(0.75 * progress + (hooked ? 0.25 * max(0, 1 - Double(clanks) / 5) : 0), 0, 1)
    }

    public var summary: String { hooked ? "Hooked it · \(clanks) clank\(clanks == 1 ? "" : "s")" : "Got \(depth) of \(baffles.count) levels down" }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        stun = max(0, stun - dt)
        flash = max(0, flash - dt)
        if clock.tick(dt) { isOver = true }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, stun <= 0 else { return }
        if depth >= baffles.count {
            hooked = true
            isOver = true
            cue(.success)
            return
        }
        if aligned {
            depth += 1
            cue(.swish)
        } else {
            clanks += 1
            stun = 0.9
            flash = 0.3
            cue(.clank)
        }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard stun <= 0 else { return nil }
        if depth >= baffles.count { return canvas.center }
        return abs(gapCenter(depth) - 0.5) <= gap * 0.25 ? canvas.center : nil
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("dr", depth >= baffles.count ? "Tap to hook it!" : "Level \(depth + 1) of \(baffles.count)", canvas: c)
        ui.mgTimer("dr", clock.fraction, canvas: c)
        let shaftW = min(260, c.w * 0.4)
        let shaft = Rect(c.midX - shaftW / 2, c.y + 44, shaftW, c.h - 50)
        ui.shape("dr.shaft", ShapeSpec(.rect, w: shaft.w, h: shaft.h, radius: 10, fill: Palette.slate.darker(0.25)), at: shaft.origin)
        ui.shape("dr.water", ShapeSpec(.rect, w: shaft.w - 12, h: 22, radius: 6, fill: Palette.turquoise.alpha(0.45)), at: Vec2(shaft.x + 6, shaft.maxY - 28))
        let n = baffles.count
        let step = (shaft.h - 40) / Double(n + 1)
        for i in 0..<n {
            let y = shaft.y + step * Double(i + 1)
            let gc = shaft.x + gapCenter(i) * shaft.w
            let gw = gap * shaft.w
            let col = i < depth ? Palette.metal.alpha(0.35) : (i == depth ? Palette.metal : Palette.metal.darker(0.2))
            let left = max(0, gc - gw / 2 - shaft.x)
            let right = max(0, shaft.maxX - (gc + gw / 2))
            if left > 1 { ui.shape("dr.bl\(i)", ShapeSpec(.rect, w: left, h: 10, radius: 3, fill: col), at: Vec2(shaft.x, y - 5)) }
            if right > 1 { ui.shape("dr.br\(i)", ShapeSpec(.rect, w: right, h: 10, radius: 3, fill: col), at: Vec2(gc + gw / 2, y - 5)) }
        }
        // The hook on its wire.
        let hookY = shaft.y + step * Double(depth) + (depth == 0 ? 14 : 12)
        ui.shape("dr.wire", ShapeSpec(.rect, w: 3, h: max(4, hookY - shaft.y + 10), fill: Palette.ochre), at: Vec2(shaft.midX - 1.5, shaft.y - 10))
        ui.shape("dr.hook", ShapeSpec(.ring, w: 16, h: 16, stroke: flash > 0 ? Palette.coral : Palette.ochre, lineWidth: 3), at: Vec2(shaft.midX - 8, hookY))
        ui.icon("dr.note", .note, center: Vec2(shaft.midX, shaft.maxY - 40), size: 26, color: hooked ? Palette.statusGreen : Palette.paper)
        ui.text("dr.tip", "Tap anywhere when the gap is under the hook", Vec2(c.midX, c.maxY - 2), size: 11.5, color: Palette.inkSoft, align: .center, width: c.w - 40)
        ui.mgTarget("dr.tap", Rect(c.x, c.y + 40, c.w, c.h - 40), ax: "Drop the hook")
    }
}
