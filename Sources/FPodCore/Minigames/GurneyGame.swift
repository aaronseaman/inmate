import Foundation

/// The infirmary ramp: steer a supply gurney down three lanes. Tap above the gurney
/// to move up a lane, below to move down. Bumps are just bumps — and they count.
public final class GurneyGame: MinigameBase, Minigame {
    public let id = MinigameID.gurney
    public let title = "Ramp run"
    public let icon = Icon.gurney
    public var controls: [(Icon, String)] {
        [(.arrowUp, "Tap above the gurney: up a lane"), (.arrowDown, "Tap below it: down a lane"),
         (.cone, "Dodge cones, carts and wet floor"), (.person, "People step aside if you're early")]
    }

    struct Obstacle { var x: Double; let lane: Int; let kind: Icon; var hit = false }

    var lane = 1
    var laneY: Double = 1
    var obstacles: [Obstacle] = []
    var distance: Double = 0
    let length: Double
    var speed: Double
    let baseSpeed: Double
    var spawnTimer: Double = 0.6
    var bumps = 0
    var bumpFlash: Double = 0
    static let gurneyX = 0.16

    public init(_ cfg: MinigameConfig) {
        baseSpeed = 0.42 * (1 + 0.1 * Double(cfg.level - 1)) / cfg.difficulty.window.squareRoot()
        speed = baseSpeed
        length = 9 + Double(cfg.level)
        super.init(cfg, salt: "gurney")
    }

    public var score: Double {
        let progress = min(1, distance / length)
        return clamp(progress * (1 - 0.17 * Double(bumps)), 0, 1)
    }

    public var summary: String { distance >= length ? "Made it down · \(bumps) bump\(bumps == 1 ? "" : "s")" : "Stopped partway" }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        bumpFlash = max(0, bumpFlash - dt)
        laneY += (Double(lane) - laneY) * min(1, dt * 12)
        speed = min(baseSpeed * 1.8, speed + dt * 0.01)
        let v = bumpFlash > 0 ? speed * 0.4 : speed
        distance += v * dt
        for i in obstacles.indices { obstacles[i].x -= v * dt }
        obstacles.removeAll { $0.x < -0.1 }
        spawnTimer -= dt
        if spawnTimer <= 0 && distance < length - 1 {
            spawnTimer = rng.double(0.7, 1.15) * cfg.difficulty.window.squareRoot()
            // Half the obstacles come at your current lane; you always have somewhere to go.
            let l = rng.chance(0.5) ? lane : rng.int(0, 2)
            obstacles.append(Obstacle(x: 1.08, lane: l, kind: rng.pick([.cone, .cart, .water, .person]) ?? .cone))
        }
        for i in obstacles.indices where !obstacles[i].hit && obstacles[i].lane == lane && abs(obstacles[i].x - GurneyGame.gurneyX) < 0.05 {
            obstacles[i].hit = true
            bumps += 1
            bumpFlash = 0.6
            cue(.thud)
        }
        if distance >= length { isOver = true; cue(.success) }
    }

    func trackRect(_ c: Rect) -> Rect { Rect(c.x + 10, c.y + 50, c.w - 20, c.h - 60) }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        let t = trackRect(canvas)
        let gy = t.y + (laneY + 0.5) * t.h / 3
        if p.y < gy - 6 && lane > 0 { lane -= 1; cue(.tap) } else if p.y > gy + 6 && lane < 2 { lane += 1; cue(.tap) }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        func danger(_ l: Int) -> Double {
            obstacles.filter { !$0.hit && $0.lane == l && $0.x > GurneyGame.gurneyX - 0.02 }.map { $0.x - GurneyGame.gurneyX }.min() ?? 9
        }
        guard danger(lane) < 0.3, abs(laneY - Double(lane)) < 0.1 else { return nil }
        let options = [lane - 1, lane + 1].filter { (0...2).contains($0) }
        guard let best = options.max(by: { danger($0) < danger($1) }), danger(best) > danger(lane) else { return nil }
        let t = trackRect(canvas)
        return Vec2(t.x + 40, t.y + (Double(best) + 0.5) * t.h / 3)
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("gy", "Bumps: \(bumps)", canvas: c)
        let t = trackRect(c)
        let barW = 150.0
        ui.shape("gy.pbg", ShapeSpec(.rect, w: barW, h: 10, radius: 5, fill: Palette.blueGray), at: Vec2(c.maxX - barW - 64, c.y + 21))
        ui.shape("gy.p", ShapeSpec(.rect, w: max(10, barW * min(1, distance / length)), h: 10, radius: 5, fill: Palette.turquoise), at: Vec2(c.maxX - barW - 64, c.y + 21))
        ui.icon("gy.flag", .flag, center: Vec2(c.maxX - 52, c.y + 26), size: 16, color: Palette.slate)
        ui.shape("gy.ramp", ShapeSpec(.rect, w: t.w, h: t.h, radius: 12, fill: Palette.metal.lighter(0.35)), at: t.origin)
        let lh = t.h / 3
        let stripe = 40.0
        let off = (distance * t.w).truncatingRemainder(dividingBy: stripe)
        for l in 1..<3 {
            var x = t.x - off, k = 0
            while x < t.maxX - 10 {
                ui.shape("gy.ln\(l).\(k)", ShapeSpec(.rect, w: 18, h: 3, radius: 1.5, fill: Palette.ochre.alpha(0.6)), at: Vec2(max(t.x, x), t.y + lh * Double(l) - 1.5))
                x += stripe; k += 1
            }
        }
        for (i, o) in obstacles.enumerated() where o.x < 1.1 {
            let center = Vec2(t.x + o.x * t.w, t.y + (Double(o.lane) + 0.5) * lh)
            ui.badge("gy.o\(i)", o.kind, center: center, size: min(40, lh * 0.7), bg: o.hit ? Palette.blueGray : (o.kind == .person ? Palette.tan : Palette.ochre), fg: Palette.ink)
        }
        let gc = Vec2(t.x + GurneyGame.gurneyX * t.w, t.y + (laneY + 0.5) * lh)
        ui.shape("gy.g", ShapeSpec(.rect, w: 64, h: min(34, lh * 0.6), radius: 8, fill: bumpFlash > 0 ? Palette.coral.lighter(0.3) : Palette.paper,
                                   stroke: Palette.navy, lineWidth: 2.5, shadow: true), at: gc - Vec2(32, min(34, lh * 0.6) / 2))
        ui.icon("gy.gi", .box, center: gc, size: 20, color: Palette.navy)
        ui.mgTarget("gy.up", Rect(c.x, c.y + 40, c.w, gc.y - c.y - 46), ax: "Move up a lane")
        ui.mgTarget("gy.down", Rect(c.x, gc.y + 6, c.w, c.maxY - gc.y - 6), ax: "Move down a lane")
    }
}
