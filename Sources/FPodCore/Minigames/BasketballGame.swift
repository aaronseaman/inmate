import Foundation

/// Yard basketball: a shooting round. Tap to lock your aim as the arrow sweeps,
/// tap again to release when the power fills to the band.
public final class BasketballGame: MinigameBase, Minigame {
    public let id = MinigameID.basketball
    public let title = "Shooting round"
    public let icon = Icon.ball
    public var controls: [(Icon, String)] {
        [(.arrowUp, "Tap to lock your aim while the arrow sweeps"), (.energy, "Tap again to release in the power band"),
         (.target, "Farther spots need more power"), (.star, "Clean swishes count extra")]
    }

    enum Result { case swish, make, rim, short, long }

    let shots: Int
    var shot = 0
    var meter: ThrowMeter
    var spots: [(x: Double, d: Double)] = []
    var results: [Result] = []
    var points = 0.0
    var pause: Double = 0
    let tolA: Double
    let tolP: Double

    public init(_ cfg: MinigameConfig) {
        shots = 6 + min(2, cfg.level - 1)
        let w = cfg.difficulty.window
        tolA = 0.15 * w
        tolP = 0.085 * w
        meter = ThrowMeter(aimSpeed: 2.4 / w.squareRoot(), powerSpeed: 2.8 / w.squareRoot())
        super.init(cfg, salt: "basketball")
        for _ in 0..<shots { spots.append((rng.double(-0.8, 0.8), rng.double(0.05, cfg.level >= 2 ? 1 : 0.7))) }
    }

    var powerTarget: Double { 0.42 + 0.36 * (shot < shots ? spots[shot].d : 0) }

    public var score: Double { clamp(points / Double(shots), 0, 1) }

    public var summary: String {
        let made = results.filter { $0 == .swish || $0 == .make }.count
        let sw = results.filter { $0 == .swish }.count
        return "\(made)/\(shots) made\(sw > 0 ? " · \(sw) swish\(sw == 1 ? "" : "es")" : "")"
    }

    func resolve() {
        let ea = abs(meter.aim) / tolA
        let ep = abs(meter.power - powerTarget) / tolP
        let r: Result
        if ea <= 0.5 && ep <= 0.5 { r = .swish; points += 1; cue(.swish) }
        else if ea <= 1 && ep <= 1 { r = .make; points += 0.85; cue(.swish) }
        else if ea <= 1.6 && ep <= 1.6 { r = .rim; cue(.clank) }
        else if meter.power < powerTarget { r = .short; cue(.thud) }
        else { r = .long; cue(.thud) }
        results.append(r)
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if pause > 0 {
            pause -= dt
            if pause <= 0 {
                shot += 1
                meter.reset()
                if shot >= shots { isOver = true }
            }
            return
        }
        if meter.tick(dt) { resolve() }
        if meter.stage == .flight && meter.t >= 0.85 { pause = 0.6 }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, pause <= 0, meter.stage != .flight else { return }
        cue(.tap)
        if meter.lock() { resolve() }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        meter.near(aimTarget: 0, powerTarget: powerTarget, tol: meter.stage == .aim ? tolA * 0.35 : tolP * 0.35) && pause <= 0 ? canvas.center : nil
    }

    // MARK: Render

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("bb", "Shot \(min(shot + 1, shots)) of \(shots)", canvas: c)
        let good = results.filter { $0 == .swish || $0 == .make }.count
        ui.mgPips("bb", total: shots, good: good, bad: results.count - good, center: Vec2(c.maxX - 150, c.y + 26))
        let court = Rect(c.x + 70, c.y + 44, c.w - 180, c.h - 50)
        ui.shape("bb.court", ShapeSpec(.rect, w: court.w, h: court.h, radius: 12, fill: Palette.track.lighter(0.35)), at: court.origin)
        let hoop = Vec2(court.midX, court.y + 34)
        let keyW = min(170, court.w * 0.34)
        ui.shape("bb.key", ShapeSpec(.rect, w: keyW, h: court.h * 0.55, fill: Palette.coral.alpha(0.22), stroke: Palette.paper, lineWidth: 3), at: Vec2(hoop.x - keyW / 2, court.y))
        ui.shape("bb.ft", ShapeSpec(.ring, w: keyW, h: keyW * 0.5, stroke: Palette.paper, lineWidth: 3), at: Vec2(hoop.x - keyW / 2, court.y + court.h * 0.55 - keyW * 0.25))
        ui.shape("bb.board", ShapeSpec(.rect, w: 86, h: 10, radius: 3, fill: Palette.paper, stroke: Palette.slate, lineWidth: 2), at: Vec2(hoop.x - 43, court.y + 8))
        ui.shape("bb.rim", ShapeSpec(.ring, w: 40, h: 20, stroke: Palette.coral, lineWidth: 4), at: Vec2(hoop.x - 20, hoop.y - 10))
        guard shot < shots else { return }
        let spot = spots[shot]
        let start = Vec2(court.midX + spot.x * court.w * 0.38, court.y + court.h * (0.5 + 0.42 * spot.d))
        if meter.stage == .flight || pause > 0 {
            let r = results.last ?? .make
            let t = clamp(meter.t / 0.85, 0, 1)
            var end = hoop + Vec2(meter.aim * 150, (powerTarget - meter.power) * 260)
            if r == .swish || r == .make { end = hoop }
            let pt = start.lerp(to: end, t) - Vec2(0, sin(t * .pi) * 70)
            let sz = 26 + sin(t * .pi) * 12
            ui.badge("bb.ball", .ball, center: pt, size: sz, bg: Palette.ochre, fg: Palette.ink)
            if t >= 1 {
                let label: String
                switch r {
                case .swish: label = "Swish!"
                case .make: label = "Good!"
                case .rim: label = "Off the rim"
                case .short: label = "Short"
                case .long: label = "Long"
                }
                ui.text("bb.res", label, Vec2(court.midX, court.y + court.h * 0.36), size: 22, weight: .bold,
                        color: r == .swish || r == .make ? Palette.navy : Palette.coral, align: .center, width: 240)
            }
        } else {
            // Aim arrow: dots toward the hoop, swung by the aim value.
            let aimV = meter.stage == .aim ? meter.aimNow : meter.aim
            let dir = (hoop - start).normalized.rotated(aimV * 0.6)
            for k in 1...6 {
                let pt = start + dir * Double(k) * 18
                ui.shape("bb.ar\(k)", ShapeSpec(.circle, w: 8, h: 8, fill: meter.stage == .aim ? Palette.navy : Palette.slate.alpha(0.6)), at: pt - Vec2(4, 4))
            }
            ui.badge("bb.ball", .ball, center: start, size: 28, bg: Palette.ochre, fg: Palette.ink)
            ui.icon("bb.me", .person, center: start + Vec2(0, 30), size: 26, color: Palette.tan.darker(0.3))
        }
        let pr = Rect(c.maxX - 62, c.y + 56, 24, c.h - 100)
        ui.mgPowerBar("bb.pw", pr, value: meter.stage == .power ? meter.powerNow : meter.power, target: powerTarget, band: tolP * 2,
                      active: meter.stage == .power)
        let tip = meter.stage == .aim ? "Tap to aim" : (meter.stage == .power ? "Tap to shoot" : "")
        ui.text("bb.tip", tip, Vec2(court.x + 12, court.maxY - 24), size: 13, weight: .semibold, color: Palette.inkSoft, width: 120)
        ui.mgTarget("bb.tap", Rect(c.x, c.y + 40, c.w, c.h - 40), ax: meter.stage == .aim ? "Lock aim" : "Release shot")
    }
}
