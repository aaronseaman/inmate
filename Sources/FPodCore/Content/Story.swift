import Foundation

/// Cross-cutting story logic: event hooks, daily hooks, critical-item recovery.
public enum Story {
    static func onEvent(_ g: Game, _ e: GameEvent) {
        switch e {
        case .shiftDone(let job, let score):
            g.noteWatchProgress("shift")
            Systems.afterShift(g, job, score)
            if job == .janitorial && !g.has(.trialDone) {
                g.setFlag(.trialDone)
                g.setFlag(.jobTrialDone)
                if score >= 0.6 { g.setFlag(.trialGood) }
                // The trial ends; a real assignment is earned later.
                g.s.player.job = nil
                _ = g.removeItem(.janitorKey, 1)
                g.bubble(.haskins, score >= 0.6 ? [.thumbsUp, .mop] : [.thumbsDown, .clock], seconds: 3,
                         caption: score >= 0.6 ? "Not bad. We'll see." : "Needs work. We'll see.")
                g.toast(.mop, "Trial shift returned the key")
            }
        case .countCleared:
            if g.s.countState.activeStart >= 1200 { g.setFlag(.firstEveningCount) }
            if g.s.countState.present { g.noteWatchProgress("count") }
        case .appointmentKept(let id):
            Systems.appointmentKept(g, id)
        case .interacted(let id):
            if id == "group.join" { g.noteWatchProgress("group") }
        case .flagSet(let f) where f == .chartCorrected || f == .reviewPassed:
            let floor = f == .reviewPassed ? 5 : 3
            if g.s.trustTierFloor < floor {
                g.s.trustTierFloor = floor
                g.toast(.trust, f == .reviewPassed ? "Trust tier 5 — discharge planning opens" : "Trust tier 3 — senior pay, more calls")
            }
        case .flagSet(let f):
            if f == .mouseErrandOffered {
                g.s.stashes["fpod.hamper2", default: []].append(ItemStack(.note, 1, owner: nil))
            }
        default:
            break
        }
        StoryHooks.onEvent(g, e)
    }

    static func dailyHooks(_ g: Game) {
        Systems.daily(g)
        StoryHooks.daily(g)
    }

    /// A critical item was confiscated: there is always another way.
    static func criticalItemLost(_ g: Game, _ item: ItemID) {
        let hint: String
        switch item {
        case .chartCopy: hint = "Tech Cole can print another chart copy."
        case .courtDocket, .lawyerCard: hint = "Call or write Ms. Calloway — she'll resend it."
        case .transportLog, .recordsRequest: hint = "Claim it back from Ms. Pruitt, or file a new request."
        case .radio: hint = "Radios are claimable property at the records desk."
        case .mapScrapA, .mapScrapB, .mapScrapC, .tunnelMap: hint = "Mouse remembers the routes — she can redraw the map."
        case .utilityKey: hint = "Static knows how the old keys were cut."
        case .lawBook: hint = "Ms. Abernathy will reissue it after a lecture."
        case .grievanceForm: hint = "Ms. Pruitt keeps blank grievance forms."
        default: hint = "Ask around — there's a way to replace it."
        }
        g.toast(.info, hint)
        g.s.recoveryHints[item] = hint
    }
}
