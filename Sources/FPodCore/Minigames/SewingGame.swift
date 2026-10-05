import Foundation

/// Workshop: stitch a seam. The needle swings across the tension bar; tap when it is
/// inside the mark to set a straight stitch. Off the mark, the stitch goes crooked.
public final class SewingGame: MinigameBase, Minigame {
    public let id = MinigameID.sewing
    public let title = "Stitch the seam"
    public let icon = Icon.needle
    public var controls: [(Icon, String)] {
        [(.needle, "The needle swings across the bar"), (.hand, "Tap anywhere when it is inside the mark"),
         (.check, "Straight stitches make a good seam"), (.clock, "Feld wants it done before the bell")]
    }

    let total: Int
    var stitches: [Bool] = []
    var phase: Double = 0
    let speed: Double
    var zoneCenter: Double = 0.5
    let zoneWidth: Double
    var clock: RunClock
    var flash: (ok: Bool, t: Double)?
    let wave: (a: Double, f: Double, p: Double)
    var cooldown: Double = 0

    public init(_ cfg: MinigameConfig) {
        total = 12 + 2 * (cfg.level - 1)
        speed = 2.3 * (1 + 0.12 * Double(cfg.level - 1)) / cfg.difficulty.window.squareRoot()
        zoneWidth = 0.17 * cfg.difficulty.window * (1 - 0.08 * Double(cfg.level - 1))
        clock = RunClock((40 + 5 * Double(cfg.level - 1)) * cfg.difficulty.window)
        var r = RNG(seed: cfg.seed ^ 0x5E3)
        wave = (r.double(0.18, 0.32), r.double(1.2, 2.2), r.double(0, 6.28))
        super.init(cfg, salt: "sewing")
        newZone()
    }

    func newZone() { zoneCenter = rng.double(0.22 + zoneWidth / 2, 0.78 - zoneWidth / 2) }

    /// Needle position on the bar, 0...1.
    var needle: Double { (1 - cos(phase)) / 2 }
    var inZone: Bool { abs(needle - zoneCenter) <= zoneWidth / 2 }
    var good: Int { stitches.filter { $0 }.count }

    public var score: Double {
        let g = Double(good) / Double(max(1, total))
        let done = Double(stitches.count) / Double(max(1, total))
        return clamp(0.8 * g + 0.12 * done + (done >= 1 ? 0.08 * clock.fraction : 0), 0, 1)
    }

    public var summary: String {
        "\(good) straight, \(stitches.count - good) crooked of \(total)"
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        phase += dt * speed
        cooldown = max(0, cooldown - dt)
        if let f = flash { flash = f.t - dt > 0 ? (f.ok, f.t - dt) : nil }
        if clock.tick(dt) { isOver = true }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, cooldown <= 0 else { return }
        let ok = inZone
        stitches.append(ok)
        cue(ok ? .tap : .error)
        flash = (ok, 0.3)
        cooldown = 0.18
        newZone()
        if stitches.count >= total { isOver = true }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard cooldown <= 0, abs(needle - zoneCenter) <= zoneWidth * 0.3 else { return nil }
        return canvas.center
    }

    // MARK: Render

    func seamPoint(_ t: Double, _ fab: Rect) -> Vec2 {
        Vec2(fab.x + 30 + t * (fab.w - 60), fab.midY + sin(t * .pi * 2 * wave.f + wave.p) * fab.h * wave.a)
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("sw", "Stitches \(stitches.count) of \(total)", canvas: c)
        ui.mgTimer("sw", clock.fraction, canvas: c)
        let fab = Rect(c.x + 16, c.y + 46, c.w - 32, min(150, c.h * 0.5))
        ui.shape("sw.fab", ShapeSpec(.rect, w: fab.w, h: fab.h, radius: 12, fill: Palette.tan.lighter(0.2), shadow: true), at: fab.origin)
        ui.shape("sw.fab2", ShapeSpec(.rect, w: fab.w, h: fab.h / 2, radius: 12, fill: Palette.tan.lighter(0.08)), at: Vec2(fab.x, fab.midY))
        // Guide dots.
        let guides = total * 2
        for k in 0...guides {
            let pt = seamPoint(Double(k) / Double(guides), fab)
            ui.shape("sw.gd\(k)", ShapeSpec(.circle, w: 4, h: 4, fill: Palette.ink.alpha(0.25)), at: pt - Vec2(2, 2))
        }
        for (k, ok) in stitches.enumerated() {
            let t = (Double(k) + 0.5) / Double(total)
            let pt = seamPoint(t, fab)
            let off = ok ? 0.0 : (k % 2 == 0 ? 7.0 : -7.0)
            let len = (fab.w - 60) / Double(total) * 0.7
            ui.shape("sw.s\(k)", ShapeSpec(.capsule, w: len, h: 5, fill: ok ? Palette.navy : Palette.coral), at: Vec2(pt.x - len / 2, pt.y - 2.5 + off))
        }
        if stitches.count < total {
            let pt = seamPoint((Double(stitches.count) + 0.5) / Double(total), fab)
            ui.badge("sw.needle", .needle, center: pt - Vec2(0, 20), size: 30, bg: Palette.navy, fg: Palette.paper)
        }
        // Tension bar.
        let bar = Rect(c.x + 40, min(c.maxY - 54, fab.maxY + 34), c.w - 80, 26)
        ui.shape("sw.bar", ShapeSpec(.rect, w: bar.w, h: bar.h, radius: 13, fill: Palette.blueGray), at: bar.origin)
        let zx = bar.x + (zoneCenter - zoneWidth / 2) * bar.w
        let zoneFill = flash.map { $0.ok ? Palette.statusGreen : Palette.coral } ?? Palette.turquoise
        ui.shape("sw.zone", ShapeSpec(.rect, w: zoneWidth * bar.w, h: bar.h, radius: 13, fill: zoneFill), at: Vec2(zx, bar.y))
        let nx = bar.x + needle * bar.w
        ui.shape("sw.mark", ShapeSpec(.rect, w: 6, h: bar.h + 16, radius: 3, fill: Palette.ink), at: Vec2(nx - 3, bar.y - 8))
        ui.text("sw.tip", "Tap anywhere when the needle is in the mark", Vec2(c.midX, bar.maxY + 10), size: 12, color: Palette.inkSoft, align: .center, width: c.w - 40)
        ui.mgTarget("sw.tap", Rect(c.x, c.y + 40, c.w, c.h - 40), ax: "Set a stitch")
    }
}
