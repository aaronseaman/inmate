import Foundation

/// Horseshoes on the east lawn. Aim against the wind, then pick your power.
/// A ringer is 3 points, a shoe within a hand's width is 1.
public final class HorseshoesGame: MinigameBase, Minigame {
    public let id = MinigameID.horseshoes
    public let title = "Horseshoes"
    public let icon = Icon.horseshoe
    public var controls: [(Icon, String)] {
        [(.arrowUp, "Tap to lock your aim"), (.energy, "Tap again to throw in the power band"),
         (.flag, "Wind pushes the shoe — aim into it"), (.star, "Ringer 3 points, close shoe 1")]
    }

    let throwsTotal: Int
    var thrown = 0
    var meter: ThrowMeter
    var wind: [Double] = []
    var landed: [(Vec2, Int)] = []
    var points = 0
    let ringer: Double
    let close = 0.75
    let powerTarget = 0.66
    var pause: Double = 0
    let abeMark: Int

    public init(_ cfg: MinigameConfig) {
        throwsTotal = 6 + min(2, cfg.level - 1)
        let w = cfg.difficulty.window
        ringer = 0.24 * w.squareRoot()
        meter = ThrowMeter(aimSpeed: 2.0 / w.squareRoot(), powerSpeed: 2.5 / w.squareRoot())
        abeMark = Int((Double(throwsTotal) * 1.3).rounded())
        super.init(cfg, salt: "horseshoes")
        for _ in 0..<throwsTotal { wind.append(rng.double(-1, 1) * (cfg.level >= 2 ? 1 : 0.6)) }
    }

    var currentWind: Double { thrown < throwsTotal ? wind[thrown] : 0 }
    /// The aim that cancels this throw's wind.
    var aimTarget: Double { -currentWind * 0.35 }

    public var score: Double { clamp(Double(points) / (Double(throwsTotal) * 2.2), 0, 1) }

    public var summary: String {
        "\(points) point\(points == 1 ? "" : "s") · \(points > abeMark ? "beat" : (points == abeMark ? "tied" : "short of")) Abe's \(abeMark)"
    }

    /// Landing offset from the stake in shoe widths (x lateral, y depth).
    func landing() -> Vec2 {
        Vec2((meter.aim + currentWind * 0.35) * 2.0, (powerTarget - meter.power) * 3.5)
    }

    func resolve() {
        let l = landing()
        let d = l.length
        let pts = d < ringer ? 3 : (d < close ? 1 : 0)
        points += pts
        landed.append((l, pts))
        cue(pts == 3 ? .clank : (pts == 1 ? .thud : .stepSoft))
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if pause > 0 {
            pause -= dt
            if pause <= 0 {
                thrown += 1
                meter.reset()
                if thrown >= throwsTotal { isOver = true }
            }
            return
        }
        if meter.tick(dt) { resolve() }
        if meter.stage == .flight && meter.t >= 0.8 { pause = 0.7 }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, pause <= 0, meter.stage != .flight else { return }
        cue(.tap)
        if meter.lock() { resolve() }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard pause <= 0 else { return nil }
        return meter.near(aimTarget: aimTarget, powerTarget: powerTarget, tol: 0.035) ? canvas.center : nil
    }

    // MARK: Render

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("hs", "Throw \(min(thrown + 1, throwsTotal)) of \(throwsTotal) · \(points) pts", canvas: c)
        ui.text("hs.abe", "Abe's mark: \(abeMark)", Vec2(c.maxX - 220, c.y + 18), size: 13, weight: .semibold, color: Palette.inkSoft, width: 150)
        let lawn = Rect(c.x + 70, c.y + 44, c.w - 180, c.h - 50)
        ui.shape("hs.lawn", ShapeSpec(.rect, w: lawn.w, h: lawn.h, radius: 12, fill: Palette.grass), at: lawn.origin)
        let pit = Rect(lawn.midX - 70, lawn.y + 14, 140, 100)
        ui.shape("hs.pit", ShapeSpec(.rect, w: pit.w, h: pit.h, radius: 10, fill: Palette.track.lighter(0.2)), at: pit.origin)
        let stake = Vec2(pit.midX, pit.midY)
        let unit = 20.0
        for (k, l) in landed.enumerated() {
            let pt = stake + l.0 * unit
            guard lawn.insetBy(-20).contains(pt) else { continue }
            let col = l.1 == 3 ? Palette.navy : (l.1 == 1 ? Palette.slate : Palette.slate.alpha(0.5))
            ui.icon("hs.l\(k)", .horseshoe, center: pt, size: 22, color: col, alpha: k == landed.count - 1 ? 1 : 0.6)
        }
        ui.shape("hs.stake", ShapeSpec(.circle, w: 10, h: 10, fill: Palette.ink), at: stake - Vec2(5, 5))
        // Wind flag.
        let wv = currentWind
        let wx = lawn.maxX - 70
        ui.icon("hs.flag", .flag, center: Vec2(wx, lawn.y + 30), size: 26, color: Palette.coral)
        if abs(wv) > 0.05 {
            ui.icon("hs.wind", wv > 0 ? .arrowRight : .arrowLeft, center: Vec2(wx + 34, lawn.y + 30), size: 18 + abs(wv) * 10, color: Palette.slate)
        }
        ui.text("hs.wt", abs(wv) < 0.05 ? "Calm" : (abs(wv) < 0.5 ? "Light wind" : "Strong wind"), Vec2(wx, lawn.y + 50), size: 11, color: Palette.inkSoft, align: .center, width: 90)
        let start = Vec2(lawn.midX, lawn.maxY - 40)
        if thrown < throwsTotal {
            if meter.stage == .flight || pause > 0 {
                let t = clamp(meter.t / 0.8, 0, 1)
                let end = stake + landing() * unit
                let pt = start.lerp(to: end, t) - Vec2(0, sin(t * .pi) * 40)
                ui.icon("hs.shoe", .horseshoe, center: pt, size: 24 + sin(t * .pi) * 10, color: Palette.ink)
                if t >= 1, let last = landed.last {
                    let label = last.1 == 3 ? "Ringer!" : (last.1 == 1 ? "Close — 1 point" : "Wide")
                    ui.text("hs.res", label, Vec2(lawn.midX, pit.maxY + 16), size: 20, weight: .bold, color: last.1 > 0 ? Palette.navy : Palette.coral, align: .center, width: 240)
                }
            } else {
                let aimV = meter.stage == .aim ? meter.aimNow : meter.aim
                let dir = (stake - start).normalized.rotated(aimV * 0.5)
                for k in 1...6 {
                    let pt = start + dir * Double(k) * 17
                    ui.shape("hs.ar\(k)", ShapeSpec(.circle, w: 8, h: 8, fill: meter.stage == .aim ? Palette.navy : Palette.slate.alpha(0.6)), at: pt - Vec2(4, 4))
                }
                ui.icon("hs.shoe", .horseshoe, center: start, size: 26, color: Palette.ink)
            }
        }
        let pr = Rect(c.maxX - 62, c.y + 56, 24, c.h - 100)
        ui.mgPowerBar("hs.pw", pr, value: meter.stage == .power ? meter.powerNow : meter.power, target: powerTarget, band: 0.14,
                      active: meter.stage == .power)
        let tip = meter.stage == .aim ? "Tap to aim" : (meter.stage == .power ? "Tap to throw" : "")
        ui.text("hs.tip", tip, Vec2(lawn.x + 12, lawn.maxY - 24), size: 13, weight: .semibold, color: Palette.inkSoft, width: 120)
        ui.mgTarget("hs.tap", Rect(c.x, c.y + 40, c.w, c.h - 40), ax: meter.stage == .aim ? "Lock aim" : "Throw")
    }
}
