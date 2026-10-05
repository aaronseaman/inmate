import Foundation

public struct TradeQuote: Hashable {
    public var tradeID: String
    public var npc: NPCID
    public var give: [ItemStack]
    public var get: [ItemStack]
    public var credits: Int
    public var favor: Int
    public var nonce: Int
}

extension Game {
    // MARK: Capacity

    public var carryCapacity: Int { Inventory.carryCapacity + (s.player.vehicle?.extraBulk ?? 0) }

    func fits(_ inv: Inventory, _ id: ItemID, _ qty: Int, _ slot: Slot) -> Bool {
        let d = Items.def(id)
        if slot == .book && inv.count(.hollowBook) == 0 { return false }
        if d.size > Inventory.slotMaxSize(slot) { return false }
        let stacks = inv.stacks(slot)
        if slot == .carried {
            return inv.carriedBulk + d.size.bulk * qty <= carryCapacity
        }
        if let existing = stacks.first(where: { $0.id == id }) {
            return existing.qty + qty <= Inventory.slotMaxQty(slot)
        }
        return stacks.count < Inventory.slotCount(slot) && qty <= Inventory.slotMaxQty(slot)
    }

    func insert(_ inv: inout Inventory, _ id: ItemID, _ qty: Int, _ slot: Slot, owner: NPCID?) {
        var stacks = inv.stacks(slot)
        if let i = stacks.firstIndex(where: { $0.id == id && $0.owner == owner }) { stacks[i].qty += qty } else {
            stacks.append(ItemStack(id, qty, owner: owner))
        }
        inv.set(slot, stacks)
    }

    /// Adds to inventory. Without `force`, fails rather than silently dropping items.
    @discardableResult
    public func addItem(_ id: ItemID, _ qty: Int = 1, preferred: Slot? = nil, owner: NPCID? = nil, force: Bool = false) -> Bool {
        guard qty > 0 else { return true }
        var order: [Slot] = [.carried, .pocket, .sock, .book]
        if let p = preferred { order.removeAll { $0 == p }; order.insert(p, at: 0) }
        // Small concealables prefer pockets when carrying is tight.
        for slot in order where fits(s.inventory, id, qty, slot) {
            insert(&s.inventory, id, qty, slot, owner: owner)
            emit(.itemGained(id))
            return true
        }
        if force {
            insert(&s.inventory, id, qty, .carried, owner: owner)
            emit(.itemGained(id))
            return true
        }
        return false
    }

    /// Removes `qty` across slots (carried first). No partial removal on failure.
    @discardableResult
    public func removeItem(_ id: ItemID, _ qty: Int = 1) -> Bool {
        guard s.inventory.count(id) >= qty else { return false }
        var left = qty
        for slot in Slot.allCases {
            var stacks = s.inventory.stacks(slot)
            var k = 0
            while k < stacks.count && left > 0 {
                if stacks[k].id == id {
                    let take = min(left, stacks[k].qty)
                    stacks[k].qty -= take
                    left -= take
                    if stacks[k].qty == 0 { stacks.remove(at: k); continue }
                }
                k += 1
            }
            s.inventory.set(slot, stacks)
        }
        // Hollow book gone -> its contents fall into carried.
        if id == .hollowBook && s.inventory.count(.hollowBook) == 0 && !s.inventory.book.isEmpty {
            let spill = s.inventory.book
            s.inventory.book = []
            for st in spill { insert(&s.inventory, st.id, st.qty, .carried, owner: st.owner) }
        }
        emit(.itemLost(id))
        return true
    }

    /// Moves a whole stack between player slots. Atomic.
    @discardableResult
    public func moveStack(from: Slot, index: Int, to: Slot) -> Bool {
        var inv = s.inventory
        var src = inv.stacks(from)
        guard index < src.count, from != to else { return false }
        let st = src.remove(at: index)
        inv.set(from, src)
        guard fits(inv, st.id, st.qty, to) else { return false }
        insert(&inv, st.id, st.qty, to, owner: st.owner)
        s.inventory = inv
        sound(.paper, volume: 0.4)
        return true
    }

    // MARK: Stashes

    public func stashContents(_ objectID: String) -> [ItemStack] { s.stashes[objectID] ?? [] }

    @discardableResult
    public func stashPut(_ objectID: String, from slot: Slot, index: Int) -> Bool {
        guard let def = stashByObject[objectID] else { return false }
        var src = s.inventory.stacks(slot)
        guard index < src.count else { return false }
        let st = src[index]
        if Items.def(st.id).size > def.maxSize { toast(.cross, "Too big for the \(def.title.lowercased())"); return false }
        var contents = s.stashes[objectID] ?? []
        if contents.first(where: { $0.id == st.id && $0.owner == st.owner }) == nil && contents.count >= def.slots {
            toast(.cross, "\(def.title) is full"); return false
        }
        src.remove(at: index)
        s.inventory.set(slot, src)
        if let i = contents.firstIndex(where: { $0.id == st.id && $0.owner == st.owner }) { contents[i].qty += st.qty } else { contents.append(st) }
        s.stashes[objectID] = contents
        sound(.drop, volume: 0.5)
        if st.id == .hollowBook && s.inventory.count(.hollowBook) == 0 && !s.inventory.book.isEmpty {
            let spill = s.inventory.book
            s.inventory.book = []
            for b in spill { insert(&s.inventory, b.id, b.qty, .carried, owner: b.owner) }
        }
        saveRequested = true
        return true
    }

    /// Takes a stash item into inventory. Taking someone else's property is theft.
    @discardableResult
    public func stashTake(_ objectID: String, index: Int) -> Bool {
        var contents = s.stashes[objectID] ?? []
        guard index < contents.count else { return false }
        let st = contents[index]
        guard addItem(st.id, st.qty, owner: st.owner) else { toast(.bag, "No room to carry that"); return false }
        contents.remove(at: index)
        s.stashes[objectID] = contents.isEmpty ? nil : contents
        sound(.pickup, volume: 0.5)
        if let owner = st.owner {
            stat("thefts")
            witnessCheck(.theft, item: st.id)
            adjustPeer(owner, -8, silent: true)
            log("Took \(Items.def(st.id).name) belonging to \(Cast.def(owner).short)")
        }
        saveRequested = true
        return true
    }

    // MARK: Credits & ledger

    @discardableResult
    func creditDelta(_ delta: Int, _ reason: String) -> Bool {
        if s.credits + delta < 0 { return false }
        s.credits += delta
        s.ledgerCounter += 1
        s.ledger.append(LedgerEntry(id: s.ledgerCounter, day: s.day, minute: Int(s.minute), delta: delta, balance: s.credits, reason: reason))
        if s.ledger.count > 400 { s.ledger.removeFirst(s.ledger.count - 400) }
        if delta != 0 { sound(.coin, volume: 0.6) }
        return true
    }

    /// Applies a reward exactly once per key.
    @discardableResult
    func claimReward(_ key: String, _ r: RewardSpec, reason: String) -> Bool {
        guard !s.claimedRewards.contains(key) else { return false }
        // Validate first (atomic): item space.
        var inv = s.inventory
        for (id, q) in r.items {
            var placed = false
            for slot in Slot.allCases where fits(inv, id, q, slot) { insert(&inv, id, q, slot, owner: nil); placed = true; break }
            if !placed { insert(&inv, id, q, .carried, owner: nil) }
        }
        s.claimedRewards.insert(key)
        s.inventory = inv
        for (id, _) in r.items { emit(.itemGained(id)) }
        if r.credits != 0 { creditDelta(r.credits, reason) }
        if r.trust != 0 { adjustTrust(r.trust, reason) }
        saveRequested = true
        return true
    }

    // MARK: Trades

    public func quote(_ t: TradeDef) -> TradeQuote {
        let rep = s.peerRep[t.npc] ?? 0
        var give = t.give.map { ItemStack($0.0, $0.1) }
        var credits = t.credits
        // Bounded relationship adjustment: at most one unit either way.
        if !give.isEmpty {
            if rep >= 40 && give[0].qty >= 2 { give[0].qty -= 1 } else if rep <= -25 { give[0].qty += 1 }
        } else if credits > 0 {
            if rep >= 40 { credits = max(1, credits - 1) } else if rep <= -25 { credits += 1 }
        }
        ui.quoteNonce += 1
        return TradeQuote(tradeID: t.id, npc: t.npc, give: give, get: t.get.map { ItemStack($0.0, $0.1) }, credits: credits, favor: t.favor, nonce: ui.quoteNonce)
    }

    public func tradeAvailable(_ t: TradeDef) -> (Bool, String?) {
        if (s.tradesToday[t.id] ?? 0) >= t.dailyLimit { return (false, "Done for today") }
        if !eval(t.when) { return (false, "Not now") }
        return (true, nil)
    }

    /// Executes exactly the quoted exchange, atomically.
    @discardableResult
    public func confirmTrade(_ q: TradeQuote) -> Bool {
        guard let t = Trades.byID[q.tradeID] else { return false }
        let (ok, why) = tradeAvailable(t)
        guard ok else { toast(.cross, why ?? "Unavailable"); return false }
        for g in q.give where s.inventory.count(g.id) < g.qty { toast(.cross, "You need \(g.qty)× \(Items.def(g.id).name)"); return false }
        if q.credits > 0 && s.credits < q.credits { toast(.coin, "Not enough credits"); return false }
        // Simulate on a copy for capacity.
        let saved = s.inventory
        for g in q.give { _ = removeItem(g.id, g.qty) }
        for r in q.get {
            if !addItem(r.id, r.qty) {
                s.inventory = saved
                toast(.bag, "No room — free a slot first")
                return false
            }
        }
        if q.credits != 0 { creditDelta(-q.credits, "Trade with \(Cast.def(q.npc).short)") }
        s.tradesToday[t.id, default: 0] += 1
        if q.favor != 0 { s.favors[q.npc, default: 0] += q.favor }
        adjustPeer(q.npc, 2, silent: true)
        emit(.traded(t.id))
        if !has(.firstTrade) { setFlag(.firstTrade) }
        sound(.confirm)
        toast(.swap, "Traded with \(Cast.def(q.npc).short)")
        stat("trades")
        saveRequested = true
        return true
    }

    // MARK: Commissary

    public static let commissaryDailyLimit = 20
    /// Items at or above this price are special orders: one per day, outside the daily cap.
    public static let specialOrderPrice = 15

    public var commissaryOpen: Bool {
        [.afternoon, .freeTime].contains(activity) || (Schedule.isWeekend(s.day) && activity == .visiting)
    }

    public var commissaryEligible: (Bool, String?) {
        if let until = s.restrictions[.noCommissary], until > s.absMinute { return (false, "Commissary restricted") }
        if s.watch >= .yellow { return (false, "Restricted during watch") }
        if trustTier < 2 && !has(.commissaryUnlocked) { return (false, "Needs trust tier 2") }
        return (true, nil)
    }

    public static var commissaryCatalog: [ItemID] {
        Items.list.filter { $0.price != nil && $0.price! > 0 }.map { $0.id }
    }

    @discardableResult
    public func buy(_ id: ItemID) -> Bool {
        guard let price = Items.def(id).price, price > 0 else { return false }
        let (ok, why) = commissaryEligible
        guard ok else { toast(.lock, why ?? "Unavailable"); return false }
        guard commissaryOpen else { toast(.clock, "Window opens afternoons & free time"); return false }
        let special = price >= Game.specialOrderPrice
        if special {
            guard s.bigOrderDay != s.day else { toast(.coin, "One special order per day"); return false }
        } else {
            guard s.purchasesToday + price <= Game.commissaryDailyLimit else { toast(.coin, "Daily limit (\(Game.commissaryDailyLimit) cr) reached"); return false }
        }
        guard s.credits >= price else { toast(.coin, "Not enough credits"); return false }
        guard addItem(id) else { toast(.bag, "No room to carry it"); return false }
        creditDelta(-price, "Commissary: \(Items.def(id).name)")
        if special { s.bigOrderDay = s.day } else { s.purchasesToday += price }
        stat("purchases")
        if id == .radio { setFlag(.radioBought) }
        saveRequested = true
        return true
    }

    // MARK: Searches

    /// Person search. Level 1 = pat-down (carried, pocket); 2 adds sock and hollow book.
    func searchPerson(level: Int) -> [ItemStack] {
        var found: [ItemStack] = []
        var slots: [Slot] = [.carried, .pocket]
        if level >= 2 { slots.append(.sock) }
        if level >= 2 && s.inventory.count(.hollowBook) > 0 && s.rng.chance(0.5) { slots.append(.book) }
        for slot in slots {
            var keep: [ItemStack] = []
            for st in s.inventory.stacks(slot) {
                if !Items.isPermitted(st.id, job: s.player.job) || (st.owner != nil) {
                    found.append(st)
                } else { keep.append(st) }
            }
            s.inventory.set(slot, keep)
        }
        if s.inventory.count(.hollowBook) == 0 && !s.inventory.book.isEmpty {
            let spill = s.inventory.book
            s.inventory.book = []
            for b in spill { found.append(b) }
        }
        return found
    }

    /// Cell search: the locker is always opened; other stashes are checked individually.
    func searchCell(_ cell: Int, thorough: Bool) -> (searched: [String], found: [ItemStack]) {
        var searched: [String] = []
        var found: [ItemStack] = []
        let prefix = "fpod.cell\(cell)."
        let defs = Stashes.all.filter { $0.objectID.hasPrefix(prefix) }
        let residents = Set(Cast.peers.filter { $0.cell == cell }.map { $0.id })
        for d in defs {
            let check: Bool
            if d.legal { check = true } else { check = s.rng.chance(thorough ? min(0.95, d.discovery * 1.4) : d.discovery) }
            guard check else { continue }
            searched.append(d.objectID)
            var keep: [ItemStack] = []
            for st in s.stashes[d.objectID] ?? [] {
                let stolen = st.owner.map { !residents.contains($0) } ?? false
                let residentsOwn = st.owner.map { residents.contains($0) } ?? false
                if stolen || (!residentsOwn && !Items.isPermitted(st.id, job: s.player.job)) { found.append(st) } else { keep.append(st) }
            }
            s.stashes[d.objectID] = keep.isEmpty ? nil : keep
        }
        return (searched, found)
    }

    func confiscate(_ stacks: [ItemStack]) {
        for st in stacks {
            if let owner = st.owner, owner != .haskins {
                // Stolen property goes back to its owner.
                let lockerID = Cast.def(owner).cell.map { "fpod.cell\($0).locker" }
                if let l = lockerID { s.stashes[l, default: []].append(st) }
                continue
            }
            s.confiscated.append(st)
            emit(.itemLost(st.id))
        }
        saveRequested = true
    }

    /// Legal confiscated items can be claimed back through Ms. Pruitt.
    public var claimableProperty: [ItemStack] {
        s.confiscated.filter { Items.def($0.id).legality <= .restricted }
    }

    @discardableResult
    func claimProperty() -> Int {
        let claim = claimableProperty
        var n = 0
        for st in claim {
            if addItem(st.id, st.qty, force: true) {
                if let i = s.confiscated.firstIndex(of: st) { s.confiscated.remove(at: i) }
                n += 1
            }
        }
        return n
    }
}
