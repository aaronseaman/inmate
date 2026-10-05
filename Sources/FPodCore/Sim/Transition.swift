import Foundation

public enum CardTone: Int { case neutral, warm, danger, quiet }

public struct SceneCard {
    public var title: String
    public var icons: [Icon]
    public var lines: [String]
    public var tone: CardTone
    public var button: String
    public init(_ title: String, icons: [Icon], lines: [String], tone: CardTone = .neutral, button: String = "Continue") {
        self.title = title; self.icons = icons; self.lines = lines; self.tone = tone; self.button = button
    }
}

public enum SceneStep {
    case fade(Double, Double)          // target alpha, seconds
    case card(SceneCard)
    case wait(Double)
    case run((Game) -> Void)
    case sound(SFX)
    case music(MusicMood)
    case duck(Double)
}

/// Short, non-interactive sequences (cards wait for a tap). The world is paused.
public final class Transition {
    var steps: [SceneStep]
    var index = 0
    var timer: Double = 0
    var fadeFrom: Double = 0
    public internal(set) var card: SceneCard?
    public internal(set) var cardAge: Double = 0
    var stepStarted = false
    var continueTapped = false

    init(_ steps: [SceneStep]) { self.steps = steps }
    public var isWaitingForTap: Bool { card != nil }
}

extension Game {
    public var fadeAlpha: Double { ui.fade }

    func updateTransition(_ dt: Double) {
        guard let tr = transition else { return }
        var budget = 30
        while budget > 0, transition === tr, tr.index < tr.steps.count {
            budget -= 1
            let step = tr.steps[tr.index]
            switch step {
            case .fade(let target, let secs):
                if !tr.stepStarted { tr.stepStarted = true; tr.fadeFrom = ui.fade; tr.timer = 0 }
                tr.timer += dt
                let t = settings.reducedMotion ? 1 : min(1, tr.timer / max(0.01, secs))
                ui.fade = lerp(tr.fadeFrom, target, t)
                if t < 1 { return }
                advance(tr)
            case .card(let c):
                if !tr.stepStarted { tr.stepStarted = true; tr.card = c; tr.cardAge = 0; tr.continueTapped = false; sound(.paper) }
                tr.cardAge += dt
                if !tr.continueTapped { return }
                tr.card = nil
                advance(tr)
            case .wait(let secs):
                if !tr.stepStarted { tr.stepStarted = true; tr.timer = 0 }
                tr.timer += dt
                if tr.timer < secs { return }
                advance(tr)
            case .run(let f):
                advance(tr)
                f(self)
            case .sound(let sfx):
                sound(sfx)
                advance(tr)
            case .music(let m):
                audioCommands.append(.music(m))
                advance(tr)
            case .duck(let v):
                audioCommands.append(.duck(v))
                advance(tr)
            }
        }
        if transition === tr && tr.index >= tr.steps.count {
            transition = nil
            if let d = pendingDoc { pendingDoc = nil; openDoc(d) }
            processEvents()
        }
    }

    private func advance(_ tr: Transition) {
        tr.index += 1
        tr.stepStarted = false
        tr.timer = 0
    }

    public func sceneContinue() {
        guard let tr = transition, tr.card != nil, tr.cardAge > 0.25 else { return }
        tr.continueTapped = true
    }
}

public enum Scenes {
    static func make(_ id: SceneID, _ g: Game) -> Transition? {
        switch id {
        case .intake: return intake(g)
        case .sleep: return sleep(g)
        case .shakedown: return shakedown(g)
        default: return StoryScenes.make(id, g)
        }
    }

    static func intake(_ g: Game) -> Transition {
        Transition([
            .run { $0.ui.fade = 1 },
            .card(SceneCard("F-Pod", icons: [.cellDoor, .person, .clipboard], lines: [
                "Federal forensic psychiatric center, housing unit F.",
                "\(Cast.playerName), \(Cast.playerNumber). Here for a court-ordered competency evaluation.",
                "Your chart came ahead of you. Not all of it sounds like you.",
            ], tone: .quiet, button: "Begin")),
            .music(.day),
            .fade(0, 1.2),
            .run { g in
                g.bubble(.haskins, [.bed, .arrowRight], seconds: 4, caption: "Bunk's in F-3. Count at six.")
                g.toast(.hand, "Tap the floor to walk. Tap people and things to use them.")
            },
        ])
    }

    static func sleep(_ g: Game) -> Transition {
        Transition([
            .duck(0.4),
            .sound(.sleep),
            .fade(1, 0.9),
            .run { $0.startNewDay() },
            .card(SceneCard("Day \(g.s.day + 1) · \(Schedule.dayName(g.s.day + 1))", icons: [.moon, .sun], lines: g.morningLines(), tone: .quiet, button: "Wake up")),
            .music(.day),
            .duck(1),
            .fade(0, 0.8),
        ])
    }

    static func capture(_ g: Game, _ r: CaptureReport) -> Transition {
        let w = Cast.def(r.witness)
        var lines = ["Reason: \(r.reason.title)", "Searched: \(r.searched.joined(separator: ", "))"]
        if r.confiscated.isEmpty { lines.append("Nothing confiscated.") } else {
            lines.append("Confiscated: " + r.confiscated.map { "\(Items.def($0.id).name)\($0.qty > 1 ? " ×\($0.qty)" : "")" }.joined(separator: ", "))
        }
        lines.append("Consequence: \(r.consequence)")
        lines.append("Next: \(r.recovery)")
        var steps: [SceneStep] = [
            .duck(0.25),
            .sound(.caught),
            .fade(0.85, 0.5),
            .card(SceneCard("Stopped by \(w.short)", icons: [r.reason.icon, .search, .hand], lines: lines, tone: .danger)),
        ]
        if r.reason.severity >= 3 {
            // The room is shown, not the procedure: the player is placed inside, the door closes.
            steps.append(.run { g in
                if let z = g.map.zone(id: "obs.seclusion") {
                    g.s.player.pos = (z.rects.first ?? TileRect(0, 0, 1, 1)).rect.center
                    g.s.player.path = []
                    g.s.player.lastZone = z.id
                    g.ui.camera = g.s.player.pos
                    g.ui.cameraSnap = true
                }
            })
            steps.append(.fade(0.45, 0.6))
            steps.append(.sound(.doorLock))
            steps.append(.card(SceneCard("Seclusion", icons: [.cellDoor, .clock], lines: [
                "A locked room. Four hours, counted by the light under the door.",
                "Afterward: a review, a form, a 72-hour watch.",
            ], tone: .quiet)))
            steps.append(.run { g in g.advanceTime(minutes: 240); g.openDocLater(.seclusionAftermath) })
        }
        steps += [
            .run { $0.afterCapture(r) },
            .fade(0, 0.7),
            .duck(1),
        ]
        return Transition(steps)
    }

    /// Riding hidden in a laundry cart: the world shrinks to slats of light and the sound
    /// of wheels. One officer may lift the lid; the odds rise with facility alert.
    static func concealedRide(_ g: Game, to spot: String, pusher: NPCID) -> Transition {
        var r = RNG(seed: stableHash([g.s.seed, UInt64(g.s.day), UInt64(g.s.minute)]))
        let lifted = r.chance(0.12 + g.s.facilityAlert * 0.3)
        var steps: [SceneStep] = [
            .duck(0.5), .sound(.cartWheels), .fade(0.7, 0.5),
            .card(SceneCard("Under the linens", icons: [.cart, .laundry, .clock], lines: [
                "\(Cast.def(pusher).short) leans on the cart. Wheels, a door, another door.",
                "You see slats of light and somebody's shoes. You can't steer. You can't see much.",
            ], tone: .quiet)),
        ]
        if lifted {
            steps += [
                .sound(.alert),
                .card(SceneCard("The lid lifts", icons: [.eye, .exclaim], lines: ["An officer looks down at you. \"Out.\""], tone: .danger)),
                .run { g in
                    g.s.player.hiddenIn = nil
                    let w = g.s.npcs.filter { $0.present && Cast.def($0.id).role.isStaff }.min { $0.pos.distance(to: g.s.player.pos) < $1.pos.distance(to: g.s.player.pos) }?.id ?? .strick
                    g.captured(by: w, reason: .hidingFromStaff)
                },
            ]
        } else {
            steps += [
                .run { g in
                    g.s.player.hiddenIn = nil
                    if let sp = g.map.spot(spot) {
                        g.s.player.pos = sp.pos; g.s.player.path = []; g.ui.camera = sp.pos; g.ui.cameraSnap = true
                        if let z = g.map.zone(at: sp.pos) { g.s.player.lastZone = z.id; g.s.player.lastDistrict = z.district; g.emit(.zoneEntered(z.id)) }
                    }
                    g.stat("cart.rides")
                },
                .fade(0, 0.6), .duck(1),
            ]
        }
        return Transition(steps)
    }

    static func shakedown(_ g: Game) -> Transition {
        Transition([
            .duck(0.4),
            .sound(.keys),
            .fade(0.7, 0.4),
            .run { g in
                let r = g.searchCell(g.s.player.cell, thorough: false)
                g.confiscate(r.found)
                g.s.lastSearch = r.searched
                g.shakedownSummary = (r.searched.compactMap { g.stashByObject[$0]?.title }, r.found)
            },
            .card(SceneCard("Cell search", icons: [.search, .cellDoor], lines: ["Officers toss F-\(g.s.player.cell).", "Only the places they opened are affected."], tone: .danger)),
            .run { g in
                let (places, found) = g.shakedownSummary
                g.toast(.search, "Searched: \(places.isEmpty ? "nothing" : places.joined(separator: ", "))")
                if !found.isEmpty { g.toast(.hand, "Taken: " + found.map { Items.def($0.id).name }.joined(separator: ", "), danger: true) }
            },
            .fade(0, 0.5),
            .duck(1),
        ])
    }
}

extension Game {
    func morningLines() -> [String] {
        var lines: [String] = []
        if s.watch != .green { lines.append("Watch: \(s.watch.short) · \(Int(watchHoursLeft.rounded()))h left") }
        if let r = s.recovery { lines.append("To do: \(r.text)") }
        let today = s.appointments.filter { $0.day == s.day + 1 && !$0.attended }
        for a in today { lines.append("\(Schedule.clockString(Double(a.start))) \(a.title)") }
        if lines.isEmpty { lines.append("Count at 06:00. Med pass after.") }
        return lines
    }

    func openDocLater(_ d: DocID) { pendingDoc = d }
}
