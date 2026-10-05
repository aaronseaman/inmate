import Foundation

extension Game {
    /// Builds the complete display list for this frame and refreshes hit regions.
    public func buildFrame() -> Frame {
        var f = Frame()
        f.camera = ui.camera
        f.tileSize = settings.zoom
        f.viewport = viewport.size
        f.background = Palette.woodsDark
        buildWorld(into: &f.items, polys: &f.polys)
        var ui0 = UIBuilder(z: 100, labels: settings.iconLabels)
        if transition == nil && minigame == nil {
            if !isFullScreenModal { buildHUD(&ui0) }
            if let m = ui.modal { buildModal(m, &ui0) }
        }
        let fadeA = max(ui.fade, ui.districtFade * 0.55)
        if fadeA > 0.01 {
            ui0.z = 5000
            ui0.art("fade", .named("fade", Int(viewport.size.x) + 2, Int(viewport.size.y) + 2), at: Vec2(-1, -1), alpha: fadeA)
        }
        if let mg = minigame {
            ui0.z = 6000
            ui0.hits = []
            ui0.ax = []
            buildMinigame(mg, &ui0)
        }
        if let tr = transition, let card = tr.card {
            ui0.z = 7000
            ui0.hits = []
            ui0.ax = []
            buildSceneCard(card, age: tr.cardAge, &ui0)
        }
        f.items += ui0.items
        f.polys += ui0.polys
        ui.hitRegions = ui0.hits
        f.accessibility = ui0.ax
        return f
    }

    // MARK: Scene card

    func buildSceneCard(_ card: SceneCard, age: Double, _ ui0: inout UIBuilder) {
        let safe = viewport.safeRect
        let w = min(560, safe.w - 40)
        let lineH = TextMetrics.lineHeight(14)
        var textH = 0.0
        for l in card.lines { textH += Double(TextMetrics.wrap(l, size: 14, width: w - 48).count) * lineH + 6 }
        let h = min(safe.h - 20, 150 + textH)
        let a = settings.reducedMotion ? 1 : min(1, age * 4)
        let r = Rect(safe.midX - w / 2, safe.midY - h / 2 + (1 - a) * 12, w, h)
        ui0.panel("scene.card", r, .sheet, alpha: a)
        let bg: RGBA
        switch card.tone {
        case .danger: bg = Palette.coral
        case .warm: bg = Palette.ochre
        case .quiet: bg = Palette.slate
        case .neutral: bg = Palette.navy
        }
        let iconsW = Double(card.icons.count) * 44
        for (k, ic) in card.icons.enumerated() {
            ui0.badge("scene.ic\(k)", ic, center: Vec2(r.midX - iconsW / 2 + 22 + Double(k) * 44, r.y + 34), size: 36, bg: bg, fg: Palette.paper, alpha: a)
        }
        ui0.text("scene.title", card.title, Vec2(r.midX, r.y + 60), size: 18, weight: .bold, align: .center, width: w - 40, alpha: a)
        var y = r.y + 90
        for (k, l) in card.lines.enumerated() {
            y += ui0.text("scene.l\(k)", l, Vec2(r.x + 24, y), size: 14, width: w - 48, maxLines: 4, alpha: a) + 6
        }
        let br = Rect(r.midX - 90, r.maxY - 56, 180, 44)
        ui0.button("scene.go", br, icon: .arrowRight, label: card.button, style: .primary, action: .sceneContinue, ax: card.button)
        ui0.hit(Rect(0, 0, viewport.size.x, viewport.size.y), .sceneContinue)
        ui0.ax.append(AXElement(id: "scene.text", rect: r, label: card.title + ". " + card.lines.joined(separator: " "), hint: nil, isButton: false))
    }

    // MARK: Minigame overlay

    public var minigameCanvas: Rect {
        let safe = viewport.safeRect
        return Rect(safe.x + 12, safe.y + 56, safe.w - 24, safe.h - 66)
    }

    func buildMinigame(_ mg: MinigameSession, _ ui0: inout UIBuilder) {
        let safe = viewport.safeRect
        ui0.panel("mg.bg", Rect(0, 0, viewport.size.x, viewport.size.y), .scrim)
        let sheetR = Rect(safe.x + 4, safe.y + 4, safe.w - 8, safe.h - 8)
        ui0.panel("mg.sheet", sheetR, .sheet)
        ui0.hit(Rect(0, 0, viewport.size.x, viewport.size.y), .none)
        ui0.badge("mg.ic", mg.game.icon, center: Vec2(sheetR.x + 30, sheetR.y + 28), size: 32, bg: Palette.navy, fg: Palette.paper)
        ui0.text("mg.title", mg.game.title, Vec2(sheetR.x + 54, sheetR.y + 17), size: 16, weight: .bold, width: sheetR.w - 200)
        let canvas = minigameCanvas
        switch mg.phase {
        case .intro:
            ui0.button("mg.back", Rect(sheetR.maxX - 50, sheetR.y + 6, 42, 42), icon: .close, style: .round, action: .minigameQuit, ax: "Back without playing")
            var y = canvas.y + 10
            ui0.text("mg.how", "HOW TO PLAY", Vec2(canvas.x + 20, y), size: 11, weight: .bold, color: Palette.slate, width: 200)
            y += 24
            for (k, c) in mg.game.controls.enumerated() {
                ui0.badge("mg.c\(k)", c.0, center: Vec2(canvas.x + 36, y + 14), size: 30, bg: Palette.turquoise.darker(0.15), fg: Palette.paper)
                ui0.text("mg.c\(k).t", c.1, Vec2(canvas.x + 60, y + 5), size: 13.5, width: canvas.w - 300)
                y += 40
            }
            if mg.alreadyClaimed { ui0.text("mg.claimed", "Already rewarded for this one — playing is just for practice.", Vec2(canvas.x + 20, y + 6), size: 12, color: Palette.inkSoft, width: canvas.w - 300) }
            ui0.text("mg.pause", "The clock is paused while you play.", Vec2(canvas.x + 20, canvas.maxY - 30), size: 11.5, color: Palette.inkSoft, width: 300)
            ui0.button("mg.start", Rect(canvas.maxX - 200, canvas.maxY - 60, 190, 50), icon: .play, label: "Start", style: .primary, action: .minigameStart, ax: "Start")
            if settings.assistMinigames {
                ui0.button("mg.assist", Rect(canvas.maxX - 200, canvas.maxY - 118, 190, 46), icon: .star, label: "Assist: auto-pass", style: .pill, action: .minigameAssist, ax: "Assist mode: pass with a basic score")
            }
        case .playing:
            ui0.button("mg.quit", Rect(sheetR.maxX - 50, sheetR.y + 6, 42, 42), icon: .close, style: .round, action: .minigameQuit, ax: "Quit (no reward)")
            ui0.hit(canvas, .minigameButton(-1))
            mg.game.render(&ui0, canvas: canvas, time: mg.time)
        case .result:
            let stars = mg.stars
            ui0.art("mg.stars", .named("stars", stars, 0), at: Vec2(canvas.midX - 50, canvas.y + 30))
            ui0.text("mg.score", mg.quit ? "Left early" : (mg.assisted ? "Assisted pass" : "Score \(Int((mg.finalScore * 100).rounded()))%"), Vec2(canvas.midX, canvas.y + 76), size: 20, weight: .bold, align: .center, width: 300)
            ui0.text("mg.sum", mg.quit ? "No reward." : mg.game.summary, Vec2(canvas.midX, canvas.y + 108), size: 13.5, color: Palette.inkSoft, align: .center, width: canvas.w - 60, maxLines: 2)
            let preview = rewardPreview(mg)
            if !preview.isEmpty { ui0.text("mg.reward", preview, Vec2(canvas.midX, canvas.y + 150), size: 14, weight: .semibold, align: .center, width: canvas.w - 60, maxLines: 2) }
            ui0.button("mg.done", Rect(canvas.midX - 100, canvas.maxY - 64, 200, 50), icon: .check, label: "Continue", style: .primary, action: .minigameContinue, ax: "Continue")
        }
    }

    func rewardPreview(_ mg: MinigameSession) -> String {
        if mg.quit { return "" }
        switch mg.outcome {
        case .shift(let job):
            let def = Jobs.def(job)
            if mg.alreadyClaimed { return "This shift was already paid." }
            let pay = shiftPay(job, score: mg.finalScore)
            return "Pay: \(pay) credits · \(def.title)"
        case .script:
            if mg.alreadyClaimed { return "Already rewarded." }
            return mg.passed ? "Passed!" : "Not quite — you can try again."
        }
    }
}
