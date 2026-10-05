import Foundation

/// Weight pile: a set of reps in rhythm. Tap as the closing ring meets the circle.
/// Three strains and you rack the bar.
public final class WeightsGame: MinigameBase, Minigame {
    public let id = MinigameID.weights
    public let title = "Weight pile"
    public let icon = Icon.dumbbell
    public var controls: [(Icon, String)] {
        [(.target, "A ring closes in on the circle"), (.hand, "Tap the moment it touches"),
         (.heart, "Off-beat or missed: a strain"), (.stop, "Three strains and you rack the bar")]
    }

    let total: Int
    let period: Double
    let hitWindow: Double
    let lead = 1.2
    var judged = 0
    var good = 0
    var strains = 0
    var feedback: (ok: Bool, t: Double)?

    public init(_ cfg: MinigameConfig) {
        total = 10 + 2 * (cfg.level - 1)
        period = 1.2 / (1 + 0.08 * Double(cfg.level - 1))
        hitWindow = 0.15 * cfg.difficulty.window
        super.init(cfg, salt: "weights")
    }

    func beatTime(_ i: Int) -> Double { lead + Double(i) * period }

    public var score: Double { clamp(Double(good) / Double(total), 0, 1) }

    public var summary: String {
        strains >= 3 ? "\(good) clean reps, then racked it" : "\(good)/\(total) clean reps"
    }

    func judge(_ ok: Bool) {
        judged += 1
        if ok { good += 1; cue(.thud) } else { strains += 1; cue(.error) }
        feedback = (ok, 0.35)
        if judged >= total || strains >= 3 { isOver = true }
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let f = feedback { feedback = f.t - dt > 0 ? (f.ok, f.t - dt) : nil }
        if judged < total && elapsed > beatTime(judged) + hitWindow { judge(false) }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, judged < total else { return }
        judge(abs(elapsed - beatTime(judged)) <= hitWindow)
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard judged < total, abs(elapsed - beatTime(judged)) < hitWindow * 0.3 else { return nil }
        return canvas.center
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("wt", "Rep \(min(judged + 1, total)) of \(total)", canvas: c)
        for k in 0..<3 {
            ui.icon("wt.h\(k)", .heart, center: Vec2(c.maxX - 120 + Double(k) * 26, c.y + 24), size: 20,
                    color: k < 3 - strains ? Palette.coral : Palette.blueGray)
        }
        let center = Vec2(c.midX, c.y + 40 + (c.h - 40) / 2)
        let r0 = min(110, (c.h - 60) / 2)
        let target = r0 * 0.42
        // The bar: plates rise on good reps.
        let lift = feedback.map { $0.ok ? sin($0.t / 0.35 * .pi) : 0 } ?? 0
        let barY = center.y + r0 * 0.15 - lift * 26
        ui.shape("wt.bar", ShapeSpec(.rect, w: r0 * 2.6, h: 8, radius: 4, fill: Palette.metal.darker(0.2)), at: Vec2(center.x - r0 * 1.3, barY - 4))
        for side in [-1.0, 1.0] {
            for k in 0..<2 {
                let px = center.x + side * (r0 * 1.05 + Double(k) * 14)
                ui.shape("wt.pl\(side > 0 ? "r" : "l")\(k)", ShapeSpec(.rect, w: 12, h: 54 - Double(k) * 12, radius: 4, fill: Palette.ink),
                         at: Vec2(px - 6, barY - (27 - Double(k) * 6)))
            }
        }
        var fill = Palette.paper
        if let f = feedback { fill = f.ok ? Palette.statusGreen.lighter(0.4) : Palette.coral.lighter(0.4) }
        ui.shape("wt.tgt", ShapeSpec(.circle, w: target * 2, h: target * 2, fill: fill, stroke: Palette.navy, lineWidth: 4), at: center - Vec2(target, target))
        ui.icon("wt.ic", .dumbbell, center: center, size: target, color: Palette.navy)
        if judged < total {
            let dtB = beatTime(judged) - elapsed
            let f = clamp(dtB / period, -0.3, 1)
            let rr = max(4, target + (r0 - target) * f)
            ui.shape("wt.ring", ShapeSpec(.ring, w: rr * 2, h: rr * 2, stroke: abs(dtB) <= hitWindow ? Palette.turquoise : Palette.ochre, lineWidth: 5),
                     at: center - Vec2(rr, rr), alpha: f < 0 ? 0.4 : 1)
        }
        ui.mgPips("wt", total: total, good: good, bad: judged - good, center: Vec2(c.midX, c.maxY - 14))
        ui.mgTarget("wt.tap", Rect(c.x, c.y + 40, c.w, c.h - 40), ax: "Lift")
    }
}
