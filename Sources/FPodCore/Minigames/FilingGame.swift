import Foundation

/// Records desk filing: tap the folders in alphabetical order by last name.
/// Later rounds bring the tricky ones (Mac / Mc, de la / Del).
public final class FilingGame: MinigameBase, Minigame {
    public let id = MinigameID.filing
    public let title = "Filing backlog"
    public let icon = Icon.form
    public var controls: [(Icon, String)] {
        [(.list, "Six folders per stack"), (.hand, "Tap them in A-to-Z order by last name"),
         (.form, "Same start? Look at the next letter"), (.clock, "Ms. Pruitt is timing you (silently)")]
    }

    static let easy = ["Abbott", "Barros", "Castillo", "Duarte", "Ellison", "Fong", "Garza", "Hollis", "Ibarra", "Jensen", "Kowal", "Lindqvist",
                       "Mendez", "Nakamura", "Okafor", "Pratt", "Quinn", "Rosen", "Sandoval", "Tate", "Ueda", "Vance", "Whitlock", "Yazzie", "Zielinski"]
    static let hard = ["MacArthur", "McAllister", "Mackey", "Madden", "Delgado", "Dellinger", "Dennis", "Deng", "Oakes", "Oakley", "O'Brien",
                       "Ochoa", "Sato", "Satterfield", "Saunders", "Saul", "Bell", "Bellamy", "Bello", "Benton"]

    let rounds: Int
    var round = 0
    var folders: [String] = []
    var filed: [String] = []
    var mistakes = 0
    var shake: (Int, Double)?
    var clock: RunClock

    public init(_ cfg: MinigameConfig) {
        rounds = 4 + min(2, cfg.level - 1)
        clock = RunClock((44 + 8 * Double(cfg.level - 1)) * cfg.difficulty.window)
        super.init(cfg, salt: "filing")
        deal()
    }

    func deal() {
        var pool = round >= 2 && cfg.level >= 2 ? FilingGame.hard : FilingGame.easy
        rng.shuffle(&pool)
        folders = Array(pool.prefix(6))
        filed = []
    }

    static func key(_ s: String) -> String { s.lowercased().filter { $0.isLetter } }
    var nextName: String? { folders.filter { !filed.contains($0) }.min { FilingGame.key($0) < FilingGame.key($1) } }

    public var score: Double {
        let done = Double(round) / Double(rounds)
        let acc = clamp(1 - Double(mistakes) / Double(rounds * 3), 0, 1)
        return clamp(0.7 * done + 0.3 * acc * done, 0, 1)
    }

    public var summary: String { "Filed \(round) of \(rounds) stacks · \(mistakes) slip\(mistakes == 1 ? "" : "s")" }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let s = shake { shake = s.1 - dt > 0 ? (s.0, s.1 - dt) : nil }
        if clock.tick(dt) { isOver = true }
    }

    func folderRects(_ c: Rect) -> [Rect] {
        let cols = 3
        let w = min(190, (c.w - 60) / 3), h = min(58, (c.h - 130) / 2)
        let gw = Double(cols) * w + Double(cols - 1) * 14
        return (0..<6).map { i in Rect(c.midX - gw / 2 + Double(i % cols) * (w + 14), c.y + 50 + Double(i / cols) * (h + 14), w, h) }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, let i = folderRects(canvas).firstIndex(where: { $0.contains(p) }), !filed.contains(folders[i]) else { return }
        if folders[i] == nextName {
            filed.append(folders[i])
            cue(.paper)
            if filed.count == folders.count {
                round += 1
                cue(.confirm)
                if round >= rounds { isOver = true } else { deal() }
            }
        } else {
            mistakes += 1
            shake = (i, 0.35)
            cue(.error)
        }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard elapsed > 0.3, let n = nextName, let i = folders.firstIndex(of: n) else { return nil }
        return folderRects(canvas)[i].center
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("fl", "Stack \(min(round + 1, rounds)) of \(rounds)", canvas: c)
        ui.mgTimer("fl", clock.fraction, canvas: c)
        for (i, r) in folderRects(c).enumerated() {
            let name = folders[i]
            let done = filed.contains(name)
            let dx = shake.map { $0.0 == i ? sin($0.1 * 60) * 4 : 0 } ?? 0
            let rr = r.offsetBy(Vec2(dx, 0))
            ui.shape("fl.tab\(i)", ShapeSpec(.rect, w: rr.w * 0.4, h: 12, radius: 4, fill: done ? Palette.blueGray : Palette.ochre), at: Vec2(rr.x + 8, rr.y - 8))
            ui.shape("fl.f\(i)", ShapeSpec(.rect, w: rr.w, h: rr.h, radius: 6, fill: done ? Palette.blueGray.lighter(0.3) : Palette.ochre.lighter(0.35),
                                           stroke: shake?.0 == i ? Palette.coral : nil, lineWidth: 2, shadow: !done), at: rr.origin)
            ui.text("fl.n\(i)", name, Vec2(rr.midX, rr.midY - 9), size: 15, weight: .bold, color: done ? Palette.inkSoft : Palette.ink, align: .center, width: rr.w - 10)
            if done, let k = filed.firstIndex(of: name) {
                ui.badge("fl.k\(i)", .check, center: Vec2(rr.maxX - 14, rr.y + 14), size: 20, bg: Palette.statusGreen, fg: Palette.paper)
                ui.text("fl.o\(i)", "\(k + 1)", Vec2(rr.x + 14, rr.y + 6), size: 11, weight: .bold, color: Palette.inkSoft, width: 20)
            }
            ui.mgTarget("fl.t\(i)", rr, ax: "Folder: \(name)\(done ? ", filed" : "")")
        }
        let filedLine = filed.isEmpty ? "Tap the first one alphabetically." : "Filed: " + filed.joined(separator: " · ")
        ui.text("fl.line", filedLine, Vec2(c.midX, c.maxY - 26), size: 12, color: Palette.inkSoft, align: .center, width: c.w - 40)
    }
}
