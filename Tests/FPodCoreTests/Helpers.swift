import XCTest
@testable import FPodCore

func makeGame(seed: UInt64 = 42) -> Game {
    let g = Game(seed: seed)
    finishTransition(g)
    return g
}

/// Advances the simulation in fixed steps.
func sim(_ g: Game, seconds: Double, dt: Double = 1.0 / 30.0, until: ((Game) -> Bool)? = nil) {
    var t = 0.0
    while t < seconds {
        if g.transition?.isWaitingForTap == true { g.sceneContinueForTests() }
        g.update(dt: dt)
        t += dt
        if let u = until, u(g) { return }
    }
}

/// Taps through any scene cards until the transition ends.
func finishTransition(_ g: Game, maxSeconds: Double = 30) {
    var t = 0.0
    while g.transition != nil && t < maxSeconds {
        if g.transition?.isWaitingForTap == true { g.sceneContinueForTests() }
        g.update(dt: 1.0 / 30.0)
        t += 1.0 / 30.0
    }
}

/// Walks the player to a target and waits for arrival.
@discardableResult
func walkAndWait(_ g: Game, to p: Vec2, timeout: Double = 60) -> Bool {
    guard g.walk(to: p) else { return false }
    sim(g, seconds: timeout, until: { $0.s.player.path.isEmpty })
    return g.s.player.pos.distance(to: p) < 1.0
}

/// Goes to a target and opens its interaction fan (or performs the single action).
func engageAndWait(_ g: Game, _ t: TargetRef, timeout: Double = 60) {
    g.engage(t)
    sim(g, seconds: timeout, until: { $0.ui.modal != nil || ($0.s.player.path.isEmpty && $0.ui.pendingTarget == nil) })
}

func setClock(_ g: Game, _ minute: Double) {
    g.s.minute = minute
}

extension Game {
    func sceneContinueForTests() {
        if let tr = transition, tr.card != nil {
            tr.cardAge = 1
            sceneContinue()
        }
    }
    func fanOptionIDs() -> [String] {
        if case .fan(_, let opts)? = ui.modal { return opts.map { $0.id } }
        return []
    }
}
