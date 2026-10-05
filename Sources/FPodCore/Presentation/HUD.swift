import Foundation

extension Game {
    func buildHUD(_ ui0: inout UIBuilder) {
        let safe = viewport.safeRect
        let m = 10.0
        let left = settings.leftHanded
        // --- Schedule chip (top-left) ---
        let block = currentBlock
        let countSoon = s.countState.warned && !s.countState.resolved && s.countState.activeDay == s.day
        var schedText = "\(Schedule.clockString(s.minute))  \(block.activity.title)"
        var chipStyle = PanelStyle.chip
        var schedIcon = Schedule.icon(block.activity)
        if countSoon && !playerInOwnCell() {
            let mins = max(0, Double(s.countState.activeStart) + countGraceMinutes - s.minute)
            schedText = "\(Schedule.clockString(s.minute))  Count · \(Int(mins.rounded(.up)))m"
            chipStyle = .danger
            schedIcon = .count
        } else if let nb = nextBlock, Double(nb.start) - s.minute <= 10 {
            schedText += " → \(nb.activity.title) \(Int((Double(nb.start) - s.minute).rounded(.up)))m"
        }
        let schedW = min(250, TextMetrics.width(schedText, size: 13, weight: .semibold) + 52)
        let schedR = Rect(safe.x + m, safe.y + m, schedW, 36)
        ui0.panel("sched", schedR, chipStyle)
        let fg: RGBA = chipStyle == .danger ? Palette.paper : Palette.ink
        ui0.icon("sched.ic", schedIcon, center: Vec2(schedR.x + 20, schedR.midY), size: 20, color: fg)
        ui0.text("sched.t", schedText, Vec2(schedR.x + 36, schedR.y + 9), size: 13, weight: .semibold, color: fg, width: schedW - 44)
        ui0.hit(schedR, .openJournal, label: "Schedule: \(schedText). Opens journal.", id: "sched")
        // --- Menu buttons (top-right) ---
        let bsz = 44.0
        let buttons: [(String, Icon, UIAction, String)] = [
            ("bag", .bag, .openInventory, "Inventory"), ("map", .map, .openMap, "Map"),
            ("journal", .journal, .openJournal, "Journal"), ("menu", .gear, .openMenu, "Menu"),
        ]
        for (k, b) in buttons.enumerated() {
            let x = safe.maxX - m - bsz - Double(buttons.count - 1 - k) * (bsz + 8)
            ui0.button("top.\(b.0)", Rect(x, safe.y + m - 4, bsz, bsz), icon: b.1, style: .round, action: b.2, ax: b.3)
        }
        let menuLeft = safe.maxX - m - Double(buttons.count) * (bsz + 8)
        // --- Objective chip (top-center, between) ---
        let obj = primaryObjective
        let objLeft = schedR.maxX + 10
        let objMaxW = max(120, menuLeft - objLeft - 6)
        let objText = TextMetrics.truncate(obj.text, size: 13, weight: .semibold, width: objMaxW - 52)
        let objW = min(objMaxW, TextMetrics.width(objText, size: 13, weight: .semibold) + 58)
        let objX = max(objLeft, min(safe.midX - objW / 2, menuLeft - objW - 6))
        let objR = Rect(objX, safe.y + m, objW, 36)
        ui0.panel("obj", objR, .chip)
        ui0.badge("obj.ic", obj.icon, center: Vec2(objR.x + 19, objR.midY), size: 26, bg: Palette.ochre, fg: Palette.paper)
        ui0.text("obj.t", objText, Vec2(objR.x + 38, objR.y + 9), size: 13, weight: .semibold, width: objW - 46)
        ui0.hit(objR, .openJournal, label: "Objective: \(obj.text)", id: "obj")
        // Off-screen arrow toward the objective.
        if let mk = obj.marker, let wp = markerPosition(mk) {
            let sp = worldToScreen(wp)
            let inner = safe.insetBy(dx: 40, dy: 60)
            if !inner.contains(sp) {
                let c = safe.center
                let d = (sp - c)
                let ang = d.angle
                // Clamp to an ellipse inside the safe area.
                let ex = inner.w / 2, ey = inner.h / 2
                let k = 1 / ((cos(ang) * cos(ang)) / (ex * ex) + (sin(ang) * sin(ang)) / (ey * ey)).squareRoot()
                let at = c + Vec2.fromAngle(ang) * k
                // Badges rotate about their top-left anchor; offset so the turn pivots on the center.
                let half = Vec2(15, 15)
                let pivot = Vec2(half.x * cos(ang) - half.y * sin(ang), half.x * sin(ang) + half.y * cos(ang))
                ui0.badge("obj.arrow", .arrowRight, center: at - pivot + half, size: 30, bg: Palette.ochre, fg: Palette.paper)
                ui0.items[ui0.items.count - 1].rotation = ang
            }
        }
        // --- Suspicion indicator ---
        var y = objR.maxY + 8
        let (who, susp) = maxSuspicion()
        if susp >= 10 {
            let stage: (String, Icon, RGBA)
            if susp >= 100 { stage = ("Pursued", .exclaim, Palette.coral) } else if susp >= 75 { stage = ("Searching", .search, Palette.coral) } else if susp >= 50 { stage = ("Challenged", .exclaim, Palette.ochre) } else if susp >= 25 { stage = ("Noticed", .question, Palette.ochre) } else { stage = ("Watched", .eye, Palette.slate) }
            let w = 190.0
            let r = Rect(safe.midX - w / 2, y, w, 30)
            ui0.panel("susp", r, .chip)
            ui0.badge("susp.ic", stage.1, center: Vec2(r.x + 16, r.midY), size: 22, bg: stage.2, fg: Palette.paper)
            let name = who.map { Cast.def($0).short } ?? "Camera"
            ui0.text("susp.t", "\(stage.0) · \(name)", Vec2(r.x + 32, r.y + 3), size: 11.5, weight: .semibold, width: w - 40)
            ui0.art("susp.bar", .named("meter", Int(min(100, susp)), susp >= 75 ? 2 : 1), at: Vec2(r.x + 32, r.y + 18), alpha: 1, scale: (w - 44) / 120)
            ui0.ax.append(AXElement(id: "susp", rect: r, label: "Suspicion: \(stage.0), \(Int(susp)) of 100, \(name)", hint: nil, isButton: false))
            y = r.maxY + 6
        }
        // --- Toasts (left column under the schedule chip; keeps the centre clear) ---
        let toastMax = 300.0
        let toastX = left ? safe.maxX - m - toastMax : safe.x + m
        var ty = schedR.maxY + 8
        for (k, t) in ui.toasts.suffix(3).enumerated() {
            let a = t.time < 0.2 ? t.time / 0.2 : (t.time > 3.0 ? max(0, (3.6 - t.time) / 0.6) : 1)
            let tw = min(toastMax, TextMetrics.width(t.text, size: 12, weight: .medium) + 42)
            // Long toasts wrap to a second line instead of losing their ending.
            let lines = min(2, TextMetrics.wrap(t.text, size: 12, width: tw - 40).count)
            let r = Rect(left ? safe.maxX - m - tw : toastX, ty, tw, lines > 1 ? 40 : 26)
            ui0.panel("toast\(k)", r, t.danger ? .danger : .toast, alpha: a)
            ui0.icon("toast\(k).ic", t.icon, center: Vec2(r.x + 15, r.midY), size: 15, color: t.danger ? Palette.paper : Palette.slate, alpha: a)
            ui0.text("toast\(k).t", t.text, Vec2(r.x + 28, r.y + 5), size: 12, color: t.danger ? Palette.paper : Palette.ink, width: tw - 40, maxLines: 2, alpha: a)
            ty = r.maxY + 4
        }
        if let last = ui.toasts.last { ui0.ax.append(AXElement(id: "toast", rect: Rect(toastX, schedR.maxY + 8, toastMax, 26), label: last.text, hint: nil, isButton: false)) }
        _ = y
        // --- Action cluster (bottom-right, mirrored for left-handed) ---
        let big = 72.0, small = 52.0
        func xFromRight(_ offset: Double, _ w: Double) -> Double { left ? safe.x + m + offset : safe.maxX - m - offset - w }
        let interactR = Rect(xFromRight(0, big), safe.maxY - m - big, big, big)
        if let t = ui.contextTarget {
            let (icon, label) = contextLabel(t)
            ui0.button("act.interact", interactR, icon: icon, style: .roundLarge, action: .contextInteract, ax: label, iconColor: Palette.navy)
            let lw = max(70, TextMetrics.width(label, size: 11, weight: .semibold) + 14)
            let lr = Rect(interactR.midX - lw / 2, interactR.y - 24, lw, 20)
            ui0.panel("act.lbl", lr, .chip)
            ui0.text("act.lbl.t", label, Vec2(lr.midX, lr.y + 3), size: 11, weight: .semibold, align: .center, width: lw - 6)
        } else {
            ui0.button("act.interact", interactR, icon: .hand, style: .roundLarge, action: .contextInteract, ax: "Interact (nothing nearby)", enabled: false)
        }
        let sneakR = Rect(xFromRight(big + 14, small), safe.maxY - m - small - 4, small, small)
        let runR = Rect(xFromRight(big * 0.5 - small * 0.5, small), interactR.y - small - 36, small, small)
        if let v = s.player.vehicle {
            // Equipment replaces sneak/run: you can't tiptoe with a floor buffer.
            ui0.button("act.park", runR, icon: v.icon, label: "Park", style: .toggleOn,
                       action: .park, ax: "Park the \(v.title.lowercased())", hint: "Leave it here; it goes back to its bay")
        } else {
            ui0.button("act.sneak", sneakR, icon: .sneak, label: settings.iconLabels ? "Sneak" : nil, style: s.player.sneakToggle ? .toggleOn : .toggleOff,
                       action: .toggleSneak, ax: s.player.sneakToggle ? "Sneak on" : "Sneak off", hint: "Quiet movement; shows vision cones")
            ui0.button("act.run", runR, icon: .run, label: settings.iconLabels ? "Run" : nil, style: s.player.runToggle ? .toggleOn : .toggleOff,
                       action: .toggleRun, ax: s.player.runToggle ? "Run on" : "Run off", hint: "Fast and noisy. Double-tap the floor to run once.")
        }
        // --- Status chip (bottom-left; mirrored) ---
        buildStatus(&ui0, safe: safe, m: m, left: left)
        // --- Caption strip ---
        if settings.captions && ui.captionTime < 4 && !ui.caption.isEmpty {
            let cw = min(safe.w * 0.55, TextMetrics.width(ui.caption, size: 13) + 28)
            let r = Rect(safe.midX - cw / 2, safe.maxY - m - 34, cw, 30)
            ui0.panel("caption", r, .dark, alpha: 0.92)
            ui0.text("caption.t", ui.caption, Vec2(r.midX, r.y + 7), size: 13, color: Palette.paper, align: .center, width: cw - 16)
            ui0.ax.append(AXElement(id: "caption", rect: r, label: ui.caption, hint: nil, isButton: false))
        }
    }

    func contextLabel(_ t: TargetRef) -> (Icon, String) {
        if let q = ui.questionedBy, case .npc(let id) = t, q == id { return (.thumbsUp, "Comply") }
        if s.player.hiddenIn != nil { return (.arrowRight, "Come out") }
        switch t {
        case .npc(let id): return (Cast.def(id).role.isStaff ? .voice : .voice, Cast.def(id).short)
        case .object(let id):
            guard let o = map.object(id: id) else { return (.hand, "Use") }
            return (objectIcon(o), objectTitle(o))
        case .door(let id): return (.lock, map.door(id: id)?.name ?? "Door")
        }
    }

    func objectIcon(_ o: WorldObject) -> Icon {
        switch o.kind {
        case .bunk: return .bed
        case .locker: return .stash
        case .shower: return .shower
        case .sink: return .soap
        case .tv: return .tv
        case .phone: return .phone
        case .medWindow: return .pills
        case .commissary: return .coin
        case .noticeBoard: return .list
        case .hamper: return .laundry
        case .stack, .shelf: return .book
        case .hatch, .culvert: return .arrowDown
        case .donationBox: return .box
        case .mopBucket: return .mop
        case .pew: return .candle
        case .dumpster, .crate: return .hide
        default: return .hand
        }
    }

    public func objectTitle(_ o: WorldObject) -> String {
        if let h = hideSpotByObject[o.id], o.kind != .bunk, o.kind != .locker { return h.title }
        switch o.kind {
        case .bunk: return o.zone == "fpod.cell\(s.player.cell)" ? "Your bunk" : "Bunk"
        case .locker: return o.zone == "fpod.cell\(s.player.cell)" ? "Your locker" : "Locker"
        case .medWindow: return "Med window"
        case .commissary: return "Commissary"
        case .noticeBoard: return "Notice board"
        case .phone: return "Phone"
        case .tv: return "TV"
        case .sink: return "Sink"
        case .toilet: return "Toilet"
        case .vent: return "Vent"
        case .donationBox: return "Donation box"
        case .mopBucket: return "Mop & bucket"
        case .waterCooler: return "Water"
        case .piano: return "Piano"
        case .hatch: return "Hatch"
        case .culvert: return "Culvert"
        default:
            if let job = s.player.job, Jobs.def(job).stationObject == o.id { return "\(Jobs.def(job).title) station" }
            return o.kind.rawValue.capitalized
        }
    }

    func buildStatus(_ ui0: inout UIBuilder, safe: Rect, m: Double, left: Bool) {
        let watchColor = s.watch.color
        if ui.statusExpanded {
            let w = 250.0, h = 196.0
            let x = left ? safe.maxX - m - w : safe.x + m
            let r = Rect(x, safe.maxY - m - h, w, h)
            ui0.panel("status", r, .card)
            var yy = r.y + 12
            func row(_ id: String, _ icon: Icon, _ label: String, _ value: String, color: RGBA = Palette.ink) {
                ui0.icon("st.\(id).ic", icon, center: Vec2(r.x + 22, yy + 9), size: 18, color: color)
                ui0.text("st.\(id).l", label, Vec2(r.x + 40, yy + 1), size: 12, color: Palette.inkSoft, width: 80)
                ui0.text("st.\(id).v", value, Vec2(r.x + 112, yy + 1), size: 12.5, weight: .semibold, width: w - 122)
                ui0.ax.append(AXElement(id: "st.\(id)", rect: Rect(r.x, yy, w, 22), label: "\(label): \(value)", hint: nil, isButton: false))
                yy += 26
            }
            let watchVal = s.watch == .green ? "Green · routine" : "\(s.watch.short) · \(Int(watchHoursLeft.rounded()))h left"
            row("watch", .eye, "Watch", watchVal, color: watchColor)
            row("energy", .energy, "Energy", "\(Int(s.player.energy))%")
            ui0.art("st.energy.bar", .named("meter", Int(s.player.energy), s.player.energy < 25 ? 2 : 3), at: Vec2(r.x + 112, yy - 6), scale: 1)
            yy += 4
            row("credits", .coin, "Credits", "\(s.credits) cr")
            row("trust", .trust, "Trust", "Tier \(trustTier)")
            ui0.art("st.trust.dots", .named("trustdots", trustTier, 0), at: Vec2(r.x + 160, yy - 21), scale: 1)
            let outfitVal = s.player.outfit == .tanScrubs ? "Tan scrubs" : "\(s.player.outfit.title) \(Int(s.player.outfitCondition))%"
            row("outfit", .shirt, "Wearing", outfitVal)
            let restr = s.restrictions.filter { $0.value > s.absMinute }.map { $0.key.title }.sorted()
            row("restr", .lock, "Limits", restr.isEmpty ? "None" : restr.joined(separator: ", "))
            ui0.hit(r, .toggleStatus, label: "Collapse status", id: "status")
        } else {
            let w = 156.0, h = 40.0
            let x = left ? safe.maxX - m - w : safe.x + m
            let r = Rect(x, safe.maxY - m - h, w, h)
            ui0.panel("status", r, .chip)
            ui0.badge("st.watch", .eye, center: Vec2(r.x + 20, r.midY), size: 26, bg: watchColor, fg: Palette.paper)
            ui0.text("st.watch.t", s.watch.short, Vec2(r.x + 37, r.y + 4), size: 11, weight: .semibold, color: Palette.inkSoft, width: 50)
            ui0.text("st.cr", "\(s.credits) cr", Vec2(r.x + 37, r.y + 19), size: 12.5, weight: .bold, width: 52)
            ui0.icon("st.energy", .energy, center: Vec2(r.x + 98, r.midY), size: 16, color: s.player.energy < 25 ? Palette.coral : Palette.slate)
            ui0.text("st.energy.t", "\(Int(s.player.energy))", Vec2(r.x + 107, r.y + 12), size: 12, weight: .semibold, width: 30)
            ui0.icon("st.more", .arrowUp, center: Vec2(r.maxX - 14, r.midY), size: 12, color: Palette.slate)
            ui0.hit(r, .toggleStatus, label: "Status: watch \(s.watch.short), \(s.credits) credits, energy \(Int(s.player.energy)). Tap to expand.", id: "status")
        }
    }
}
