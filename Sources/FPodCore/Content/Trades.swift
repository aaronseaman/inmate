import Foundation

/// Fixed-quote barter. NPCs never give more barter value than they receive
/// (except one-time welcome deals), so no trade cycle can generate profit.
public enum Trades {
    public static let all: [TradeDef] = [
        TradeDef("dutch.welcome", .dutch, give: [(.snack, 1)], get: [(.coffee, 1)], when: .all([.notFlag(.firstTrade), .dayAtLeast(1)]), dailyLimit: 1),
        TradeDef("dutch.coffee", .dutch, give: [(.snack, 2)], get: [(.coffee, 1)], when: .flag(.firstTrade), dailyLimit: 2),
        TradeDef("dutch.tomato", .dutch, give: [(.tomatoes, 1)], get: [(.coffee, 1)], when: .flag(.firstTrade), dailyLimit: 1),
        TradeDef("dutch.cards", .dutch, give: [(.coffee, 1)], get: [(.cards, 1)], when: .flag(.metDutch), dailyLimit: 1),
        TradeDef("benny.snack", .benny, give: [(.cigarettes, 1)], get: [(.snack, 1)], dailyLimit: 3),
        TradeDef("benny.dice", .benny, give: [(.peanutButter, 1)], get: [(.dice, 1)], dailyLimit: 1),
        TradeDef("benny.cigs", .benny, give: [(.snack, 2), (.coffee, 1)], get: [(.cigarettes, 1)], dailyLimit: 2),
        TradeDef("rosa.tomato", .rosa, give: [(.tomatoes, 1)], get: [(.snack, 1)], dailyLimit: 2),
        TradeDef("rosa.cards", .rosa, give: [(.cards, 1)], get: [(.peanutButter, 1)], when: .peer(.rosa, 10), dailyLimit: 1, favor: 0),
        TradeDef("mouse.pb", .mouse, give: [(.peanutButter, 1)], get: [], dailyLimit: 1, favor: 1),
        TradeDef("kenji.drawing", .kenji, give: [(.pencils, 1), (.coffee, 1)], get: [(.drawing, 1)], dailyLimit: 1),
        TradeDef("static.wire", .staticFell, give: [(.copperWire, 1)], get: [(.batteries, 1)], dailyLimit: 1, favor: 1),
        TradeDef("lou.pb", .lou, give: [(.peanutButter, 1)], get: [], dailyLimit: 1, favor: 1),
        TradeDef("harlan.cigs", .harlan, give: [(.coffee, 2)], get: [(.cigarettes, 1)], dailyLimit: 1),
        TradeDef("ada.soap", .ada, give: [(.book, 1)], get: [(.soap, 2), (.workbook, 1)], when: .peer(.ada, 10), dailyLimit: 1),
        TradeDef("moss.hymnal", .moss, give: [(.coffee, 1)], get: [], when: .flag(.hymnalReturned), dailyLimit: 1, favor: 1),
        TradeDef("abe.book", .abe, give: [(.book, 1)], get: [(.coffee, 1)], dailyLimit: 1),
        TradeDef("fitz.earplugs", .fitz, give: [(.earplugs, 1)], get: [], when: .questActive(.m05Cellmate), dailyLimit: 1, favor: 1),
        TradeDef("theo.snack", .theo, give: [(.snack, 1)], get: [], dailyLimit: 1, favor: 0),
        TradeDef("marisol.coffee", .marisol, give: [(.coffee, 1)], get: [], dailyLimit: 1, favor: 1),
    ] + SystemTrades.list

    public static let byID: [String: TradeDef] = {
        var d: [String: TradeDef] = [:]
        for t in all { d[t.id] = t }
        return d
    }()

    public static func forNPC(_ id: NPCID) -> [TradeDef] { all.filter { $0.npc == id } }
}
