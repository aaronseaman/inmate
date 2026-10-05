import Foundation

/// Shared state for minigames: seeded randomness, a run clock, sound cues.
public class MinigameBase {
    let cfg: MinigameConfig
    var rng: RNG
    var cues: [SFX] = []
    /// Seconds since the game started playing.
    var elapsed: Double = 0
    public internal(set) var isOver = false

    init(_ cfg: MinigameConfig, salt: String) {
        self.cfg = cfg
        rng = RNG(seed: cfg.seed ^ stableHash(salt))
    }

    /// Difficulty window (bigger = more forgiving), shrinking a little per level.
    var window: Double { cfg.difficulty.window * (1 - 0.06 * Double(max(0, cfg.level - 1))) }

    func cue(_ s: SFX) { if cues.count < 6 { cues.append(s) } }
    public func drainCues() -> [SFX] { defer { cues = [] }; return cues }
}

/// A countdown that ends the game when it runs out.
struct RunClock {
    let total: Double
    var left: Double
    init(_ total: Double) { self.total = total; left = total }
    var fraction: Double { total > 0 ? max(0, left / total) : 0 }
    /// Returns true when time ran out on this tick.
    mutating func tick(_ dt: Double) -> Bool {
        guard left > 0 else { return false }
        left = max(0, left - dt)
        return left == 0
    }
}

extension UIBuilder {
    /// Header line (left) used by every minigame.
    mutating func mgHeader(_ id: String, _ s: String, canvas: Rect) {
        text(id + ".hdr", s, Vec2(canvas.x + 20, canvas.y + 14), size: 15, weight: .semibold, width: canvas.w * 0.55)
    }

    /// Timer bar (top right). Coral when nearly out.
    mutating func mgTimer(_ id: String, _ frac: Double, canvas: Rect) {
        let barW = 150.0
        let x = canvas.maxX - barW - 64
        shape(id + ".tbg", ShapeSpec(.rect, w: barW, h: 10, radius: 5, fill: Palette.blueGray), at: Vec2(x, canvas.y + 21))
        shape(id + ".t", ShapeSpec(.rect, w: max(10, barW * clamp(frac, 0, 1)), h: 10, radius: 5, fill: frac < 0.25 ? Palette.coral : Palette.turquoise),
              at: Vec2(x, canvas.y + 21))
        icon(id + ".tic", .clock, center: Vec2(x - 14, canvas.y + 26), size: 16, color: Palette.slate)
    }

    /// Row of progress pips: filled = done, coral = missed.
    mutating func mgPips(_ id: String, total: Int, good: Int, bad: Int, center: Vec2) {
        let gap = 13.0
        let n = min(total, 30)
        let x0 = center.x - Double(n - 1) * gap / 2
        for i in 0..<n {
            let fill: RGBA = i < good ? Palette.turquoise : (i < good + bad ? Palette.coral : Palette.blueGray)
            shape("\(id).pip\(i)", ShapeSpec(.circle, w: 8, h: 8, fill: fill), at: Vec2(x0 + Double(i) * gap - 4, center.y - 4))
        }
    }

    /// A tappable minigame button: drawn like any button, routed to `Minigame.tap`.
    mutating func mgButton(_ id: String, _ r: Rect, icon: Icon? = nil, label: String? = nil, style: ButtonStyle = .tile, ax: String,
                           enabled: Bool = true, iconColor: RGBA? = nil) {
        button(id, r, icon: icon, label: label, style: style, action: .minigameButton(-1), ax: ax, enabled: enabled, iconColor: iconColor)
    }

    /// Accessibility-only element (a tappable target without its own drawing).
    mutating func mgTarget(_ id: String, _ r: Rect, ax: String) {
        hit(r, .minigameButton(-1), label: ax, id: id)
    }
}

extension Game {
    func playMinigameCues(_ mg: MinigameSession) {
        for c in mg.game.drainCues() {
            sound(c, volume: 0.8)
            switch c {
            case .error, .fail: haptic(.warning)
            case .success: haptic(.success)
            case .thud, .clank: haptic(.medium)
            default: break
            }
        }
        if mg.phase == .result && !mg.resultCuePlayed {
            mg.resultCuePlayed = true
            if !mg.quit { sound(mg.passed && mg.finalScore >= 0.3 ? .success : .fail) }
        }
    }
}

/// Two-stage aim-then-power meter shared by the throwing games. Each stage locks on a
/// tap, or by itself after a few seconds (so an idle player still throws — badly).
struct ThrowMeter {
    enum Stage { case aim, power, flight }
    var stage: Stage = .aim
    var t: Double = 0
    var aim: Double = 0
    var power: Double = 0
    let aimSpeed: Double
    let powerSpeed: Double
    let stageTimeout: Double

    init(aimSpeed: Double, powerSpeed: Double, stageTimeout: Double = 5) {
        self.aimSpeed = aimSpeed; self.powerSpeed = powerSpeed; self.stageTimeout = stageTimeout
    }

    /// -1...1, sweeping side to side.
    var aimNow: Double { sin(t * aimSpeed) }
    /// 0...1, filling and draining.
    var powerNow: Double { (1 - cos(t * powerSpeed)) / 2 }

    /// Returns true when the throw is released (both stages locked).
    @discardableResult
    mutating func lock() -> Bool {
        switch stage {
        case .aim: aim = aimNow; stage = .power; t = 0; return false
        case .power: power = powerNow; stage = .flight; t = 0; return true
        case .flight: return false
        }
    }

    /// Advances; returns true if a stage timed out and locked itself this tick.
    mutating func tick(_ dt: Double) -> Bool {
        t += dt
        if stage != .flight && t >= stageTimeout {
            if stage == .aim { aim = aimNow } else { power = powerNow }
            let released = stage == .power
            stage = stage == .aim ? .power : .flight
            t = 0
            return released
        }
        return false
    }

    mutating func reset() { stage = .aim; t = 0 }

    /// Would a tap now land within `tol` of `target` for the current stage?
    func near(aimTarget: Double, powerTarget: Double, tol: Double) -> Bool {
        switch stage {
        case .aim: return abs(aimNow - aimTarget) < tol
        case .power: return abs(powerNow - powerTarget) < tol
        case .flight: return false
        }
    }
}

extension UIBuilder {
    /// Vertical power meter with a target band.
    mutating func mgPowerBar(_ id: String, _ r: Rect, value: Double, target: Double, band: Double, active: Bool) {
        shape(id + ".bg", ShapeSpec(.rect, w: r.w, h: r.h, radius: r.w / 2, fill: Palette.blueGray), at: r.origin)
        let by = r.maxY - (target + band / 2) * r.h
        shape(id + ".band", ShapeSpec(.rect, w: r.w, h: band * r.h, radius: 4, fill: Palette.turquoise.alpha(0.75)), at: Vec2(r.x, by))
        let fh = max(r.w, value * r.h)
        shape(id + ".fill", ShapeSpec(.rect, w: r.w - 8, h: fh - 8, radius: (r.w - 8) / 2, fill: active ? Palette.ochre : Palette.slate),
              at: Vec2(r.x + 4, r.maxY - fh + 4))
        icon(id + ".ic", .energy, center: Vec2(r.midX, r.maxY + 14), size: 16, color: Palette.slate)
    }
}
