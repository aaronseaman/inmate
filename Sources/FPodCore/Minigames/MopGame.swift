import Foundation

/// Janitorial: plan one connected mopping route. Tap a tile next to the mop to move;
/// every new tile gets cleaned. Re-crossing wet floor leaves prints. End at the door.
public final class MopGame: Minigame {
    public let id = MinigameID.mop
    public let title = "Mop the dayroom"
    public let icon = Icon.mop
    public var controls: [(Icon, String)] {
        [(.hand, "Tap a tile beside the mop to move it"), (.arrowRight, "Tap further along a row to glide"),
         (.water, "Don't cross your own wet tiles"), (.door, "Finish at the door (tap it again to end)")]
    }

    enum Cell: Equatable { case blocked, floor, dirty }
    let cols: Int
    let rows: Int
    var cells: [Cell]
    var wet: [Bool]
    var prints: [Bool]
    var pos: Int
    let exit: Int
    var timeLeft: Double
    let timeTotal: Double
    var moves = 0
    var reWet = 0
    let dirtyTotal: Int
    public private(set) var isOver = false
    /// A known no-revisit route (used by assist mode and tests).
    public private(set) var solution: [Int] = []
    var reachedExit = false
    var flash: Double = 0

    public init(_ cfg: MinigameConfig) {
        var rng = RNG(seed: cfg.seed)
        let cols = 7 + min(2, cfg.level - 1)
        let rows = 5
        self.cols = cols
        self.rows = rows
        let n = cols * rows
        var cells = [Cell](repeating: .blocked, count: n)
        // A self-avoiding random walk guarantees a solvable, no-revisit route.
        var walk: [Int] = [0]
        var visited = Set([0])
        let targetLen = Int(Double(n) * 0.72)
        func neighbors(_ i: Int) -> [Int] {
            var out: [Int] = []
            let x = i % cols, y = i / cols
            if x > 0 { out.append(i - 1) }
            if x < cols - 1 { out.append(i + 1) }
            if y > 0 { out.append(i - cols) }
            if y < rows - 1 { out.append(i + cols) }
            return out
        }
        var attempts = 0
        while walk.count < targetLen && attempts < 400 {
            attempts += 1
            walk = [0]; visited = [0]
            while walk.count < targetLen {
                let opts = neighbors(walk.last!).filter { !visited.contains($0) }
                // Prefer moves that keep options open (Warnsdorff-like).
                guard !opts.isEmpty else { break }
                var scored = opts.map { o -> (Int, Int) in (o, neighbors(o).filter { !visited.contains($0) }.count) }
                rng.shuffle(&scored)
                scored.sort { $0.1 < $1.1 }
                let pick = rng.chance(0.75) ? scored[0].0 : scored[rng.int(0, scored.count - 1)].0
                walk.append(pick)
                visited.insert(pick)
            }
        }
        for (k, i) in walk.enumerated() { cells[i] = (k == 0 || rng.chance(0.18)) ? .floor : .dirty }
        let route = walk
        // Some non-route tiles are plain floor (open space), the rest benches/signs.
        for i in 0..<n where cells[i] == .blocked && rng.chance(0.35) { cells[i] = .floor }
        self.cells = cells
        wet = [Bool](repeating: false, count: n)
        prints = [Bool](repeating: false, count: n)
        pos = 0
        exit = walk.last ?? n - 1
        if cells[exit] == .dirty { } else { self.cells[exit] = .dirty }
        dirtyTotal = self.cells.filter { $0 == .dirty }.count
        timeTotal = (36 + Double(dirtyTotal) * 1.1) * cfg.difficulty.window
        timeLeft = timeTotal
        wet[0] = true
        solution = route
    }

    var dirtyLeft: Int { cells.filter { $0 == .dirty }.count }

    public var score: Double {
        let cleaned = Double(dirtyTotal - dirtyLeft) / Double(max(1, dirtyTotal))
        let neat = max(0, 1 - Double(reWet) / 6)
        let time = timeLeft / timeTotal
        var sc = 0.65 * cleaned + 0.2 * neat + 0.15 * time
        if !reachedExit { sc *= 0.8 }
        return clamp(sc, 0, 1)
    }

    public var summary: String {
        let cleaned = dirtyTotal - dirtyLeft
        return "Cleaned \(cleaned)/\(dirtyTotal) · \(reWet == 0 ? "no prints" : "\(reWet) print\(reWet == 1 ? "" : "s")")\(reachedExit ? "" : " · didn't reach the door")"
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        timeLeft -= dt
        flash = max(0, flash - dt)
        if timeLeft <= 0 { timeLeft = 0; isOver = true }
    }

    func step(to i: Int) {
        guard cells[i] != .blocked else { return }
        if wet[i] {
            reWet += 1
            prints[i] = true
            flash = 0.3
        }
        if cells[i] == .dirty { cells[i] = .floor }
        wet[i] = true
        pos = i
        moves += 1
        if i == exit && dirtyLeft == 0 { reachedExit = true; isOver = true }
        if i == exit && dirtyLeft > 0 { reachedExit = true }
    }

    func layout(_ canvas: Rect) -> (origin: Vec2, size: Double) {
        let size = min((canvas.w - 40) / Double(cols), (canvas.h - 90) / Double(rows))
        let w = size * Double(cols), h = size * Double(rows)
        return (Vec2(canvas.midX - w / 2, canvas.y + 64 + (canvas.h - 90 - h) / 2), size)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        let (o, size) = layout(canvas)
        let cx = Int(floor((p.x - o.x) / size)), cy = Int(floor((p.y - o.y) / size))
        guard cx >= 0, cy >= 0, cx < cols, cy < rows else { return }
        let px = pos % cols, py = pos / cols
        if cx == px && cy == py {
            // Tapping the door again ends the shift early.
            if pos == exit { isOver = true }
            return
        }
        // Straight-line glide along a row or column.
        if cx == px || cy == py {
            let dx = (cx - px).signum(), dy = (cy - py).signum()
            var x = px, y = py
            while x != cx || y != cy {
                let nx = x + dx, ny = y + dy
                let ni = ny * cols + nx
                if cells[ni] == .blocked { break }
                step(to: ni)
                x = nx; y = ny
                if isOver { break }
            }
        }
        if pos == rows * cols - 1 && dirtyLeft == 0 { isOver = true }
        if reachedExit && pos == exit && dirtyLeft == 0 { isOver = true }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard let k = solution.firstIndex(of: pos), k + 1 < solution.count else { return nil }
        let (o, size) = layout(canvas)
        let n = solution[k + 1]
        return o + Vec2((Double(n % cols) + 0.5) * size, (Double(n / cols) + 0.5) * size)
    }

    /// Finish early by stepping onto the door with dirt left.
    public func finishAtDoor() { if pos == exit { isOver = true } }

    public func render(_ ui: inout UIBuilder, canvas: Rect, time: Double) {
        let (o, size) = layout(canvas)
        ui.text("mop.title", "Dirty tiles left: \(dirtyLeft)", Vec2(canvas.x + 20, canvas.y + 18), size: 15, weight: .semibold)
        let frac = timeLeft / timeTotal
        let barW = 160.0
        ui.shape("mop.timebg", ShapeSpec(.rect, w: barW, h: 10, radius: 5, fill: Palette.blueGray), at: Vec2(canvas.maxX - barW - 20, canvas.y + 24))
        ui.shape("mop.time", ShapeSpec(.rect, w: max(10, barW * frac), h: 10, radius: 5, fill: frac < 0.25 ? Palette.coral : Palette.turquoise),
                 at: Vec2(canvas.maxX - barW - 20, canvas.y + 24))
        ui.icon("mop.clock", .clock, center: Vec2(canvas.maxX - barW - 34, canvas.y + 29), size: 16, color: Palette.slate)
        let px = pos % cols, py = pos / cols
        for i in 0..<(cols * rows) {
            let x = i % cols, y = i / cols
            let r = Rect(o.x + Double(x) * size + 2, o.y + Double(y) * size + 2, size - 4, size - 4)
            switch cells[i] {
            case .blocked:
                ui.shape("mop.c\(i)", ShapeSpec(.rect, w: r.w, h: r.h, radius: 6, fill: Palette.wallTop, shadow: true), at: r.origin)
                ui.icon("mop.b\(i)", (i % 3 == 0) ? .exclaim : .chair, center: r.center, size: size * 0.4, color: Palette.ochre)
            case .floor, .dirty:
                let fill = wet[i] ? Palette.turquoise.lighter(0.55) : Palette.floor
                ui.shape("mop.c\(i)", ShapeSpec(.rect, w: r.w, h: r.h, radius: 6, fill: fill), at: r.origin)
                if cells[i] == .dirty {
                    ui.shape("mop.d\(i)a", ShapeSpec(.circle, w: size * 0.34, h: size * 0.26, fill: Palette.wood.alpha(0.75)), at: Vec2(r.x + r.w * 0.2, r.y + r.h * 0.3))
                    ui.shape("mop.d\(i)b", ShapeSpec(.circle, w: size * 0.2, h: size * 0.18, fill: Palette.wood.alpha(0.6)), at: Vec2(r.x + r.w * 0.55, r.y + r.h * 0.55))
                }
                if prints[i] {
                    ui.icon("mop.p\(i)", .walk, center: r.center, size: size * 0.38, color: Palette.slate.alpha(0.6))
                }
                // Highlight reachable neighbours.
                if !isOver && abs(x - px) + abs(y - py) == 1 {
                    ui.shape("mop.h\(i)", ShapeSpec(.rect, w: r.w, h: r.h, radius: 6, stroke: Palette.navy.alpha(0.45), lineWidth: 2), at: r.origin)
                }
            }
            if i == exit {
                ui.icon("mop.exit", .door, center: Vec2(r.maxX - size * 0.18, r.y + size * 0.18), size: size * 0.3, color: Palette.navy)
            }
        }
        let mr = Rect(o.x + Double(px) * size, o.y + Double(py) * size, size, size)
        ui.badge("mop.me", .mop, center: mr.center, size: size * 0.62, bg: flash > 0 ? Palette.coral : Palette.navy, fg: Palette.paper)
    }
}
