import Foundation

public enum Interactions {
    public static let all: [InteractionDef] = Day1Interactions.list + SystemInteractions.list + StoryInteractions.list

    public static let byID: [String: InteractionDef] = {
        var d: [String: InteractionDef] = [:]
        for i in all {
            precondition(d[i.id] == nil, "duplicate interaction \(i.id)")
            d[i.id] = i
        }
        return d
    }()

    static let byNPC: [NPCID: [InteractionDef]] = {
        var d: [NPCID: [InteractionDef]] = [:]
        for i in all { if case .npc(let n) = i.target { d[n, default: []].append(i) } }
        return d
    }()
    static let byObject: [String: [InteractionDef]] = {
        var d: [String: [InteractionDef]] = [:]
        for i in all { if case .object(let o) = i.target { d[o, default: []].append(i) } }
        return d
    }()
    static let byKind: [ObjKind: [InteractionDef]] = {
        var d: [ObjKind: [InteractionDef]] = [:]
        for i in all { if case .kind(let k) = i.target { d[k, default: []].append(i) } }
        return d
    }()

    static func forTarget(_ t: TargetRef, map: WorldMap) -> [InteractionDef] {
        switch t {
        case .npc(let n): return (byNPC[n] ?? []).sorted { $0.priority > $1.priority }
        case .object(let id):
            var out = byObject[id] ?? []
            if let o = map.object(id: id) { out += byKind[o.kind] ?? [] }
            return out.sorted { $0.priority > $1.priority }
        case .door: return []
        }
    }

    static func hasAny(for o: WorldObject, map: WorldMap) -> Bool {
        byObject[o.id] != nil || byKind[o.kind] != nil
    }
}

enum Day1Interactions {
    static let list: [InteractionDef] = [
        InteractionDef("intake.claimBunk", .object("fpod.cell3.bunk"), .bed, "Claim the top bunk",
                       when: .notFlag(.claimedBunk), once: true, priority: 10, [
                        .set(.claimedBunk), .bubble(.fitz, [.bed, .stop]), .caption("Fitz: Bottom bunk's mine. Top's yours."),
                        .peer(.fitz, 2), .sound(.paper),
                       ]),
        InteractionDef("dutch.meet", .npc(.dutch), .voice, "Say hello", when: .notFlag(.metDutch), once: true,
                       reply: [.cup, .swap, .snack], priority: 5, [
                        .set(.metDutch), .peer(.dutch, 3), .caption("Dutch: Coffee for a snack. Welcome rate, today only."),
                       ]),
        InteractionDef("haskins.trial", .npc(.haskins), .work, "Ask about work",
                       when: .all([.questStage(.m01Intake, 4), .activity([.work]), .notFlag(.trialDone)]), once: true,
                       reply: [.mop, .door, .clock], priority: 8, [
                        .setJob(.janitorial), .caption("Haskins: Trial shift. Mop's in the closet. Don't make me regret it."),
                        .staff(.haskins, 1),
                       ]),
        InteractionDef("cole.chart", .npc(.cole), .clipboard, "Ask for your chart",
                       when: .all([.notFlag(.readChart), .minuteBetween(650, 1300)]),
                       reply: [.clipboard, .eye], priority: 8, [
                        .set(.readChart), .give(.chartCopy, 1), .doc(.chart), .staff(.cole, 2),
                        .caption("Cole: Here's what they sent with you. Read it. Tell me what's wrong."),
                       ]),
        InteractionDef("cole.chartAgain", .npc(.cole), .clipboard, "Ask for another chart copy",
                       when: .all([.flag(.readChart), .not(.has(.chartCopy))]),
                       reply: [.clipboard, .check], priority: 4, [
                        .give(.chartCopy, 1), .caption("Cole: Another copy. Keep it somewhere safer."),
                       ]),
        InteractionDef("mouse.errand", .npc(.mouse), .note, "Mouse wants a favor",
                       when: .all([.questStage(.m02Ally, 0), .not(.any([.flag(.mouseErrandOffered), .flag(.mouseErrandDeclined), .flag(.mouseErrandReported)]))]),
                       reply: [.note, .question], priority: 8, [
                        .choice(.mouseErrand),
                       ]),
        InteractionDef("mouse.deliver", .npc(.mouse), .note, "Give Mouse the note",
                       when: .all([.has(.note), .flag(.mouseErrandOffered), .notFlag(.mouseNoteFetched)]),
                       reply: [.heart, .thumbsUp], priority: 9, [
                        .take(.note, 1), .set(.mouseNoteFetched), .peer(.mouse, 15), .favor(.mouse, 1),
                        .caption("Mouse: You're quick. I won't forget it."),
                       ]),
        InteractionDef("ally.lou", .npc(.lou), .dumbbell, "Spot Lou on the bench",
                       when: .all([.questStage(.m02Ally, 1), .activity([.rec])]), reply: [.dumbbell, .thumbsUp], priority: 9, [
                        .set(.allyLou), .peer(.lou, 15), .favor(.lou, 1), .caption("Lou: You show up, I show up. That's the deal."),
                       ]),
        InteractionDef("ally.marisol", .npc(.marisol), .gavel, "Ask Marisol about your case",
                       when: .all([.questStage(.m02Ally, 1), .activity([.rec])]), reply: [.gavel, .form, .clock], priority: 9, [
                        .set(.allyMarisol), .peer(.marisol, 15), .caption("Marisol: Bring me paper. Dates, names. Then we talk."),
                       ]),
        InteractionDef("ally.dutch", .npc(.dutch), .cup, "Sit with Dutch",
                       when: .all([.questStage(.m02Ally, 1), .activity([.rec])]), reply: [.cup, .cards, .happy], priority: 9, [
                        .set(.allyDutch), .peer(.dutch, 15), .give(.coffee, 1), .caption("Dutch: Sit. Drink. Nobody bothers you at my bench."),
                       ]),
    ]
}
