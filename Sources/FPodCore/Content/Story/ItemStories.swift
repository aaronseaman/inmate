import Foundation

// Every item earns its place: where it comes from, what it's for, what it costs.
// Contraband and dangerous items are abstract tokens in authored moments — no how-to.

enum ItemStories {
    static let interactions: [InteractionDef] = [
        // Theo's hoard (abstract pill tokens): a safety story, not a heist.
        InteractionDef("item.theo.tokens", .npc(.theo), .heart, "Ask Theo what's in the sock", when: .all([.dayAtLeast(4), .peer(.theo, 6), .dailyOnce("theo.tokens")]),
                       once: true, reply: [.quiet, .sad, .token], priority: 4, [
                        .give(.pillToken, 1), .peer(.theo, 2),
                        .caption("Theo: I save the evening ones. In case. …You can hold them. Just don't make it a thing."),
                       ]),
        InteractionDef("item.tokens.okonjo", .npc(.okonjo), .stethoscope, "Hand Theo's tokens to Nurse Okonjo", when: .has(.pillToken), reply: [.heart, .stethoscope, .check],
                       priority: 9, [
                        .take(.pillToken, 1), .trust(4, "Safety"), .staff(.okonjo, 4), .peer(.ada, 5),
                        .caption("Okonjo: Thank you. I'll sit with Theo tonight — not a write-up. A conversation."),
                       ]),
        InteractionDef("item.tokens.back", .npc(.theo), .token, "Give the tokens back", when: .has(.pillToken), risky: true, reply: [.token, .quiet], priority: 3, [
            .take(.pillToken, 1), .peer(.theo, 3), .peer(.ada, -5),
        ]),
        // Harlan's batch.
        InteractionDef("item.harlan.hooch", .npc(.harlan), .bottle, "Harlan wants something held", when: .all([.dayAtLeast(4), .notFlag(.hoochDumped), .dailyOnce("harlan.hooch")]),
                       once: true, reply: [.bottle, .quiet, .angry], priority: 4, [.choice(.hoochDecision)]),
        InteractionDef("item.hooch.dump", .kind(.sink), .water, "Pour out the hooch", when: .has(.hooch), priority: 8, [
            .take(.hooch, 1), .set(.hoochDumped), .peer(.harlan, -6), .sound(.splash),
        ]),
        InteractionDef("item.hooch.return", .npc(.harlan), .bottle, "Give Harlan his batch back", when: .has(.hooch), reply: [.bottle, .thumbsUp], priority: 8, [
            .take(.hooch, 1), .peer(.harlan, 5),
        ]),
        // Benny's phone and Static's charger.
        InteractionDef("item.benny.phone", .npc(.benny), .phone, "Buy Benny's spare phone", when: .all([.has(.cigarettes, 3), .not(.has(.phone)), .peer(.benny, 5)]), risky: true,
                       witnessed: .contraband, reply: [.phone, .coin, .quiet], priority: 4, [
                        .take(.cigarettes, 3), .give(.phone, 1), .caption("Benny: Battery's dead. Static has a charger, if you ask nice."),
                       ]),
        InteractionDef("item.static.charger", .npc(.staticFell), .charger, "Ask for a charger", when: .all([.has(.phone), .not(.has(.charger)), .has(.copperWire)]),
                       reply: [.charger, .wire], priority: 5, [.take(.copperWire, 1), .give(.charger, 1), .caption("Static: Copper in, electrons out. Don't call anyone I know.")]),
        InteractionDef("item.phone.call", .kind(.bunk), .phone, "Call Calloway on the contraband phone", when: .all([.has(.phone), .has(.charger), .inOwnCell, .unobserved]),
                       risky: true, witnessed: .contraband, priority: 3, [.set(.usedContrabandPhone), .call(.calloway)]),
        // Kenji's tattoo device.
        InteractionDef("item.kenji.device", .npc(.kenji), .needle, "Kenji needs a hiding place", when: .all([.dayAtLeast(5), .peer(.kenji, 5), .not(.has(.tattooDevice))]),
                       risky: true, once: true, reply: [.needle, .search, .quiet], priority: 4, [
                        .give(.tattooDevice, 1), .peer(.kenji, 4), .caption("Kenji: Searches tomorrow. Keep it two days. It's all I have from outside."),
                       ]),
        InteractionDef("item.kenji.return", .npc(.kenji), .needle, "Give Kenji his device back", when: .has(.tattooDevice), reply: [.needle, .heart], priority: 7, [
            .take(.tattooDevice, 1), .peer(.kenji, 8), .favor(.kenji, 1), .caption("Kenji: You kept it. I keep promises too."),
        ]),
        InteractionDef("item.device.turnin", .npc(.haskins), .needle, "Turn in a tattoo device", when: .has(.tattooDevice), reply: [.needle, .form], priority: 2, [
            .take(.tattooDevice, 1), .trust(3, "Turned in contraband"), .peer(.kenji, -15),
        ]),
        // The shard: an authored threat, a real choice, no instructions.
        InteractionDef("item.lou.shard", .npc(.lou), .shard, "Lou has something for you", when: .all([.flag(.harlanRadioAngry), .notFlag(.harlanDebtSettled), .dayAtLeast(7)]),
                       once: true, reply: [.shard, .quiet, .eye], priority: 6, [.choice(.weaponDecision)]),
        InteractionDef("item.shard.surrender", .npc(.gaines), .badge, "Surrender the shard to Lt. Gaines", when: .has(.weaponToken), reply: [.badge, .form, .check], priority: 9, [
            .take(.weaponToken, 1), .set(.weaponSurrendered), .trust(6, "Surrendered a weapon"), .set(.harlanDebtSettled),
            .caption("Gaines: Where'd it come from? …Never mind. Harlan's going on a watch. Thank you."),
        ]),
        InteractionDef("item.shard.dump", .object("yard.dumpster"), .shard, "Throw the shard away", when: .has(.weaponToken), priority: 8, [.take(.weaponToken, 1)]),
        // A hollow book (one concealed slot) — Mouse's craft.
        InteractionDef("item.mouse.hollow", .npc(.mouse), .book, "Ask Mouse to hollow out a paperback", when: .all([.has(.book), .favor(.mouse, 1), .not(.has(.hollowBook))]),
                       reply: [.book, .hide], priority: 3, [.favor(.mouse, -1), .take(.book, 1), .give(.hollowBook, 1)]),
        // Library loans and returns.
        InteractionDef("item.chess.borrow", .npc(.abernathy), .chess, "Borrow the pocket chess set", when: .all([.flag(.libraryCardIssued), .not(.has(.chessSet))]), reply: [.chess, .clock],
                       priority: 2, [.give(.chessSet, 1)]),
        InteractionDef("item.chess.theo", .npc(.theo), .chess, "Give Theo the chess set", when: .all([.has(.chessSet), .flag(.theoAccused)]), reply: [.chess, .happy], priority: 7, [
            .take(.chessSet, 1), .peer(.theo, 10), .caption("Theo: They took mine. This one's tiny. I love it."),
        ]),
        // Paper trails.
        InteractionDef("item.statement.file", .npc(.pruitt), .form, "File your witness statement", when: .has(.witnessStatement), reply: [.form, .stamp], priority: 8, [
            .take(.witnessStatement, 1), .staff(.pruitt, 1), .doc(.witnessTheo),
        ]),
        InteractionDef("item.support.letter", .npc(.sato), .letter, "Add Nadia's support letter to your file", when: .has(.supportLetter), reply: [.letter, .check], priority: 6, [
            .take(.supportLetter, 1), .staff(.sato, 2), .trust(2, "Family support on file"),
        ]),
    ]

    static let choices: [ChoiceDef] = [
        ChoiceDef(id: .hoochDecision, title: "Harlan's batch", icon: .bottle,
                  prompt: "Harlan shoves a lumpy bag at you. \"Hold this till Friday. Nobody searches the new kid.\"", speaker: .harlan, options: [
                    ChoiceOption(.hand, "Hold it", "Harlan owes you. If it's found, it's yours.", risky: true, [.give(.hooch, 1), .peer(.harlan, 4)]),
                    ChoiceOption(.cross, "Refuse", "Harlan sulks. It's only Tuesday.", [.peer(.harlan, -3)]),
                    ChoiceOption(.badge, "Tell CO Haskins", "Trust rises. Harlan learns your name.", [.set(.hoochDumped), .trust(3, "Reported hooch"), .peer(.harlan, -12), .staff(.haskins, 2)]),
                  ]),
        ChoiceDef(id: .weaponDecision, title: "Lou's offer", icon: .shard,
                  prompt: "Lou presses something wrapped in tape into your hand. \"Harlan's carrying. Now you are.\"", speaker: .lou, options: [
                    ChoiceOption(.cross, "Hand it back", "Lou nods slowly. \"Then stay near me.\"", [.peer(.lou, 3), .set(.louProtection)]),
                    ChoiceOption(.hand, "Keep it", "If it's found on you: a severe incident.", risky: true, [.give(.weaponToken, 1), .peer(.lou, 2)]),
                  ]),
    ]

    static let trades: [TradeDef] = [
        TradeDef("marisol.lawbook", .marisol, give: [(.lawBook, 1)], get: [], dailyLimit: 1, favor: 2),
        TradeDef("fitz.dice", .fitz, give: [(.dice, 1)], get: [], dailyLimit: 1, favor: 1),
        TradeDef("benny.hooch", .benny, give: [(.hooch, 1)], get: [(.cigarettes, 2)], dailyLimit: 1),
    ]

    static let stock: [String: [(ItemID, Int)]] = [
        "clerk.desk": [(.recordsKey, 1)],
        "visit.desk": [(.visitorBadge, 1)],
    ]

    static let stashes: [StashDef] = [
        StashDef(objectID: "clerk.desk", title: "Desk drawer", slots: 2, maxSize: .small, discovery: 0.6, legal: false, needs: nil),
        StashDef(objectID: "visit.desk", title: "Visiting desk drawer", slots: 2, maxSize: .small, discovery: 0.6, legal: false, needs: nil),
    ]
}
