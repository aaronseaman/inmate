import Foundation

public enum Quests {
    public static let all: [QuestDef] = MainQuests.list + SideQuests.list

    public static let byID: [QuestID: QuestDef] = {
        var d: [QuestID: QuestDef] = [:]
        for q in all { d[q.id] = q }
        return d
    }()

    public static var main: [QuestDef] { all.filter { $0.kind == .main } }
    public static var side: [QuestDef] { all.filter { $0.kind == .side } }
}

enum MainQuests {
    static let list: [QuestDef] = day1 + StoryQuests.main

    static let day1: [QuestDef] = [
        QuestDef(.m01Intake, .main, "Intake", icon: .cellDoor, giver: .haskins, location: "F-Pod",
                 summary: "Find your bunk, survive your first count, and read the chart that arrived before you.",
                 prerequisite: .always, stages: [
                    StageDef("Find your bunk in cell F-3", icon: .bed, marker: .object("fpod.cell3.bunk"),
                             completeWhen: .flag(.claimedBunk), approaches: ["Tap the bunk in F-3 (top row of cells)."]),
                    StageDef("Count: stay in F-3 until it clears", icon: .count, marker: .zone("fpod.cell3"),
                             completeWhen: .flag(.firstCountDone), approaches: ["Be inside your cell when the buzzer sounds; 2 minutes' grace."],
                             recovery: "Missed it? Get back to F-3 — a late return is recorded as late, not missing."),
                    StageDef("Med pass at the window by the officer station", icon: .pills, marker: .object("fpod.medwindow"),
                             completeWhen: .any([.flag(.tookMeds), .flag(.medDiscussRequested), .flag(.medDeclined), .minuteBetween(420, 1440)]),
                             approaches: ["Take it, ask to discuss it, or decline — each has its own follow-up."]),
                    StageDef("Breakfast: say hello to Dutch in the dining hall", icon: .meal, marker: .npc(.dutch),
                             completeWhen: .any([.flag(.firstTrade), .all([.flag(.metDutch), .minuteBetween(470, 1440)]), .minuteBetween(480, 1440)]),
                             approaches: ["Dutch trades coffee for snacks — try the welcome rate."]),
                    StageDef("Work detail: ask CO Haskins for a trial shift", icon: .work, marker: .npc(.haskins),
                             completeWhen: .any([.flag(.trialDone), .minuteBetween(660, 1440)]),
                             approaches: ["She assigns you the mop. The closet is in the top-right corner of the pod."],
                             recovery: "Missed the window? Haskins offers another trial tomorrow."),
                    StageDef("Group: ask Tech Cole for your chart", icon: .clipboard, marker: .npc(.cole),
                             completeWhen: .flag(.readChart),
                             approaches: ["Group is in the support wing at 11:00. Cole also carries it around the pod afterward."],
                             recovery: "Lost the copy? Cole will print another."),
                 ], reward: "Your chart copy (evidence later).", worldChange: "You know the shape of a day here.",
                 failure: "Nothing here fails permanently; missed windows reopen tomorrow."),
        QuestDef(.m02Ally, .main, "Routine and a first ally", icon: .people, giver: nil, location: "F-Pod & yard",
                 summary: "Find your footing: a favor asked, a bench chosen, a count made.",
                 prerequisite: .questDone(.m01Intake), autoStart: true, stages: [
                    StageDef("Afternoon: Mouse is looking for you", icon: .note, marker: .npc(.mouse),
                             completeWhen: .any([.flag(.mouseNoteFetched), .flag(.mouseErrandReported), .flag(.mouseErrandDeclined), .minuteBetween(900, 1440)]),
                             approaches: ["Help her (risky), decline, or tell an officer."]),
                    StageDef("Rec yard: choose who you stand with", icon: .ball, marker: .zone("yard"),
                             completeWhen: .any([.flag(.allyLou), .flag(.allyMarisol), .flag(.allyDutch)]),
                             approaches: ["Lou at the weights (protection)", "Marisol on the bleachers (legal help)", "Dutch on his bench (trade)"]),
                    StageDef("Evening count in F-3", icon: .count, marker: .zone("fpod.cell3"), completeWhen: .flag(.firstEveningCount)),
                    StageDef("Lights out: sleep at your bunk", icon: .moon, marker: .object("fpod.cell3.bunk"), completeWhen: .dayAtLeast(2)),
                 ], reward: "An ally with their own perk and path.", worldChange: "Peers start treating you as someone with a side.",
                 failure: "If you miss rec, the yard is there tomorrow."),
    ]
}

enum SideQuests {
    static let list: [QuestDef] = StoryQuests.side
}
