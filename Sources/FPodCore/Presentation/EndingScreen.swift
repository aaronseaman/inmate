import Foundation

extension Game {
    /// The end of a path: what happened, which endings you've seen, and where to go next.
    func buildEnding(_ e: Ending, _ ui0: inout UIBuilder) {
        let r = sheet(&ui0, id: "end", title: e.title, icon: .star, width: 600, tone: .warm)
        var y = r.y + 4
        for (k, l) in Endings.epilogue(e, self).prefix(3).enumerated() {
            y += ui0.text("end.l\(k)", l, Vec2(r.x, y), size: 13, width: r.w - 24, maxLines: 3) + 6
        }
        y += 6
        ui0.text("end.seen", "ENDINGS SEEN", Vec2(r.x, y), size: 11, weight: .bold, color: Palette.slate, width: 200)
        y += 18
        for (k, en) in Ending.allCases.enumerated() {
            let seen = s.endingsSeen.contains(en)
            ui0.badge("end.e\(k)", seen ? .check : .question, center: Vec2(r.x + 12 + Double(k) * 190, y + 12), size: 22,
                      bg: seen ? Palette.statusGreen : Palette.blueGray, fg: Palette.paper)
            ui0.text("end.et\(k)", seen ? en.title : "???", Vec2(r.x + 30 + Double(k) * 190, y + 4), size: 12, weight: .semibold,
                     color: seen ? Palette.ink : Palette.inkSoft, width: 150)
        }
        let bw = (r.w - 20) / 3
        let by = r.maxY - 50
        ui0.button("end.load", Rect(r.x, by, bw, 46), icon: .back, label: "Before the finale", style: .primary, action: .loadPreFinale,
                   ax: "Load the save from before the finale", hint: "Try another ending", enabled: has(.preFinaleSaved))
        ui0.button("end.stay", Rect(r.x + bw + 10, by, bw, 46), icon: .walk, label: "Keep exploring", style: .pill, action: .continueGame, ax: "Close and keep exploring")
        ui0.button("end.new", Rect(r.x + 2 * (bw + 10), by, bw, 46), icon: .plus, label: "New game", style: .pill, action: .newGame, ax: "Start a new game")
    }
}
