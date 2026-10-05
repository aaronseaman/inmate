import Foundation

/// Mail call: drop each envelope in its pigeonhole. Legal mail is logged, never opened;
/// envelopes without a name go back to sender.
public final class MailSortGame: MinigameBase, Minigame {
    public let id = MinigameID.mailSort
    public let title = "Mail call"
    public let icon = Icon.envelope
    public var controls: [(Icon, String)] {
        [(.envelope, "Read the pod number on the envelope"), (.hand, "Tap its pigeonhole"),
         (.gavel, "Legal mail → the Legal log, unopened"), (.back, "No name → Return to sender")]
    }

    static let holes = ["F-1", "F-2", "F-3", "F-4", "F-5", "F-6", "Legal log", "Return"]

    struct Letter { let dest: Int; let label: String; let legal: Bool; let blank: Bool }

    var letters: [Letter] = []
    var index = 0
    var correct = 0
    var wrong = 0
    var late = 0
    var letterTime: Double
    let perLetter: Double
    var flash: (Int, Bool, Double)?

    public init(_ cfg: MinigameConfig) {
        perLetter = 4.2 * cfg.difficulty.window * (1 - 0.06 * Double(cfg.level - 1))
        letterTime = perLetter
        super.init(cfg, salt: "mail")
        let names = ["D. Okafor", "M. Reyes", "J. Merritt", "T. Lindqvist", "B. Castillo", "H. Pratt", "A. Kowal", "R. Duarte"]
        for _ in 0..<(12 + 2 * cfg.level) {
            let roll = rng.double()
            if roll < 0.15 {
                letters.append(Letter(dest: 6, label: "Legal mail — \(rng.pick(names) ?? "")", legal: true, blank: false))
            } else if roll < 0.25 {
                letters.append(Letter(dest: 7, label: "(no name) F-?", legal: false, blank: true))
            } else {
                let d = rng.int(0, 5)
                letters.append(Letter(dest: d, label: "\(rng.pick(names) ?? "") · \(MailSortGame.holes[d])", legal: false, blank: false))
            }
        }
    }

    var current: Letter? { index < letters.count ? letters[index] : nil }

    public var score: Double { clamp((Double(correct) - 0.3 * Double(wrong)) / Double(letters.count), 0, 1) }

    public var summary: String { "Sorted \(correct) of \(letters.count)\(wrong > 0 ? " · \(wrong) misfiled" : "")" }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let f = flash { flash = f.2 - dt > 0 ? (f.0, f.1, f.2 - dt) : nil }
        letterTime -= dt
        if letterTime <= 0 { late += 1; cue(.error); advance() }
    }

    func advance() {
        index += 1
        letterTime = perLetter
        if index >= letters.count { isOver = true }
    }

    func holeRects(_ c: Rect) -> [Rect] {
        let cols = 4
        let w = min(140, (c.w - 60) / 4), h = min(52, (c.h - 160) / 2)
        let gw = Double(cols) * w + Double(cols - 1) * 10
        let y0 = c.maxY - 2 * h - 16
        return (0..<8).map { i in Rect(c.midX - gw / 2 + Double(i % cols) * (w + 10), y0 + Double(i / cols) * (h + 10), w, h) }
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, let l = current, let i = holeRects(canvas).firstIndex(where: { UIBuilder.touchTarget($0).contains(p) && $0.insetBy(-5).contains(p) }) else { return }
        if i == l.dest { correct += 1; cue(.paper); flash = (i, true, 0.25) } else { wrong += 1; cue(.error); flash = (i, false, 0.35) }
        advance()
    }

    public func botTap(canvas: Rect) -> Vec2? {
        guard elapsed > 0.3, let l = current else { return nil }
        return holeRects(canvas)[l.dest].center
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        ui.mgHeader("ms", "Letter \(min(index + 1, letters.count)) of \(letters.count)", canvas: c)
        ui.mgPips("ms", total: letters.count, good: correct, bad: wrong + late, center: Vec2(c.maxX - 150, c.y + 26))
        if let l = current {
            let er = Rect(c.midX - 150, c.y + 48, 300, 74)
            ui.shape("ms.env", ShapeSpec(.rect, w: er.w, h: er.h, radius: 6, fill: l.legal ? Palette.ivory : Palette.paper, stroke: Palette.wallEdge, lineWidth: 1.5, shadow: true), at: er.origin)
            ui.shape("ms.flap", ShapeSpec(.triangle, w: er.w - 20, h: 18, fill: Palette.wallTop), at: Vec2(er.x + 10, er.y + 4))
            ui.text("ms.to", l.label, Vec2(er.midX, er.y + 32), size: 15, weight: .bold, color: l.blank ? Palette.inkSoft : Palette.ink, align: .center, width: er.w - 20)
            if l.legal { ui.badge("ms.legal", .gavel, center: Vec2(er.maxX - 18, er.y + 18), size: 24, bg: Palette.coral, fg: Palette.paper) }
            let f = clamp(letterTime / perLetter, 0, 1)
            ui.shape("ms.tbg", ShapeSpec(.rect, w: er.w - 30, h: 5, radius: 2.5, fill: Palette.blueGray), at: Vec2(er.x + 15, er.maxY - 10))
            ui.shape("ms.t", ShapeSpec(.rect, w: max(5, (er.w - 30) * f), h: 5, radius: 2.5, fill: f < 0.3 ? Palette.coral : Palette.slate), at: Vec2(er.x + 15, er.maxY - 10))
        }
        for (i, r) in holeRects(c).enumerated() {
            var style: ButtonStyle = .tile
            if let fl = flash, fl.0 == i { style = fl.1 ? .tileSelected : .danger }
            let ic: Icon? = i == 6 ? .gavel : (i == 7 ? .back : .cellDoor)
            ui.mgButton("ms.h\(i)", r, icon: ic, label: MailSortGame.holes[i], style: style, ax: "Pigeonhole \(MailSortGame.holes[i])")
        }
    }
}
