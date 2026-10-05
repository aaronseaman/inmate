import Foundation

public struct ChoiceOption {
    public let icon: Icon
    public let label: String
    public let detail: String
    public let when: Cond
    public let effects: [Effect]
    public let risky: Bool
    public init(_ icon: Icon, _ label: String, _ detail: String, when: Cond = .always, risky: Bool = false, _ effects: [Effect]) {
        self.icon = icon; self.label = label; self.detail = detail; self.when = when; self.effects = effects; self.risky = risky
    }
}

public struct ChoiceDef {
    public let id: ChoiceID
    public let title: String
    public let icon: Icon
    public let prompt: String
    public let speaker: NPCID?
    public let options: [ChoiceOption]
}

/// Story decisions. Each option has situational consequences — no universal virtue score.
public enum Choices {
    public static let all: [ChoiceDef] = Day1Choices.list + SystemChoices.list + StoryChoices.list

    public static let byID: [ChoiceID: ChoiceDef] = {
        var d: [ChoiceID: ChoiceDef] = [:]
        for c in all { d[c.id] = c }
        return d
    }()
}

enum Day1Choices {
    static let list: [ChoiceDef] = [
        ChoiceDef(id: .medPass, title: "Med pass", icon: .pills,
                  prompt: "Nurse Okonjo has the morning dose your chart prescribes. He'll explain it if you ask.",
                  speaker: .okonjo, options: [
                    ChoiceOption(.check, "Take it", "Routine noted. You'll feel it by mid-morning.", when: .notFlag(.tookMeds), [
                        .set(.tookMeds), .staff(.okonjo, 1), .bubble(.okonjo, [.thumbsUp]), .toast(.pills, "Med pass done"),
                    ]),
                    ChoiceOption(.question, "Ask to discuss it", "Okonjo books you with Dr. Sato. Nothing is held against you.", [
                        .set(.medDiscussRequested), .staff(.okonjo, 1), .bubble(.okonjo, [.stethoscope, .clock]),
                        .appointment(id: "sato.meds", dayOffset: 1, start: 810, end: 870, title: "Dr. Sato: medication talk", icon: .stethoscope, spot: "sato.client", npc: .sato, quest: nil),
                    ]),
                    ChoiceOption(.stop, "Decline today", "Recorded as declined. Dr. Sato will want to talk — that's all.", [
                        .set(.medDeclined), .bubble(.okonjo, [.form, .clock]),
                        .appointment(id: "sato.meds", dayOffset: 1, start: 810, end: 870, title: "Dr. Sato: medication talk", icon: .stethoscope, spot: "sato.client", npc: .sato, quest: nil),
                    ]),
                  ]),
        ChoiceDef(id: .mouseErrand, title: "Mouse's favor", icon: .note,
                  prompt: "Mouse stashed a folded note in the laundry alcove hamper. CO Strick is doing rounds. She wants it back before he finds it.",
                  speaker: .mouse, options: [
                    ChoiceOption(.hand, "I'll get it", "Grab it from the hamper without Strick seeing. Hiding spots are nearby.", risky: true, [
                        .set(.mouseErrandOffered), .peer(.mouse, 3), .bubble(.mouse, [.note, .hide, .eye]),
                    ]),
                    ChoiceOption(.cross, "Not my business", "Mouse shrugs. No harm, no favor.", [
                        .set(.mouseErrandDeclined), .bubble(.mouse, [.sad]),
                    ]),
                    ChoiceOption(.badge, "Tell an officer", "Staff trust rises. Mouse — and anyone she talks to — remembers.", [
                        .set(.mouseErrandReported), .trust(4, "Reported contraband"), .peer(.mouse, -20), .peer(.benny, -5),
                        .staff(.haskins, 2), .bubble(.mouse, [.angry]),
                    ]),
                  ]),
    ]
}
