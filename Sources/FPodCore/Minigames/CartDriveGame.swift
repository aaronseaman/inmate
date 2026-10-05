import Foundation

/// Cart derby (and any supervised driving): tap where you want the cart to go; it
/// turns toward that point at cart speed. Pass the gates in order; stay on the track.
public final class CartDriveGame: MinigameBase, Minigame {
    public let id: MinigameID
    public let title: String
    public let icon: Icon
    let van: Bool
    public var controls: [(Icon, String)] {
        [(.hand, "Tap where you want the cart to head"), (.flag, "Pass the numbered gates in order"),
         (.cone, "Off the track you slow down"), (.clock, van ? "Mr. Feld rides along; he'd like to arrive" : "Abe's record is forty seconds")]
    }

    // World units: track centered at (50, 30), ellipse radii 38 × 20, half-width 7.
    static let center = Vec2(50, 30)
    static let ra = 38.0, rb = 20.0, halfWidth = 7.0
    var pos: Vec2
    var heading: Double
    var target: Vec2
    var gate = 0
    /// Counter-clockwise from the top: left, bottom, right, then back to the start line.
    let gateAngles: [Double] = [.pi, .pi / 2, 0, -.pi / 2]
    let laps: Int
    var lap = 0
    var offTrack: Double = 0
    var bumps = 0
    var clock: RunClock
    let par = 40.0
    let turnRate: Double
    var wasOff = false

    public init(_ cfg: MinigameConfig, van: Bool = false) {
        self.van = van
        id = van ? .vanDrive : .cartDrive
        title = van ? "Supply run (supervised)" : "Cart derby"
        icon = van ? .van : .cart
        laps = cfg.level >= 3 ? 2 : 1
        clock = RunClock(70 * Double(laps) * cfg.difficulty.window)
        turnRate = 2.6 * cfg.difficulty.window.squareRoot()
        pos = CartDriveGame.point(-.pi / 2)
        heading = .pi
        target = CartDriveGame.point(-.pi / 2 - 0.6)
        super.init(cfg, salt: "cart")
        target = gatePoint(0)
    }

    static func point(_ a: Double) -> Vec2 { center + Vec2(cos(a) * ra, sin(a) * rb) }
    func gatePoint(_ g: Int) -> Vec2 { CartDriveGame.point(gateAngles[g % gateAngles.count]) }

    /// Normalized radial distance from the track center line, in world units (approx.).
    func offCenter(_ p: Vec2) -> Double {
        let d = p - CartDriveGame.center
        let r = (d.x * d.x / (CartDriveGame.ra * CartDriveGame.ra) + d.y * d.y / (CartDriveGame.rb * CartDriveGame.rb)).squareRoot()
        return abs(r - 1) * min(CartDriveGame.ra, CartDriveGame.rb)
    }

    var totalGates: Int { gateAngles.count * laps }
    var gatesPassed: Int { lap * gateAngles.count + gate }

    public var score: Double {
        let done = Double(gatesPassed) / Double(totalGates)
        guard done >= 1 else { return 0.55 * done }
        let used = clock.total - clock.left
        let timeScore = clamp(1 - (used - par * Double(laps) * cfg.difficulty.window) / (par * Double(laps)), 0, 1)
        return clamp(0.6 + 0.4 * timeScore - 0.03 * Double(bumps), 0, 1)
    }

    public var summary: String {
        let used = Int((clock.total - clock.left).rounded())
        return gatesPassed >= totalGates ? "Lap in \(used)s · \(bumps) cone\(bumps == 1 ? "" : "s")" : "\(gatesPassed) of \(totalGates) gates"
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        let want = (target - pos).angle
        var diff = want - heading
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        heading += clamp(diff, -turnRate * dt, turnRate * dt)
        let off = offCenter(pos) > CartDriveGame.halfWidth
        if off && !wasOff { bumps += 1; cue(.thud) }
        wasOff = off
        let speed = off ? 7.0 : 17.0
        let step = Vec2.fromAngle(heading, speed * dt)
        let next = pos + step
        // The outer wall: you can't leave the bay.
        if offCenter(next) < CartDriveGame.halfWidth * 2.2 { pos = next } else { heading += .pi * 0.5 * dt }
        if pos.distance(to: gatePoint(gate)) < CartDriveGame.halfWidth * 1.1 {
            gate += 1
            cue(.coin)
            if gate >= gateAngles.count { gate = 0; lap += 1 }
            if gatesPassed >= totalGates { isOver = true; return }
        }
        if clock.tick(dt) { isOver = true }
    }

    func toScreen(_ w: Vec2, _ c: Rect) -> Vec2 {
        let area = Rect(c.x + 10, c.y + 44, c.w - 20, c.h - 50)
        let s = min(area.w / 100, area.h / 60)
        let o = Vec2(area.midX - 50 * s, area.midY - 30 * s)
        return o + w * s
    }
    func toWorld(_ p: Vec2, _ c: Rect) -> Vec2 {
        let area = Rect(c.x + 10, c.y + 44, c.w - 20, c.h - 50)
        let s = min(area.w / 100, area.h / 60)
        let o = Vec2(area.midX - 50 * s, area.midY - 30 * s)
        return (p - o) / s
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        target = toWorld(p, canvas)
        cue(.tap)
    }

    public func botTap(canvas: Rect) -> Vec2? {
        // Aim a little past the next gate along the direction of travel (decreasing angle).
        let a = gateAngles[gate] - 0.3
        let aim = CartDriveGame.point(a)
        guard aim.distance(to: target) > 2 else { return nil }
        return toScreen(aim, canvas)
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("cd", "Gate \(min(gatesPassed + 1, totalGates)) of \(totalGates)", canvas: c)
        ui.mgTimer("cd", clock.fraction, canvas: c)
        let s = toScreen(Vec2(1, 0), c).x - toScreen(Vec2(0, 0), c).x
        let ctr = toScreen(CartDriveGame.center, c)
        let ow = (CartDriveGame.ra + CartDriveGame.halfWidth) * 2 * s, oh = (CartDriveGame.rb + CartDriveGame.halfWidth) * 2 * s
        let iw = (CartDriveGame.ra - CartDriveGame.halfWidth) * 2 * s, ih = (CartDriveGame.rb - CartDriveGame.halfWidth) * 2 * s
        ui.shape("cd.out", ShapeSpec(.circle, w: ow, h: oh, fill: Palette.concrete), at: ctr - Vec2(ow / 2, oh / 2))
        ui.shape("cd.in", ShapeSpec(.circle, w: iw, h: ih, fill: Palette.paper), at: ctr - Vec2(iw / 2, ih / 2))
        ui.shape("cd.line", ShapeSpec(.ring, w: CartDriveGame.ra * 2 * s, h: CartDriveGame.rb * 2 * s, stroke: Palette.paper.alpha(0.8), lineWidth: 2),
                 at: ctr - Vec2(CartDriveGame.ra * s, CartDriveGame.rb * s))
        for g in 0..<gateAngles.count {
            let gp = toScreen(gatePoint(g), c)
            let next = g == gate
            ui.badge("cd.g\(g)", .flag, center: gp, size: next ? 30 : 22, bg: next ? Palette.coral : Palette.blueGray, fg: Palette.paper)
            ui.text("cd.gn\(g)", "\(g + 1)", Vec2(gp.x, gp.y + 14), size: 11, weight: .bold, color: Palette.ink, align: .center, width: 20)
        }
        let tp = toScreen(target, c)
        ui.shape("cd.target", ShapeSpec(.ring, w: 18, h: 18, stroke: Palette.navy.alpha(0.5), lineWidth: 2), at: tp - Vec2(9, 9))
        let cp = toScreen(pos, c)
        ui.art("cd.cart", .named("vehicle", Vehicle.allCases.firstIndex(of: .janitorCart) ?? 0, 0), at: cp, scale: max(0.8, s * 3 / 30), rotation: heading)
        ui.mgTarget("cd.tap", Rect(c.x, c.y + 40, c.w, c.h - 40), ax: "Steer toward this point")
    }
}
