import Foundation

/// Art therapy: compose a picture from cut-paper shapes for the session's prompt.
/// Pick a shape and a color, tap the paper to place it, then tap Finish.
/// Balanced, varied pictures that answer the prompt sell for more.
public final class ArtGame: MinigameBase, Minigame {
    public let id = MinigameID.art
    public let title = "Art therapy"
    public let icon = Icon.palette
    public var controls: [(Icon, String)] {
        [(.palette, "Pick a shape and a color on the right"), (.hand, "Tap the paper to place it"),
         (.question, "Answer the prompt; balance and variety help"), (.check, "Tap Finish when you're happy")]
    }

    enum ShapeKind: Int, CaseIterable { case circle, square, triangle
        var spec: ShapeSpec.Kind { [.circle, .rect, .triangle][rawValue] }
        var title: String { ["Circle", "Square", "Triangle"][rawValue] }
    }
    static let colors: [(RGBA, String)] = [(Palette.coral, "Coral"), (Palette.ochre, "Ochre"), (Palette.turquoise, "Turquoise"),
                                          (Palette.navy, "Navy"), (Palette.grassDark, "Green")]

    struct Prompt { let title: String; let hint: String }
    static let prompts: [Prompt] = [
        Prompt(title: "The yard at noon", hint: "An ochre circle up high, something green down low"),
        Prompt(title: "A window", hint: "A navy or turquoise square, and at least four shapes"),
        Prompt(title: "Someone you miss", hint: "Two or more circles, with some coral"),
        Prompt(title: "Quiet", hint: "Five or more shapes, two colors at most"),
        Prompt(title: "Home", hint: "A triangle sitting above a square"),
    ]

    struct Stamp { let kind: ShapeKind; let color: Int; let pos: Vec2 }   // pos in 0...1 paper space

    let prompt: Int
    var stamps: [Stamp] = []
    var shape: ShapeKind = .circle
    var color = 0
    var clock: RunClock
    let maxStamps = 16
    var finished = false
    var botPlan: [Stamp] = []

    public init(_ cfg: MinigameConfig) {
        clock = RunClock(70 * cfg.difficulty.window)
        var r = RNG(seed: cfg.seed ^ 0xA27)
        prompt = r.int(0, ArtGame.prompts.count - 1)
        super.init(cfg, salt: "art")
        botPlan = makePlan()
    }

    // MARK: Scoring

    var promptMet: Bool {
        switch prompt {
        case 0:
            return stamps.contains { $0.kind == .circle && $0.color == 1 && $0.pos.y < 0.4 } && stamps.contains { $0.color == 4 && $0.pos.y > 0.5 }
        case 1:
            return stamps.contains { $0.kind == .square && ($0.color == 3 || $0.color == 2) } && stamps.count >= 4
        case 2:
            return stamps.filter { $0.kind == .circle }.count >= 2 && stamps.contains { $0.color == 0 }
        case 3:
            return stamps.count >= 5 && Set(stamps.map { $0.color }).count <= 2
        default:
            return stamps.contains { t in t.kind == .triangle && stamps.contains { s in s.kind == .square && s.pos.y > t.pos.y + 0.05 && abs(s.pos.x - t.pos.x) < 0.2 } }
        }
    }

    var composition: Double {
        guard !stamps.isEmpty else { return 0 }
        let n = Double(stamps.count)
        let count = n < 4 ? n / 4 : (n <= 12 ? 1 : max(0, 1 - (n - 12) / 6))
        let colorsUsed = Double(Set(stamps.map { $0.color }).count)
        let variety = prompt == 3 ? 1 : min(1, colorsUsed / 3)
        var com = Vec2(0, 0)
        for s in stamps { com += s.pos }
        com = com / n
        let balance = clamp(1 - ((com - Vec2(0.5, 0.5)).length - 0.08) / 0.25, 0, 1)
        let xs = stamps.map { $0.pos.x }, ys = stamps.map { $0.pos.y }
        let spread = clamp(((xs.max()! - xs.min()!) * (ys.max()! - ys.min()!)) / 0.3, 0, 1)
        return (count + variety + balance + spread) / 4
    }

    public var score: Double { clamp(0.45 * (promptMet ? 1 : 0) + 0.55 * composition, 0, 1) }

    /// What Kenji would pay for it at the art table.
    public var saleValue: Int { stamps.isEmpty ? 0 : 1 + Int((score * 5).rounded()) }

    public var summary: String {
        if stamps.isEmpty { return "A blank page" }
        return "\"\(ArtGame.prompts[prompt].title)\" — \(promptMet ? "on prompt" : "off prompt") · worth about \(saleValue) credits"
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if clock.tick(dt) { isOver = true }
    }

    // MARK: Layout

    struct Layout { var paper: Rect; var shapes: [Rect]; var colors: [Rect]; var finish: Rect; var undo: Rect }

    func layout(_ c: Rect) -> Layout {
        let side = 210.0
        let paperH = c.h - 56
        let paperW = min(c.w - side - 30, paperH * 1.45)
        let paper = Rect(c.x + 14, c.y + 46, paperW, paperH)
        let px = c.maxX - side
        let shapes = (0..<3).map { Rect(px + Double($0) * 66, c.y + 46, 58, 52) }
        let colors = (0..<5).map { Rect(px + Double($0) * 40, c.y + 108, 34, 34) }
        let finish = Rect(px, c.maxY - 56, side - 10, 48)
        let undo = Rect(px, c.maxY - 112, side - 10, 44)
        return Layout(paper: paper, shapes: shapes, colors: colors, finish: finish, undo: undo)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver else { return }
        let L = layout(canvas)
        if let i = L.shapes.firstIndex(where: { UIBuilder.touchTarget($0).contains(p) }) { shape = ShapeKind(rawValue: i)!; cue(.tap); return }
        if let i = L.colors.firstIndex(where: { UIBuilder.touchTarget($0).contains(p) }) { color = i; cue(.tap); return }
        if UIBuilder.touchTarget(L.finish).contains(p) { if !stamps.isEmpty { finished = true; isOver = true; cue(.confirm) }; return }
        if UIBuilder.touchTarget(L.undo).contains(p) { if !stamps.isEmpty { stamps.removeLast(); cue(.paper) }; return }
        if L.paper.insetBy(10).contains(p) && stamps.count < maxStamps {
            let pos = Vec2((p.x - L.paper.x) / L.paper.w, (p.y - L.paper.y) / L.paper.h)
            stamps.append(Stamp(kind: shape, color: color, pos: pos))
            cue(.paper)
        }
    }

    /// A tidy picture that answers the prompt.
    func makePlan() -> [Stamp] {
        switch prompt {
        case 0: return [Stamp(kind: .circle, color: 1, pos: Vec2(0.7, 0.22)), Stamp(kind: .square, color: 4, pos: Vec2(0.25, 0.75)),
                        Stamp(kind: .square, color: 4, pos: Vec2(0.5, 0.78)), Stamp(kind: .triangle, color: 4, pos: Vec2(0.75, 0.75)),
                        Stamp(kind: .circle, color: 2, pos: Vec2(0.3, 0.3)), Stamp(kind: .triangle, color: 0, pos: Vec2(0.5, 0.5))]
        case 1: return [Stamp(kind: .square, color: 3, pos: Vec2(0.35, 0.35)), Stamp(kind: .square, color: 2, pos: Vec2(0.65, 0.35)),
                        Stamp(kind: .square, color: 2, pos: Vec2(0.35, 0.65)), Stamp(kind: .square, color: 3, pos: Vec2(0.65, 0.65)),
                        Stamp(kind: .circle, color: 1, pos: Vec2(0.5, 0.15)), Stamp(kind: .triangle, color: 0, pos: Vec2(0.5, 0.85))]
        case 2: return [Stamp(kind: .circle, color: 0, pos: Vec2(0.35, 0.4)), Stamp(kind: .circle, color: 2, pos: Vec2(0.65, 0.4)),
                        Stamp(kind: .square, color: 3, pos: Vec2(0.35, 0.7)), Stamp(kind: .square, color: 1, pos: Vec2(0.65, 0.7)),
                        Stamp(kind: .triangle, color: 0, pos: Vec2(0.5, 0.2))]
        case 3: return [Stamp(kind: .circle, color: 3, pos: Vec2(0.25, 0.3)), Stamp(kind: .circle, color: 2, pos: Vec2(0.75, 0.3)),
                        Stamp(kind: .square, color: 3, pos: Vec2(0.5, 0.5)), Stamp(kind: .triangle, color: 2, pos: Vec2(0.25, 0.75)),
                        Stamp(kind: .triangle, color: 3, pos: Vec2(0.75, 0.75)), Stamp(kind: .circle, color: 2, pos: Vec2(0.5, 0.82))]
        default: return [Stamp(kind: .triangle, color: 0, pos: Vec2(0.5, 0.3)), Stamp(kind: .square, color: 1, pos: Vec2(0.5, 0.58)),
                         Stamp(kind: .circle, color: 2, pos: Vec2(0.18, 0.2)), Stamp(kind: .square, color: 4, pos: Vec2(0.2, 0.8)),
                         Stamp(kind: .square, color: 4, pos: Vec2(0.8, 0.8)), Stamp(kind: .triangle, color: 3, pos: Vec2(0.82, 0.35))]
        }
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard elapsed > 0.3 else { return nil }
        let L = layout(canvas)
        if stamps.count >= botPlan.count { return L.finish.center }
        let next = botPlan[stamps.count]
        if shape != next.kind { return L.shapes[next.kind.rawValue].center }
        if color != next.color { return L.colors[next.color].center }
        return Vec2(L.paper.x + next.pos.x * L.paper.w, L.paper.y + next.pos.y * L.paper.h)
    }

    // MARK: Render

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        let L = layout(c)
        let pr = ArtGame.prompts[prompt]
        ui.text("art.prompt", "Prompt: \(pr.title)", Vec2(c.x + 20, c.y + 6), size: 15, weight: .bold, width: L.paper.w)
        ui.text("art.hint", pr.hint, Vec2(c.x + 20, c.y + 26), size: 11.5, color: Palette.inkSoft, width: L.paper.w)
        ui.mgTimer("art", clock.fraction, canvas: c)
        ui.shape("art.paper", ShapeSpec(.rect, w: L.paper.w, h: L.paper.h, radius: 6, fill: Palette.white, shadow: true), at: L.paper.origin)
        let unit = min(L.paper.w, L.paper.h) * 0.2
        for (i, s) in stamps.enumerated() {
            let center = Vec2(L.paper.x + s.pos.x * L.paper.w, L.paper.y + s.pos.y * L.paper.h)
            ui.shape("art.s\(i)", ShapeSpec(s.kind.spec, w: unit, h: unit, radius: s.kind == .square ? 4 : 0, fill: ArtGame.colors[s.color].0),
                     at: center - Vec2(unit / 2, unit / 2))
        }
        ui.mgTarget("art.canvas", L.paper, ax: "Paper: place a \(ArtGame.colors[color].1.lowercased()) \(shape.title.lowercased())")
        for (i, r) in L.shapes.enumerated() {
            let k = ShapeKind(rawValue: i)!
            let sel = shape == k
            ui.mgButton("art.sh\(i)", r, style: sel ? .tileSelected : .tile, ax: "Shape: \(k.title)")
            ui.shape("art.shi\(i)", ShapeSpec(k.spec, w: 26, h: 26, radius: 3, fill: sel ? Palette.paper : Palette.ink), at: r.center - Vec2(13, 13))
        }
        for (i, r) in L.colors.enumerated() {
            let sel = color == i
            ui.shape("art.cs\(i)", ShapeSpec(.circle, w: r.w, h: r.h, fill: ArtGame.colors[i].0, stroke: sel ? Palette.ink : Palette.paper, lineWidth: sel ? 4 : 2), at: r.origin)
            ui.mgTarget("art.c\(i)", r, ax: "Color: \(ArtGame.colors[i].1)")
        }
        ui.text("art.count", "\(stamps.count)/\(maxStamps) shapes", Vec2(L.colors[0].x, L.colors[0].maxY + 12), size: 12, color: Palette.inkSoft, width: 200)
        ui.mgButton("art.undo", L.undo, icon: .back, label: "Undo", style: .pill, ax: "Undo last shape", enabled: !stamps.isEmpty)
        ui.mgButton("art.finish", L.finish, icon: .check, label: "Finish", style: .primary, ax: "Finish the picture", enabled: !stamps.isEmpty)
    }
}
