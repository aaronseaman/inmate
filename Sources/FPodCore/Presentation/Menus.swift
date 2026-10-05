import Foundation

extension Game {
    var isFullScreenModal: Bool {
        guard let m = ui.modal else { return false }
        if case .fan = m { return false }
        return true
    }

    /// Centered paper sheet with title and close button; returns the content rect.
    func sheet(_ ui0: inout UIBuilder, id: String, title: String, icon: Icon, width: Double = 640, height: Double? = nil, tone: CardTone = .neutral) -> Rect {
        let safe = viewport.safeRect
        ui0.panel("\(id).scrim", Rect(0, 0, viewport.size.x, viewport.size.y), .scrim)
        ui0.hit(Rect(0, 0, viewport.size.x, viewport.size.y), .closeModal)
        let w = min(width, safe.w - 24)
        let h = min(height ?? (safe.h - 20), safe.h - 16)
        let r = Rect(safe.midX - w / 2, safe.midY - h / 2, w, h)
        ui0.panel("\(id).card", r, .sheet)
        ui0.hit(r, .none)
        let badgeBG: RGBA = tone == .danger ? Palette.coral : (tone == .warm ? Palette.ochre : Palette.navy)
        ui0.badge("\(id).ic", icon, center: Vec2(r.x + 30, r.y + 30), size: 32, bg: badgeBG, fg: Palette.paper)
        ui0.text("\(id).title", title, Vec2(r.x + 54, r.y + 18), size: 17, weight: .bold, width: w - 120)
        ui0.button("\(id).close", Rect(r.maxX - 50, r.y + 8, 42, 42), icon: .close, style: .round, action: .closeModal, ax: "Close")
        return Rect(r.x + 16, r.y + 56, w - 32, h - 68)
    }

    func buildModal(_ m: Modal, _ ui0: inout UIBuilder) {
        switch m {
        case .fan(let t, let opts): buildFan(t, opts, &ui0)
        case .inventory: buildInventory(&ui0)
        case .stash(let id): buildStash(id, &ui0)
        case .trade(let q): buildTrade(q, &ui0)
        case .tradeList(let npc): buildTradeList(npc, &ui0)
        case .commissary: buildCommissary(&ui0)
        case .choice(let c): buildChoice(c, &ui0)
        case .doc(let d): buildDoc(d, &ui0)
        case .journal(let tab): buildJournal(tab, &ui0)
        case .map: buildMap(&ui0)
        case .settings: buildSettings(&ui0)
        case .menu: buildMenu(&ui0)
        case .help: buildHelp(&ui0)
        case .outfit: buildOutfit(&ui0)
        case .phone: buildPhone(&ui0)
        case .dev: buildDev(&ui0)
        case .ending(let e): buildEnding(e, &ui0)
        }
    }

    // MARK: Fan

    func buildFan(_ t: TargetRef, _ opts: [InteractOption], _ ui0: inout UIBuilder) {
        ui0.hit(Rect(0, 0, viewport.size.x, viewport.size.y), .closeModal)
        guard let wp = targetPosition(t) else { return }
        let anchor = worldToScreen(wp)
        let safe = viewport.safeRect
        let bs = 54.0
        // One clean row of options with labels underneath; never overlapping.
        let labels = opts.map { o -> String in o.enabled ? o.caption : (o.note ?? o.caption) }
        // Long labels wrap to two lines rather than widening the slot past 112 pt.
        let labelMax = 112.0
        let slotW = opts.indices.map { k -> Double in settings.iconLabels ? max(bs + 10, min(labelMax, TextMetrics.width(labels[k], size: 10.5, weight: .semibold) + 16)) : bs + 10 }
        let labelLines = opts.indices.map { k -> [String] in
            settings.iconLabels ? Array(TextMetrics.wrap(labels[k], size: 10.5, weight: .semibold, width: slotW[k] - 16).prefix(2)) : []
        }
        let twoLine = labelLines.contains { $0.count > 1 }
        let total = slotW.reduce(0, +)
        let rowH = bs + (settings.iconLabels ? (twoLine ? 38 : 24) : 4)
        let titleH = 30.0
        let blockH = titleH + rowH
        var top = anchor.y - settings.zoom * 1.6 - blockH
        // Stay clear of the top-right buttons (their bottom edge is ≈ safe.y + 52).
        if top < safe.y + 58 { top = anchor.y + settings.zoom * 0.7 }
        top = clamp(top, safe.y + 58, safe.maxY - blockH - 8)
        var x0 = anchor.x - total / 2
        x0 = clamp(x0, safe.x + 6, safe.maxX - total - 6)
        let (icon, title) = contextLabel(t)
        let tw = TextMetrics.width(title, size: 12, weight: .semibold) + 40
        let tr = Rect(clamp(anchor.x - tw / 2, safe.x + 4, safe.maxX - tw - 4), top, tw, 26)
        ui0.panel("fan.title", tr, .chip)
        ui0.icon("fan.title.ic", icon, center: Vec2(tr.x + 15, tr.midY), size: 15, color: Palette.slate)
        ui0.text("fan.title.t", title, Vec2(tr.x + 28, tr.y + 5), size: 12, weight: .semibold, width: tw - 32)
        var x = x0
        for (k, o) in opts.enumerated() {
            let cx = x + slotW[k] / 2
            let r = Rect(cx - bs / 2, top + titleH, bs, bs)
            let style: ButtonStyle = o.risky ? .danger : .round
            ui0.button("fan.\(k)", r, icon: o.icon, style: style, action: .fanOption(o.id), ax: o.caption + (o.note.map { ". \($0)" } ?? ""),
                       hint: o.risky ? "Risky" : nil, enabled: o.enabled, iconColor: o.risky ? Palette.paper : nil)
            if settings.iconLabels {
                let lw = slotW[k] - 6
                let lines = labelLines[k].count
                let lr = Rect(cx - lw / 2, r.maxY + 3, lw, lines > 1 ? 32 : 18)
                ui0.panel("fan.\(k).lbg", lr, .chip, alpha: 0.95)
                ui0.text("fan.\(k).lb", labels[k], Vec2(cx, lr.y + 2.5), size: 10.5, weight: .semibold, color: o.enabled ? Palette.ink : Palette.inkSoft,
                         align: .center, width: lw - 10, maxLines: 2)
            }
            x += slotW[k]
        }
    }

    // MARK: Inventory

    func itemTile(_ ui0: inout UIBuilder, id: String, _ r: Rect, _ st: ItemStack?, selected: Bool, action: UIAction, ax: String) {
        ui0.button(id, r, style: selected ? .tileSelected : .tile, action: action, ax: ax)
        guard let st = st else {
            ui0.shape("\(id).empty", ShapeSpec(.rect, w: r.w - 12, h: r.h - 12, radius: 8, stroke: Palette.blueGray, lineWidth: 1.5), at: Vec2(r.x + 6, r.y + 6))
            return
        }
        let d = Items.def(st.id)
        let col = selected ? Palette.paper : (d.tint ?? Palette.ink)
        ui0.icon("\(id).ic", d.icon, center: Vec2(r.midX, r.midY - 2), size: r.w * 0.52, color: col)
        if st.qty > 1 { ui0.text("\(id).q", "×\(st.qty)", Vec2(r.maxX - 4, r.maxY - 16), size: 10.5, weight: .bold, color: selected ? Palette.paper : Palette.ink, align: .right, width: 30) }
        if d.legality >= .restricted && !Items.isPermitted(st.id, job: s.player.job) {
            let glyph: Icon = d.legality == .dangerous ? .shard : (d.legality == .contraband ? .exclaim : .lock)
            ui0.badge("\(id).leg", glyph, center: Vec2(r.x + 11, r.y + 11), size: 16, bg: d.legality == .restricted ? Palette.ochre : Palette.coral, fg: Palette.paper)
        }
        if st.owner != nil { ui0.badge("\(id).own", .person, center: Vec2(r.maxX - 11, r.y + 11), size: 16, bg: Palette.slate, fg: Palette.paper) }
    }

    func buildInventory(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "inv", title: "Inventory", icon: .bag, width: 700)
        let tile = 54.0, gap = 8.0
        var y = c.y
        let leftW = c.w * 0.56
        for slot in Slot.allCases {
            if slot == .book && s.inventory.count(.hollowBook) == 0 { continue }
            let stacks = s.inventory.stacks(slot)
            var header = slot.title
            if slot == .carried { header += " · bulk \(s.inventory.carriedBulk)/\(carryCapacity)" } else { header += " · \(stacks.count)/\(Inventory.slotCount(slot)) · max \(Inventory.slotMaxSize(slot).title.lowercased())" }
            ui0.icon("inv.h.\(slot.rawValue).ic", slot.icon, center: Vec2(c.x + 8, y + 8), size: 15, color: Palette.slate)
            ui0.text("inv.h.\(slot.rawValue)", header, Vec2(c.x + 22, y), size: 12, weight: .semibold, color: Palette.inkSoft, width: leftW - 24)
            y += 20
            let count = slot == .carried ? max(stacks.count, 1) : Inventory.slotCount(slot)
            let perRow = Int((leftW + gap) / (tile + gap))
            for k in 0..<count {
                let r = Rect(c.x + Double(k % perRow) * (tile + gap), y + Double(k / perRow) * (tile + gap), tile, tile)
                let st = k < stacks.count ? stacks[k] : nil
                let sel = ui.inventorySelection.map { $0.0 == slot && $0.1 == k } ?? false
                let ax = st.map { "\(Items.def($0.id).name), \($0.qty), \(Items.def($0.id).legality.title)" } ?? "Empty \(slot.title) slot"
                itemTile(&ui0, id: "inv.\(slot.rawValue).\(k)", r, st, selected: sel, action: st != nil ? .invSelect(slot, k) : .none, ax: ax)
            }
            y += Double((count + perRow - 1) / perRow) * (tile + gap) + 6
        }
        // Details
        let dx = c.x + leftW + 16, dw = c.w - leftW - 16
        ui0.panel("inv.detail", Rect(dx - 8, c.y - 4, dw + 8, c.h + 4), .inset)
        guard let (slot, idx) = ui.inventorySelection, idx < s.inventory.stacks(slot).count else {
            ui0.text("inv.hint", "Tap an item to see what it's for, move it between hiding places, or use it.", Vec2(dx, c.y + 10), size: 13, color: Palette.inkSoft, width: dw - 10, maxLines: 4)
            ui0.text("inv.wear", "Wearing: \(s.player.outfit.title)\(s.player.outfit == .tanScrubs ? "" : " (\(Int(s.player.outfitCondition))%)")", Vec2(dx, c.maxY - 24), size: 12, weight: .semibold, width: dw - 10)
            return
        }
        let st = s.inventory.stacks(slot)[idx]
        let d = Items.def(st.id)
        ui0.icon("inv.d.ic", d.icon, center: Vec2(dx + 26, c.y + 26), size: 44, color: d.tint ?? Palette.ink)
        ui0.text("inv.d.name", d.name + (st.qty > 1 ? " ×\(st.qty)" : ""), Vec2(dx + 56, c.y + 8), size: 15, weight: .bold, width: dw - 60)
        let legal = Items.isPermitted(st.id, job: s.player.job) ? "Allowed for you" : d.legality.title
        ui0.text("inv.d.meta", "\(d.size.title) · \(legal)\(st.owner.map { " · belongs to \(Cast.def($0).short)" } ?? "")", Vec2(dx + 56, c.y + 30), size: 11.5, color: d.legality >= .contraband ? Palette.coral.darker(0.2) : Palette.inkSoft, width: dw - 60)
        var yy = c.y + 60
        yy += ui0.text("inv.d.purpose", d.purpose, Vec2(dx, yy), size: 12.5, width: dw - 10, maxLines: 4) + 8
        var actions: [(String, Icon, UIAction, Bool)] = []
        for target in Slot.allCases where target != slot {
            if target == .book && s.inventory.count(.hollowBook) == 0 { continue }
            var inv = s.inventory
            var src = inv.stacks(slot); src.remove(at: idx); inv.set(slot, src)
            let ok = fits(inv, st.id, st.qty, target)
            let short: String
            switch target {
            case .carried: short = "Carry"
            case .pocket: short = "Pocket"
            case .sock: short = "Sock"
            case .book: short = "In book"
            }
            actions.append((short, target.icon, .invMove(target), ok))
        }
        if [.snack, .coffee, .peanutButter, .tomatoes].contains(st.id) { actions.append(("Eat / drink", .cup, .invUse, true)) }
        if Outfit.from(item: st.id) != nil { actions.append(("Wear", .change, .invUse, privateForChanging())) }
        if [.chartCopy, .courtDocket, .transportLog, .letter, .lawyerCard, .supportLetter, .witnessStatement].contains(st.id) { actions.append(("Read", .eye, .invUse, true)) }
        let bw = (dw - 18) / 2
        for (k, a) in actions.enumerated() {
            let r = Rect(dx + Double(k % 2) * (bw + 8), yy + Double(k / 2) * 50, bw, 44)
            ui0.button("inv.a.\(k)", r, icon: a.1, label: a.0, style: .pill, action: a.2, ax: a.0, enabled: a.3, labelSize: 12)
        }
    }

    // MARK: Stash

    func buildStash(_ id: String, _ ui0: inout UIBuilder) {
        let def = stashByObject[id]
        let title = def?.title ?? "Storage"
        let c = sheet(&ui0, id: "stash", title: title, icon: .stash, width: 700)
        let half = (c.w - 20) / 2
        let contents = stashContents(id)
        ui0.text("stash.l", "Yours — tap to put away", Vec2(c.x, c.y), size: 12, weight: .semibold, color: Palette.inkSoft, width: half)
        ui0.text("stash.r", "\(title) · \(contents.count)/\(def?.slots ?? 0) · \(def.map { "max \($0.maxSize.title.lowercased())" } ?? "") — tap to take",
                 Vec2(c.x + half + 20, c.y), size: 12, weight: .semibold, color: Palette.inkSoft, width: half)
        let tile = 54.0, gap = 8.0, perRow = Int((half + gap) / (tile + gap))
        let mine = s.inventory.all
        for (k, pair) in mine.enumerated() {
            let r = Rect(c.x + Double(k % perRow) * (tile + gap), c.y + 22 + Double(k / perRow) * (tile + gap), tile, tile)
            let idx = s.inventory.stacks(pair.0).firstIndex(of: pair.1) ?? 0
            itemTile(&ui0, id: "stash.mine.\(k)", r, pair.1, selected: false, action: .stashPut(pair.0, idx), ax: "Put \(Items.def(pair.1.id).name) away")
        }
        for (k, st) in contents.enumerated() {
            let r = Rect(c.x + half + 20 + Double(k % perRow) * (tile + gap), c.y + 22 + Double(k / perRow) * (tile + gap), tile, tile)
            let sel = ui.stashSelection == k
            itemTile(&ui0, id: "stash.in.\(k)", r, st, selected: sel, action: .stashTake(k), ax: "Take \(Items.def(st.id).name)\(st.owner.map { ", belongs to \(Cast.def($0).short)" } ?? "")")
        }
        if let sel = ui.stashSelection, sel < contents.count, let owner = contents[sel].owner {
            let r = Rect(c.x + half + 20, c.maxY - 50, half, 44)
            ui0.button("stash.steal", r, icon: .hand, label: "Take it — belongs to \(Cast.def(owner).short)", style: .danger, action: .stashTake(sel), ax: "Confirm taking someone else's item", hint: "Theft if anyone sees")
        }
        if let d = def, !d.legal {
            ui0.text("stash.risk", "Hidden spot. Searches find it about \(Int(d.discovery * 100))% of the time — only if they look here.", Vec2(c.x, c.maxY - 18), size: 11, color: Palette.inkSoft, width: half)
        }
    }

    // MARK: Trade

    func itemRow(_ ui0: inout UIBuilder, id: String, _ stacks: [ItemStack], at p: Vec2, width: Double) {
        var x = p.x
        for (k, st) in stacks.enumerated() {
            let d = Items.def(st.id)
            ui0.panel("\(id).\(k)", Rect(x, p.y, 120, 56), .inset)
            ui0.icon("\(id).\(k).ic", d.icon, center: Vec2(x + 26, p.y + 28), size: 32, color: d.tint ?? Palette.ink)
            ui0.text("\(id).\(k).q", "×\(st.qty)", Vec2(x + 48, p.y + 10), size: 15, weight: .bold, width: 64)
            ui0.text("\(id).\(k).n", d.name, Vec2(x + 48, p.y + 30), size: 10.5, color: Palette.inkSoft, width: 68)
            x += 128
        }
        if stacks.isEmpty {
            ui0.text("\(id).none", "—", Vec2(p.x, p.y + 18), size: 15, color: Palette.inkSoft, width: 40)
        }
    }

    func buildTrade(_ q: TradeQuote, _ ui0: inout UIBuilder) {
        let npc = Cast.def(q.npc)
        let c = sheet(&ui0, id: "trade", title: "Trade with \(npc.short)", icon: .swap, width: 560, height: 330)
        ui0.text("trade.fixed", "Fixed quote. Nothing changes hands until you confirm.", Vec2(c.x, c.y), size: 12, color: Palette.inkSoft, width: c.w)
        ui0.text("trade.give", "You give", Vec2(c.x, c.y + 26), size: 12, weight: .semibold, width: 100)
        var give = q.give
        if q.credits > 0 { give.append(ItemStack(.requestForm, 0)) }
        itemRow(&ui0, id: "trade.g", q.give, at: Vec2(c.x, c.y + 44), width: c.w)
        if q.credits > 0 { ui0.text("trade.cr", "+ \(q.credits) credits", Vec2(c.x + Double(q.give.count) * 128 + 6, c.y + 62), size: 14, weight: .bold, width: 120) }
        ui0.icon("trade.arrow", .arrowDown, center: Vec2(c.midX, c.y + 116), size: 20, color: Palette.slate)
        ui0.text("trade.get", "You get", Vec2(c.x, c.y + 126), size: 12, weight: .semibold, width: 100)
        itemRow(&ui0, id: "trade.r", q.get, at: Vec2(c.x, c.y + 144), width: c.w)
        if q.get.isEmpty && q.favor > 0 { ui0.text("trade.fav", "\(npc.short) owes you a favor", Vec2(c.x, c.y + 160), size: 14, weight: .semibold, width: c.w) }
        let have = q.give.allSatisfy { s.inventory.count($0.id) >= $0.qty } && s.credits >= q.credits
        let t = Trades.byID[q.tradeID]
        let (avail, why) = t.map { tradeAvailable($0) } ?? (false, "Unavailable")
        ui0.button("trade.ok", Rect(c.maxX - 200, c.maxY - 48, 200, 46), icon: .check, label: avail ? (have ? "Confirm trade" : "You're missing items") : (why ?? "Unavailable"),
                   style: .primary, action: .tradeConfirm, ax: "Confirm trade", enabled: have && avail)
        ui0.button("trade.no", Rect(c.x, c.maxY - 48, 140, 46), icon: .close, label: "Not now", style: .pill, action: .closeModal, ax: "Cancel trade")
    }

    func buildTradeList(_ npcID: NPCID, _ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "tlist", title: "\(Cast.def(npcID).short)'s offers", icon: .swap, width: 560)
        var y = c.y
        for (k, t) in Trades.forNPC(npcID).enumerated() {
            let (ok, why) = tradeAvailable(t)
            let give = t.give.map { "\($0.1)× \(Items.def($0.0).name)" }.joined(separator: " + ")
            let get = t.get.isEmpty ? "a favor" : t.get.map { "\($0.1)× \(Items.def($0.0).name)" }.joined(separator: " + ")
            ui0.button("tlist.\(k)", Rect(c.x, y, c.w, 48), icon: .swap, label: "\(give) → \(get)\(ok ? "" : " (\(why ?? ""))")", style: .pill,
                       action: .tradeOpen(t.id), ax: "\(give) for \(get)", enabled: ok, labelSize: 12.5)
            y += 56
            if y > c.maxY - 48 { break }
        }
    }

    // MARK: Commissary

    func buildCommissary(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "com", title: "Commissary", icon: .coin, width: 700)
        let (ok, why) = commissaryEligible
        ui0.text("com.bal", "Balance \(s.credits) cr · spent today \(s.purchasesToday)/\(Game.commissaryDailyLimit) cr\(ok ? "" : " · \(why ?? "")")",
                 Vec2(c.x, c.y), size: 12.5, weight: .semibold, color: ok ? Palette.ink : Palette.coral.darker(0.2), width: c.w)
        let items = Game.commissaryCatalog
        let tw = 96.0, th = 78.0, gap = 8.0
        let perRow = Int((c.w + gap) / (tw + gap))
        for (k, id) in items.enumerated() {
            let d = Items.def(id)
            let r = Rect(c.x + Double(k % perRow) * (tw + gap), c.y + 26 + Double(k / perRow) * (th + gap), tw, th)
            let canBuy = ok && commissaryOpen && s.credits >= (d.price ?? 0) && s.purchasesToday + (d.price ?? 0) <= Game.commissaryDailyLimit
            ui0.button("com.\(k)", r, style: .tile, action: .buy(id), ax: "Buy \(d.name) for \(d.price ?? 0) credits", enabled: canBuy)
            ui0.icon("com.\(k).ic", d.icon, center: Vec2(r.midX, r.y + 26), size: 30, color: d.tint ?? Palette.ink, alpha: canBuy ? 1 : 0.45)
            ui0.text("com.\(k).n", d.name, Vec2(r.midX, r.y + 44), size: 10.5, align: .center, width: tw - 6)
            ui0.text("com.\(k).p", "\(d.price ?? 0) cr", Vec2(r.midX, r.y + 58), size: 11.5, weight: .bold, align: .center, width: tw - 6)
        }
    }

    // MARK: Choice

    func buildChoice(_ cid: ChoiceID, _ ui0: inout UIBuilder) {
        guard let def = Choices.byID[cid] else { return }
        let c = sheet(&ui0, id: "choice", title: def.title, icon: def.icon, width: 620, tone: .warm)
        var y = c.y
        if let sp = def.speaker {
            ui0.text("choice.sp", Cast.def(sp).name, Vec2(c.x, y), size: 12, weight: .semibold, color: Palette.inkSoft, width: c.w)
            y += 18
        }
        y += ui0.text("choice.prompt", def.prompt, Vec2(c.x, y), size: 14, width: c.w, maxLines: 4) + 10
        let available = def.options.enumerated().filter { eval($0.element.when) }
        let bh = min(64.0, (c.maxY - y - 8) / Double(max(1, available.count)) - 8)
        for (k, pair) in available.enumerated() {
            let (i, o) = pair
            let r = Rect(c.x, y + Double(k) * (bh + 8), c.w, bh)
            ui0.button("choice.\(k)", r, style: o.risky ? .ghost : .pill, action: .choice(cid, i), ax: "\(o.label). \(o.detail)")
            ui0.badge("choice.\(k).ic", o.icon, center: Vec2(r.x + 26, r.midY), size: 34, bg: o.risky ? Palette.coral : Palette.navy, fg: Palette.paper)
            ui0.text("choice.\(k).l", o.label, Vec2(r.x + 52, r.y + 8), size: 14, weight: .bold, width: r.w - 60)
            ui0.text("choice.\(k).d", o.detail, Vec2(r.x + 52, r.y + 28), size: 11.5, color: Palette.inkSoft, width: r.w - 60, maxLines: 2)
        }
    }

    // MARK: Document

    func buildDoc(_ id: DocID, _ ui0: inout UIBuilder) {
        let d = Docs.def(id, self)
        let c = sheet(&ui0, id: "doc", title: d.title, icon: d.icon, width: 680)
        ui0.text("doc.sub", d.subtitle, Vec2(c.x, c.y - 6), size: 11.5, color: Palette.inkSoft, width: c.w - 140)
        if let stamp = d.stamp {
            let sw = TextMetrics.width(stamp, size: 13, weight: .bold) + 18
            ui0.panel("doc.stamp.bg", Rect(c.maxX - sw - 4, c.y - 46, sw, 26), .danger, alpha: 0.85)
            ui0.text("doc.stamp", stamp, Vec2(c.maxX - sw / 2 - 4, c.y - 41), size: 13, weight: .bold, color: Palette.paper, align: .center, width: sw)
        }
        var y = c.y + 14 - ui.docScroll
        var k = 0
        for sec in d.sections {
            if let h = sec.heading {
                if y > c.y && y < c.maxY - 16 { ui0.text("doc.h\(k)", h.uppercased(), Vec2(c.x, y), size: 11, weight: .bold, color: Palette.slate, width: c.w) }
                y += 20
            }
            for line in sec.lines {
                k += 1
                let lines = TextMetrics.wrap(line.text, size: 13, width: c.w - 30)
                let hgt = Double(lines.count) * TextMetrics.lineHeight(13)
                if y > c.y - 2 && y + hgt < c.maxY + 2 {
                    if line.disputed { ui0.icon("doc.f\(k)", .flag, center: Vec2(c.x + 8, y + 8), size: 14, color: Palette.coral) }
                    if line.evidence { ui0.icon("doc.e\(k)", .star, center: Vec2(c.x + 8, y + (line.disputed ? 24 : 8)), size: 13, color: Palette.turquoise.darker(0.2)) }
                    ui0.text("doc.l\(k)", line.text, Vec2(c.x + 22, y), size: 13, color: line.evidence ? Palette.navy : Palette.ink, width: c.w - 30, maxLines: 6)
                }
                y += hgt + 6
            }
            y += 8
        }
        let overflow = y + ui.docScroll - c.maxY
        if overflow > 0 || ui.docScroll > 0 {
            ui0.button("doc.up", Rect(c.maxX - 44, c.maxY - 96, 40, 40), icon: .arrowUp, style: .round, action: .scroll("doc", -1), ax: "Scroll up", enabled: ui.docScroll > 0)
            ui0.button("doc.down", Rect(c.maxX - 44, c.maxY - 48, 40, 40), icon: .arrowDown, style: .round, action: .scroll("doc", 1), ax: "Scroll down", enabled: overflow > 0)
        }
        ui0.text("doc.legend", "Flag = you dispute this · Star = evidence you found", Vec2(c.x, c.maxY - 2), size: 10.5, color: Palette.inkSoft, width: c.w - 60)
    }

    // MARK: Journal

    func buildJournal(_ tab: JournalTab, _ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "jr", title: "Journal", icon: .journal, width: 720)
        let tabs: [(JournalTab, String, Icon)] = [(.quests, "Goals", .target), (.chart, "Papers", .clipboard), (.people, "People", .people), (.ledger, "Ledger", .coin), (.incidents, "Record", .form)]
        let tw = (c.w - Double(tabs.count - 1) * 6) / Double(tabs.count)
        for (k, t) in tabs.enumerated() {
            ui0.button("jr.tab\(k)", Rect(c.x + Double(k) * (tw + 6), c.y - 4, tw, 36), icon: t.2, label: t.1, style: tab == t.0 ? .tabActive : .tab,
                       action: .journalTab(t.0.rawValue), ax: "\(t.1) tab", labelSize: 12.5)
        }
        let body = Rect(c.x, c.y + 42, c.w, c.h - 42)
        var y = body.y
        switch tab {
        case .quests:
            if let (q, st) = activeMainQuest {
                ui0.text("jr.mq", "MAIN · \(q.title.uppercased())", Vec2(body.x, y), size: 11, weight: .bold, color: Palette.slate, width: body.w); y += 18
                ui0.badge("jr.mq.ic", st.icon, center: Vec2(body.x + 14, y + 12), size: 26, bg: Palette.ochre, fg: Palette.paper)
                y += ui0.text("jr.mq.o", st.objective, Vec2(body.x + 34, y + 2), size: 14, weight: .semibold, width: body.w - 40, maxLines: 2) + 6
                for (k, a) in st.approaches.prefix(3).enumerated() {
                    y += ui0.text("jr.mq.a\(k)", "• " + a, Vec2(body.x + 34, y), size: 12, color: Palette.inkSoft, width: body.w - 40, maxLines: 2) + 2
                }
                if let rec = st.recovery { y += ui0.text("jr.mq.r", "If it goes wrong: \(rec)", Vec2(body.x + 34, y), size: 11.5, color: Palette.slate, width: body.w - 40, maxLines: 2) + 4 }
                y += 8
                // Parallel chapters, one line each.
                for (k, pair) in activeMainQuests.dropFirst().prefix(3).enumerated() where y < body.maxY - 60 {
                    ui0.icon("jr.mq2.\(k).ic", pair.1.icon, center: Vec2(body.x + 14, y + 9), size: 18, color: Palette.ochre.darker(0.2))
                    y += ui0.text("jr.mq2.\(k)", "\(pair.0.title): \(pair.1.objective)", Vec2(body.x + 34, y), size: 12.5, weight: .semibold, width: body.w - 40, maxLines: 2) + 6
                }
                y += 4
            }
            if let r = s.recovery {
                ui0.badge("jr.rec.ic", r.icon, center: Vec2(body.x + 14, y + 12), size: 26, bg: Palette.turquoise.darker(0.15), fg: Palette.paper)
                y += ui0.text("jr.rec", "Recovery: \(r.text)", Vec2(body.x + 34, y + 4), size: 13, weight: .semibold, width: body.w - 40) + 12
            }
            let sides = activeSideQuests
            if !sides.isEmpty {
                ui0.text("jr.sq", "ERRANDS", Vec2(body.x, y), size: 11, weight: .bold, color: Palette.slate, width: body.w); y += 18
                for (k, pair) in sides.enumerated() where y < body.maxY - 24 {
                    ui0.icon("jr.sq\(k).ic", pair.0.icon, center: Vec2(body.x + 14, y + 9), size: 18, color: Palette.slate)
                    y += ui0.text("jr.sq\(k)", "\(pair.0.title): \(pair.1.objective)", Vec2(body.x + 34, y), size: 12.5, width: body.w - 40, maxLines: 2) + 6
                }
            }
            let done = s.quests.values.filter { $0.status == .done }.count
            ui0.text("jr.done", "Completed: \(done)", Vec2(body.x, body.maxY - 16), size: 11.5, color: Palette.inkSoft, width: 200)
        case .chart:
            let docs: [(DocID, String, Icon, Bool)] = [
                (.chart, "Your chart", .clipboard, has(.readChart)), (.handbook, "Today's schedule & rules", .list, true),
                (.intakeSheet, "Intake sheet", .form, true), (.medInfo, "About your medication", .pills, true),
                (.watchOrder, "Behavioral watch", .eye, true), (.incidentReport, "Incident record", .form, true),
            ] + StoryDocsList.available(self)
            for (k, d) in docs.enumerated() where d.3 {
                let col = k % 2, row = k / 2
                let w = (body.w - 10) / 2
                ui0.button("jr.doc\(k)", Rect(body.x + Double(col) * (w + 10), body.y + Double(row) * 54, w, 46), icon: d.2, label: d.1, style: .pill, action: .docOpen(d.0), ax: "Open \(d.1)", labelSize: 13)
            }
        case .people:
            let met = Cast.all.values.filter { d in
                if d.role == .lawyer || d.role == .family { return has(.lawyerMet) && d.id == .calloway || has(.visitorDayDone) && d.id == .nadia }
                return d.role == .peer ? (s.peerRep[d.id] ?? 0) != 0 || s.flags.contains(.metDutch) && d.id == .dutch : s.metStaff.contains(d.id)
            }.sorted { $0.name < $1.name }
            let colW = (body.w - 10) / 2
            for (k, d) in met.prefix(16).enumerated() {
                let x = body.x + Double(k % 2) * (colW + 10), yy = body.y + Double(k / 2) * 46
                let val = d.role == .peer ? (s.peerRep[d.id] ?? 0) : (s.staffOpinion[d.id] ?? 0)
                ui0.icon("jr.p\(k).ic", d.role == .peer ? .person : .badge, center: Vec2(x + 10, yy + 10), size: 16, color: d.role.isStaff ? Palette.navy : Palette.tan.darker(0.3))
                ui0.text("jr.p\(k).n", d.short, Vec2(x + 24, yy + 1), size: 13, weight: .semibold, width: 110)
                ui0.art("jr.p\(k).m", .named("meter", Int(clamp(Double(val + 100) / 2, 0, 100)), val >= 0 ? 3 : 2), at: Vec2(x + 140, yy + 6), scale: 0.8)
                ui0.text("jr.p\(k).b", d.blurb, Vec2(x + 24, yy + 19), size: 10.5, color: Palette.inkSoft, width: colW - 30)
            }
            if met.isEmpty { ui0.text("jr.p.none", "Talk to people to get to know them.", Vec2(body.x, body.y), size: 13, color: Palette.inkSoft, width: body.w) }
        case .ledger:
            ui0.text("jr.lg.h", "Balance: \(s.credits) credits · Favors: " + (s.favors.filter { $0.value > 0 }.map { "\(Cast.def($0.key).short) ×\($0.value)" }.sorted().joined(separator: ", ")).ifEmpty("none"),
                     Vec2(body.x, y), size: 12.5, weight: .semibold, width: body.w)
            y += 24
            for (k, e) in s.ledger.suffix(11).reversed().enumerated() {
                ui0.text("jr.lg\(k).t", "D\(e.day) \(Schedule.clockString(Double(e.minute)))", Vec2(body.x, y), size: 11.5, color: Palette.inkSoft, width: 80)
                ui0.text("jr.lg\(k).d", "\(e.delta >= 0 ? "+" : "")\(e.delta)", Vec2(body.x + 84, y), size: 12, weight: .bold, color: e.delta >= 0 ? Palette.statusGreen.darker(0.2) : Palette.coral.darker(0.15), width: 40)
                ui0.text("jr.lg\(k).r", e.reason, Vec2(body.x + 130, y), size: 12, width: body.w - 200)
                ui0.text("jr.lg\(k).b", "\(e.balance)", Vec2(body.maxX, y), size: 11.5, color: Palette.inkSoft, align: .right, width: 50)
                y += 20
            }
        case .incidents:
            if s.incidents.isEmpty { ui0.text("jr.in.none", "Nothing on your record yet.", Vec2(body.x, y), size: 13, color: Palette.inkSoft, width: body.w) }
            for (k, inc) in s.incidents.suffix(10).reversed().enumerated() {
                ui0.icon("jr.in\(k).ic", inc.kind.icon, center: Vec2(body.x + 10, y + 9), size: 16, color: inc.kind.severity >= 2 ? Palette.coral : Palette.slate)
                ui0.text("jr.in\(k)", "D\(inc.day) \(Schedule.clockString(Double(inc.minute))) · \(inc.kind.title) — \(inc.outcome)", Vec2(body.x + 24, y), size: 12, width: body.w - 30)
                y += 22
            }
        }
    }

    // MARK: Map

    func buildMap(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "map", title: "Campus map", icon: .map, width: 820)
        let showTunnels = has(.tunnelHatchKnown) || s.knownZones.contains { $0.hasPrefix("tunnels") }
        let mapW = 160.0, mapH = 116.0
        let areaW = showTunnels ? c.w * 0.8 : c.w
        let sc = min(areaW / mapW, (c.h - 18) / mapH)
        let origin = Vec2(c.x + (areaW - mapW * sc) / 2, c.y)
        ui0.art("map.overview", .mapOverview, at: origin, scale: sc / MapArt.scale)
        func toMap(_ v: Vec2) -> Vec2 { origin + v * sc }
        // Discovered rooms: tint + label.
        var labeled = Set<String>()
        for z in map.zones where s.knownZones.contains(z.id) && z.district != .service && z.district != .perimeter {
            for (k, r) in z.rects.enumerated() {
                let rr = Rect(origin.x + Double(r.x) * sc, origin.y + Double(r.y) * sc, Double(r.w) * sc, Double(r.h) * sc)
                ui0.shape("map.z.\(z.id).\(k)", ShapeSpec(.rect, w: rr.w, h: rr.h, radius: 2, fill: z.district.floorTint.darker(0.06)), at: rr.origin)
            }
            if !labeled.contains(z.name), let r = z.rects.first, Double(r.w) * sc > 28 {
                labeled.insert(z.name)
                ui0.text("map.l.\(z.id)", z.name, Vec2(origin.x + r.center.x * sc, origin.y + r.center.y * sc - 6), size: 9, weight: .semibold, color: Palette.ink, align: .center, width: Double(r.w) * sc + 20)
            }
        }
        // Known locked doors (requirements).
        for d in map.doors where s.knownZones.contains(map.zone(at: d.vertical ? TilePos(d.tile.x - 1, d.tile.y) : TilePos(d.tile.x, d.tile.y - 1))?.id ?? "") {
            if let di = map.doorByID[d.id], !playerCanPass(doorIndex: di), d.kind == .secure {
                ui0.icon("map.d.\(d.id)", .lock, center: toMap(d.tile.center), size: 9, color: Palette.coral.darker(0.1))
            }
        }
        // Objective & obligation markers.
        if let mk = primaryObjective.marker, let wp = markerPosition(mk), wp.x < 160 {
            ui0.badge("map.obj", primaryObjective.icon, center: toMap(wp), size: 18, bg: Palette.ochre, fg: Palette.paper)
        }
        if s.player.pos.x < 160 {
            ui0.badge("map.me", .person, center: toMap(s.player.pos), size: 16, bg: Palette.navy, fg: Palette.paper)
        }
        if showTunnels {
            let tx = c.x + areaW + 10, tw = c.w - areaW - 10
            ui0.panel("map.t.bg", Rect(tx, c.y, tw, c.h - 18), .inset)
            ui0.text("map.t.h", "Service tunnels", Vec2(tx + 6, c.y + 4), size: 10.5, weight: .bold, color: Palette.slate, width: tw - 8)
            let tsc = min((tw - 12) / 34, (c.h - 44) / 120)
            for z in map.zones where z.district == .service && s.knownZones.contains(z.id) {
                for (k, r) in z.rects.enumerated() {
                    ui0.shape("map.tz.\(z.id).\(k)", ShapeSpec(.rect, w: max(2, Double(r.w) * tsc), h: max(2, Double(r.h) * tsc), radius: 1, fill: Palette.tunnel.darker(0.1)),
                              at: Vec2(tx + 6 + Double(r.x - 165) * tsc, c.y + 22 + Double(r.y - 10) * tsc))
                }
            }
            if s.player.pos.x >= 160 {
                ui0.badge("map.me.t", .person, center: Vec2(tx + 6 + (s.player.pos.x - 165) * tsc, c.y + 22 + (s.player.pos.y - 10) * tsc), size: 14, bg: Palette.navy, fg: Palette.paper)
            }
        }
        ui0.text("map.legend", "Rooms appear as you visit them. Lock = secure door you can't open yet.", Vec2(c.x, c.maxY - 10), size: 10.5, color: Palette.inkSoft, width: c.w)
    }

    // MARK: Settings & menus

    func buildSettings(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "set", title: "Settings", icon: .gear, width: 760)
        let colW = (c.w - 16) / 2
        let toggles: [(String, String, Icon, Bool)] = [
            ("leftHanded", "Left-handed layout", .leftHand, settings.leftHanded), ("reducedMotion", "Reduced motion", .motion, settings.reducedMotion),
            ("conesAlways", "Always show vision cones", .cone, settings.conesAlways), ("captions", "Captions", .captions, settings.captions),
            ("iconLabels", "Icon labels", .info, settings.iconLabels), ("haptics", "Haptics", .hand, settings.haptics),
            ("betting", "Allow betting games", .coin, settings.bettingEnabled), ("assist", "Assist mode for minigames", .star, settings.assistMinigames),
        ]
        for (k, t) in toggles.enumerated() {
            let r = Rect(c.x, c.y + Double(k) * 46, colW, 40)
            ui0.icon("set.t\(k).ic", t.2, center: Vec2(r.x + 14, r.midY), size: 18, color: Palette.slate)
            ui0.text("set.t\(k).l", t.1, Vec2(r.x + 32, r.y + 11), size: 13, width: colW - 100)
            ui0.button("set.t\(k).b", Rect(r.maxX - 64, r.y, 60, 40), label: t.3 ? "On" : "Off", style: t.3 ? .primary : .pill, action: .setting(t.0), ax: "\(t.1): \(t.3 ? "on" : "off")", labelSize: 12.5)
        }
        let steppers: [(String, String, Icon, String)] = [
            ("music", "Music", .music, "\(Int(settings.musicVolume * 100))%"), ("sfx", "Effects", .sound, "\(Int(settings.sfxVolume * 100))%"),
            ("voice", "Voices (mumbles)", .voice, "\(Int(settings.voiceVolume * 100))%"), ("zoom", "Zoom", .search, "\(Int(settings.zoom))"),
            ("clock", "Clock speed", .clock, String(format: "%.2g×", settings.clockRate)), ("difficulty", "Difficulty", .trust, settings.difficulty.title),
        ]
        for (k, st) in steppers.enumerated() {
            let r = Rect(c.x + colW + 16, c.y + Double(k) * 46, colW, 40)
            ui0.icon("set.s\(k).ic", st.2, center: Vec2(r.x + 14, r.midY), size: 18, color: Palette.slate)
            ui0.text("set.s\(k).l", st.1, Vec2(r.x + 32, r.y + 11), size: 13, width: 120)
            ui0.button("set.s\(k).m", Rect(r.maxX - 150, r.y, 44, 40), icon: .minus, style: .round, action: .settingStep(st.0, -1), ax: "Decrease \(st.1)")
            ui0.text("set.s\(k).v", st.3, Vec2(r.maxX - 78, r.y + 11), size: 13, weight: .semibold, align: .center, width: 60)
            ui0.button("set.s\(k).p", Rect(r.maxX - 44, r.y, 44, 40), icon: .plus, style: .round, action: .settingStep(st.0, 1), ax: "Increase \(st.1)")
        }
        ui0.button("set.help", Rect(c.x + colW + 16, c.maxY - 46, colW, 44), icon: .info, label: "Controls & icon guide", style: .pill, action: .openHelp, ax: "Controls and icon guide")
    }

    func buildMenu(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "menu", title: "Paused", icon: .pause, width: 560)
        var items: [(Icon, String, UIAction)] = [(.play, "Resume", .closeModal), (.save, "Save now", .saveGame), (.gear, "Settings", .openSettings), (.info, "Controls & icons", .openHelp), (.journal, "Journal", .openJournal)]
        // Starting over erases the save: the first tap arms it, the second confirms.
        items.append(ui.confirmNewGame ? (.cross, "Tap again: erase and start over", .newGame) : (.plus, "New game", .armNewGame))
        if settings.devMenuEnabled || isDevBuild { items.append((.tools, "Developer", .dev("open"))) }
        // Two columns so the menu fits a phone held sideways.
        let colW = (c.w - 10) / 2
        for (k, it) in items.enumerated() {
            let r = Rect(c.x + Double(k % 2) * (colW + 10), c.y + Double(k / 2) * 54, colW, 46)
            ui0.button("menu.\(k)", r, icon: it.0, label: it.1, style: k == 0 ? .primary : .pill, action: it.2, ax: it.1, labelSize: it.1.count > 20 ? 12 : 14)
        }
        ui0.text("menu.day", "Day \(s.day) · \(Schedule.dayName(s.day)) · \(Schedule.clockString(s.minute))", Vec2(c.x, c.maxY - 14), size: 11.5, color: Palette.inkSoft, width: c.w)
    }

    func buildHelp(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "help", title: "Controls & icons", icon: .info, width: 780)
        let rows: [(Icon, String)] = [
            (.hand, "Tap the floor to walk there. Tap a person or object to walk over and use it."),
            (.run, "Double-tap the floor to run once, or toggle Run. Running is noisy indoors."),
            (.sneak, "Sneak is quiet (not invisible) and shows staff vision cones."),
            (.target, "The big round button uses whatever is outlined in front of you."),
            (.count, "Count: be in your cell at count time. 2 minutes' grace; late is better than missing."),
            (.question, "? Noticed — staff are curious. Move along or look busy."),
            (.exclaim, "! Challenged — they want a word. Comply, or it escalates."),
            (.search, "Magnifier — searching your last known spot (not where you are now)."),
            (.eye, "Watch: Green routine · Yellow closer rounds · Red constant observer. Badge color + word."),
            (.hide, "Hiding spots hide you from sight, but searches check them — with a visible cue."),
            (.flag, "In documents, a flag marks a record you dispute; a star marks evidence."),
            (.exclaim, "Item badges: ! contraband · lock restricted · shard dangerous · person = belongs to someone."),
        ]
        let colW = (c.w - 16) / 2
        for (k, r) in rows.enumerated() {
            let x = c.x + Double(k % 2) * (colW + 16), y = c.y + Double(k / 2) * 52
            ui0.badge("help.\(k).ic", r.0, center: Vec2(x + 16, y + 16), size: 30, bg: Palette.navy, fg: Palette.paper)
            ui0.text("help.\(k).t", r.1, Vec2(x + 38, y + 2), size: 12, width: colW - 44, maxLines: 3)
        }
    }

    func buildOutfit(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "outfit", title: "Change clothes", icon: .change, width: 560)
        let priv = privateForChanging()
        let watched = anyStaffSeesPlayer()
        ui0.text("outfit.note", priv ? (watched ? "Someone can see you. Changing in view is suspicious." : "Private enough. Takes a few seconds.") : "Find a private spot: your cell, a shower stall, a closet or the laundry.",
                 Vec2(c.x, c.y), size: 12.5, color: watched || !priv ? Palette.coral.darker(0.2) : Palette.inkSoft, width: c.w, maxLines: 2)
        var opts: [Outfit] = [.tanScrubs]
        for o in Outfit.allCases where o != .tanScrubs && s.inventory.count(o.item) > 0 { opts.append(o) }
        for (k, o) in opts.enumerated() {
            let r = Rect(c.x, c.y + 40 + Double(k) * 52, c.w, 46)
            let current = s.player.outfit == o
            ui0.button("outfit.\(k)", r, icon: .shirt, label: o.title + (current ? " (wearing)" : ""), style: current ? .tileSelected : .pill,
                       action: .outfit(o), ax: "Wear \(o.title)", enabled: priv && !current, iconColor: o.color.darker(0.1), labelSize: 13)
        }
    }

    func buildPhone(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "phone", title: "Phone", icon: .phone, width: 520)
        let contacts = PhoneBook.contacts(self)
        if contacts.isEmpty {
            ui0.text("phone.none", "No approved numbers yet. Ms. Pruitt handles phone lists.", Vec2(c.x, c.y), size: 13, color: Palette.inkSoft, width: c.w, maxLines: 2)
        }
        for (k, ct) in contacts.enumerated() {
            ui0.button("phone.\(k)", Rect(c.x, c.y + Double(k) * 54, c.w, 48), icon: ct.icon, label: ct.label, style: .pill, action: .phone(k), ax: "Call \(ct.label)", enabled: ct.enabled, labelSize: 13)
        }
    }

    func buildDev(_ ui0: inout UIBuilder) {
        let c = sheet(&ui0, id: "dev", title: "Developer", icon: .tools, width: 780)
        let actions = DevMenu.actions
        let colW = (c.w - 24) / 4
        let rows = max(1, Int((c.h - 50) / 46))
        let perPage = rows * 4
        let pages = (actions.count + perPage - 1) / perPage
        let page = min(ui.devPage, pages - 1)
        for (k, a) in actions.dropFirst(page * perPage).prefix(perPage).enumerated() {
            let r = Rect(c.x + Double(k % 4) * (colW + 8), c.y + Double(k / 4) * 46, colW, 40)
            ui0.button("dev.\(page).\(k)", r, label: a.1, style: .pill, action: .dev(a.0), ax: a.1, labelSize: 11.5)
        }
        if pages > 1 {
            let y = c.maxY - 42
            ui0.button("dev.prev", Rect(c.x, y, 120, 40), icon: .arrowLeft, label: "Prev", style: .pill, action: .dev("page-"), ax: "Previous page", enabled: page > 0)
            ui0.text("dev.page", "Page \(page + 1) of \(pages)", Vec2(c.midX, y + 11), size: 12.5, weight: .semibold, color: Palette.inkSoft, align: .center, width: 160)
            ui0.button("dev.next", Rect(c.maxX - 120, y, 120, 40), icon: .arrowRight, label: "Next", style: .pill, action: .dev("page+"), ax: "Next page", enabled: page < pages - 1)
        }
    }
}

extension String {
    func ifEmpty(_ alt: String) -> String { isEmpty ? alt : self }
}
