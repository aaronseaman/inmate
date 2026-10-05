import Foundation

/// Developer tools (debug builds / explicit opt-in only; never in release UI).
public enum DevMenu {
    public static let actions: [(String, String)] = [
        ("clock30", "+30 min"), ("clock120", "+2 hours"), ("nextBlock", "Next block"), ("sleep", "Sleep now"),
        ("credits", "+20 credits"), ("trust", "+40 trust"), ("susp0", "Clear suspicion"), ("susp100", "Max suspicion"),
        ("watchY", "Yellow watch"), ("watchR", "Red watch"), ("watch72", "72h watch"), ("watch0", "Clear watch"),
        ("cond", "Outfit cond 20%"), ("outfits", "Give all outfits"), ("keys", "Give keys"), ("tunnels", "Reveal tunnels"),
        ("tp.fpod", "TP F-Pod"), ("tp.yard", "TP yard"), ("tp.kitchen", "TP kitchen"), ("tp.voc", "TP voc rehab"),
        ("tp.support", "TP support"), ("tp.admin", "TP admin"), ("tp.control", "TP control"), ("tp.obs", "TP obs wing"),
        ("tp.tunnel", "TP tunnels"), ("tp.perimeter", "TP perimeter"), ("skipQuest", "Advance main quest"), ("finishDay1", "Skip day 1"),
        ("jobKitchen", "Job: kitchen"), ("jobLaundry", "Job: laundry"), ("jobLibrary", "Job: library"), ("jobInfirmary", "Job: infirmary"),
        ("jobWorkshop", "Job: workshop"), ("jobGrounds", "Job: grounds"), ("jobJanitorial", "Job: janitorial"), ("cones", "Toggle cones"),
        ("scn.lawyer", "Scenario: lawyer met"), ("scn.review", "Scenario: review prep"), ("scn.plan", "Scenario: discharge plan"),
        ("scn.advocacy", "Scenario: advocacy"), ("scn.escape", "Scenario: escape night"), ("scn.cond", "Outfit cond 20%"),
    ]

    /// Seeded story jump-points: a coherent state for each chapter, not just flags.
    static func scenario(_ g: Game, _ key: String) {
        let base: [Flag] = [.claimedBunk, .firstCountDone, .metDutch, .firstTrade, .trialDone, .jobTrialDone, .readChart, .allyMarisol, .firstEveningCount]
        for f in base { g.setFlag(f) }
        var done: [QuestID] = [.m01Intake, .m02Ally, .m03Work, .m04Radio, .m05Cellmate]
        if g.s.player.job == nil { g.assignJob(.janitorial) }
        g.setFlag(.commissaryUnlocked)
        switch key {
        case "scn.lawyer":
            done += [.m06Lawyer]
            g.apply([.set(.lawyerNumberKnown), .set(.phoneListApproved), .set(.calledLawyer), .set(.lawyerMet), .give(.courtDocket, 1), .give(.chartCopy, 1)])
        case "scn.review":
            done += [.m06Lawyer, .m07Contradiction, .m08Records]
            g.apply([.set(.lawyerMet), .set(.phoneListApproved), .set(.contradictionFound), .set(.contradictionReported), .set(.chartCorrected), .give(.transportLog, 1)])
        case "scn.plan":
            done += [.m06Lawyer, .m07Contradiction, .m08Records, .m09Theo, .m10Review]
            g.apply([.set(.lawyerMet), .set(.phoneListApproved), .set(.chartCorrected), .set(.reviewPassed), .set(.theoHelped), .set(.theoResolved)])
        case "scn.advocacy":
            done += [.m06Lawyer, .m09Theo]
            g.apply([.set(.theoTestified), .set(.strickDocumented), .set(.theoResolved), .set(.allyLou), .set(.hymnalReturned)])
        case "scn.escape":
            g.apply([.set(.tunnelHatchKnown), .set(.culvertKnown), .set(.mapAssembled), .startQuest(.m12Escape), .give(.tunnelMap, 1), .give(.utilityKey, 1), .give(.fenceTool, 1)])
            while g.s.day < 6 { g.startNewDay() }
            g.s.minute = 1390
        default: break
        }
        for q in done { g.apply([.completeQuest(q)]) }
    }

    static let teleports: [String: String] = [
        "tp.fpod": "fpod.center", "tp.yard": "yard.post", "tp.kitchen": "dining.post", "tp.voc": "voc.hall.post",
        "tp.support": "support.hall.post", "tp.admin": "clerk.client", "tp.control": "control.seat", "tp.obs": "obs.hall.w",
        "tp.tunnel": "tunnels.patrol.3", "tp.perimeter": "k9.a",
    ]

    public static func run(_ g: Game, _ key: String) {
        switch key {
        case "open": g.ui.modal = .dev; return
        case "page+": g.ui.devPage += 1; g.ui.modal = .dev; return
        case "page-": g.ui.devPage = max(0, g.ui.devPage - 1); g.ui.modal = .dev; return
        case "clock30": g.advanceTime(minutes: 30)
        case "clock120": g.advanceTime(minutes: 120)
        case "nextBlock": if let nb = g.nextBlock { g.s.minute = Double(nb.start) }
        case "sleep": g.ui.modal = nil; g.goToSleep(); return
        case "credits": g.creditDelta(20, "Developer grant")
        case "trust": g.s.trustGainedToday = 0; g.s.trust += 40; g.adjustTrust(0, "dev")
        case "susp0": for i in g.s.npcs.indices { g.s.npcs[i].suspicion = 0; g.s.npcs[i].mode = .resume }
        case "susp100": for i in g.s.npcs.indices where Cast.def(g.s.npcs[i].id).role.isStaff { g.s.npcs[i].suspicion = 99 }
        case "watchY": g.setWatch(.yellow, hours: 24, reason: "Developer")
        case "watchR": g.setWatch(.red, hours: 24, reason: "Developer")
        case "watch72": g.apply([.watch72("Developer")])
        case "watch0": g.apply([.reviewWatch])
        case "cond": g.s.player.outfitCondition = 20
        case "outfits": for o in Outfit.allCases where o != .tanScrubs { g.addItem(o.item, 1, force: true) }
        case "keys": for k in [ItemID.janitorKey, .utilityKey, .recordsKey] { g.addItem(k, 1, force: true) }
        case "tunnels": g.setFlag(.tunnelHatchKnown); g.setFlag(.culvertKnown)
        case "skipQuest":
            if let (q, _) = g.activeMainQuest, let p = g.s.quests[q.id] { g.setStage(q.id, p.stage + 1) }
        case "finishDay1":
            for f in [Flag.claimedBunk, .firstCountDone, .tookMeds, .metDutch, .firstTrade, .trialDone, .jobTrialDone, .readChart, .mouseErrandDeclined, .allyMarisol, .firstEveningCount] { g.setFlag(f) }
        case "cones": g.settings.conesAlways.toggle()
        case "scn.cond": g.s.player.outfitCondition = 20
        default:
            if key.hasPrefix("job"), let j = JobID(rawValue: String(key.dropFirst(3)).lowercased()) { g.assignJob(j) }
            if let spot = teleports[key] { g.apply([.teleport(spot)]) }
            if key.hasPrefix("scn.") { scenario(g, key) }
        }
        g.processEvents()
    }
}
