import Foundation

/// Static checks over authored content: every item needs a way in and a reason to exist.
public enum ContentAudit {
    public struct Coverage { public var sources: [String] = []; public var uses: [String] = [] }

    /// Sources and uses that live in code rather than in content tables.
    static let codePaths: [ItemID: (source: String?, use: String?)] = [
        .soap: (nil, "wash up (+condition)"), .brokenRadio: ("donation box (new game)", nil), .janitorKey: ("janitorial job", "closet door"),
        .recordsKey: (nil, "records room door"), .screwdriver: (nil, "cell vent stash"), .deliveryBox: (nil, "PPE/laundry prop"),
        .visitorBadge: (nil, "visitor prop"), .courtDocket: ("Calloway's visit", nil), .supportLetter: ("Nadia's visit", nil),
        .tanScrubs: ("worn at intake", nil), .mop: (nil, "maintenance prop"), .clipboard: (nil, "white-coat prop"), .tray: (nil, "kitchen prop"),
        .laundryBag: (nil, "laundry prop"), .hymnal: (nil, "chaplain prop"), .hollowBook: (nil, "concealed book slot"),
        .batteries: (nil, "radio upkeep"), .snack: (nil, "eat (+energy)"), .coffee: (nil, "drink (+energy)"),
    ]

    public static func itemCoverage() -> [ItemID: Coverage] {
        var cov: [ItemID: Coverage] = [:]
        func scanEffects(_ es: [Effect], _ tag: String) {
            for e in es {
                switch e {
                case .give(let i, _), .putInStash(_, let i, _): cov[i, default: Coverage()].sources.append(tag)
                case .take(let i, _), .returnOwned(let i, _): cov[i, default: Coverage()].uses.append(tag)
                case .minigame(_, _, _, let a, let b): scanEffects(a, tag); scanEffects(b, tag)
                case .ifThen(let c, let a, let b): scanCond(c, tag); scanEffects(a, tag); scanEffects(b, tag)
                default: break
                }
            }
        }
        func scanCond(_ c: Cond, _ tag: String) {
            switch c {
            case .has(let i, _), .hasOwned(let i, _): cov[i, default: Coverage()].uses.append(tag)
            case .hasAny(let ids): for i in ids { cov[i, default: Coverage()].uses.append(tag) }
            case .all(let cs), .any(let cs): for x in cs { scanCond(x, tag) }
            case .not(let x): scanCond(x, tag)
            default: break
            }
        }
        for i in Interactions.all { scanEffects(i.effects, "i:" + i.id); scanCond(i.when, "i:" + i.id) }
        for c in Choices.all { for o in c.options { scanEffects(o.effects, "c:\(c.id)"); scanCond(o.when, "c:\(c.id)") } }
        for q in Quests.all {
            scanCond(q.prerequisite, "q:\(q.id)")
            for st in q.stages { if let w = st.completeWhen { scanCond(w, "q:\(q.id)") }; scanEffects(st.onComplete, "q:\(q.id)") }
        }
        for t in Trades.all {
            for (i, _) in t.give { cov[i, default: Coverage()].uses.append("t:" + t.id) }
            for (i, _) in t.get { cov[i, default: Coverage()].sources.append("t:" + t.id) }
        }
        for (c, items) in SupplyStashes.stock { for (i, _) in items { cov[i, default: Coverage()].sources.append("s:" + c) } }
        for d in Items.list where (d.price ?? 0) > 0 { cov[d.id, default: Coverage()].sources.append("commissary") }
        for j in JobID.allCases { if let u = Jobs.def(j).uniform { cov[u.item, default: Coverage()].sources.append("job:\(j)") } }
        for o in Outfit.allCases { cov[o.item, default: Coverage()].uses.append("wear") }
        for (i, p) in codePaths {
            if let s = p.source { cov[i, default: Coverage()].sources.append("code:" + s) }
            if let u = p.use { cov[i, default: Coverage()].uses.append("code:" + u) }
        }
        return cov
    }
}
