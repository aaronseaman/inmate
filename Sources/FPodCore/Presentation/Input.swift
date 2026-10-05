import Foundation

extension Game {
    /// A tap at a screen point (points, origin top-left).
    public func tap(_ p: Vec2) {
        haptic(.light)
        // Hit regions come from the last built frame; build one if none exists yet.
        if ui.hitRegions.isEmpty { _ = buildFrame() }
        if let tr = transition {
            if tr.card != nil { sceneContinue() }
            return
        }
        // UI hit regions (topmost first).
        for h in ui.hitRegions.reversed() where h.rect.contains(p) {
            if case .none = h.action { return }
            if case .minigameButton(-1) = h.action, let mg = minigame, mg.phase == .playing {
                mg.game.tap(p, canvas: minigameCanvas)
                return
            }
            perform(h.action)
            return
        }
        if minigame != nil { return }
        if ui.modal != nil {
            ui.modal = nil
            return
        }
        tapWorld(p)
    }

    func tapWorld(_ p: Vec2) {
        let w = screenToWorld(p)
        let now = ui.realTime
        var run = false
        if let last = ui.lastTap, now - last.time < 0.35, (last.pos - p).length < 34 { run = true }
        ui.lastTap = (p, now)
        if s.player.hiddenIn != nil {
            if let id = s.player.hiddenIn, let o = map.object(id: id), o.rect.rect.insetBy(-0.4).contains(w) {
                openInteraction(.object(id))
            } else {
                toast(.hide, "Hidden — tap the hiding spot or the button to come out")
            }
            return
        }
        if s.player.escortedBy != nil { toast(.badge, "Being escorted"); return }
        if let t = pickTarget(at: w) {
            if !s.flags.contains(.tutorialInteract) { s.flags.insert(.tutorialInteract) }
            engage(t, run: run)
            return
        }
        if walk(to: w, run: run) {
            ui.tapMarker = (s.player.path.last ?? w, now)
            if !s.flags.contains(.tutorialMove) { s.flags.insert(.tutorialMove) }
        }
        ui.pendingTarget = nil
    }

    /// Nearest tappable person or thing under the finger (with touch slop).
    func pickTarget(at w: Vec2) -> TargetRef? {
        let slop = max(0.35, 18 / settings.zoom)
        var best: (TargetRef, Double)?
        for n in s.npcs where n.present {
            let body = n.pos + Vec2(0, -0.55)
            let d = min(body.distance(to: w), n.pos.distance(to: w))
            if d < 0.45 + slop && (best == nil || d < best!.1) { best = (.npc(n.id), d) }
        }
        if best != nil { return best!.0 }
        var objBest: (TargetRef, Double)?
        let t = w.tile
        for dy in -1...1 {
            for dx in -1...1 {
                guard let o = map.object(at: TilePos(t.x + dx, t.y + dy)), isInteractable(o) else { continue }
                let d = o.rect.rect.distance(to: w)
                if d < slop * 0.6 && (objBest == nil || d < objBest!.1 || (d == objBest!.1 && Double(o.w * o.h) < 2)) { objBest = (.object(o.id), d) }
            }
        }
        if let ob = objBest { return ob.0 }
        if let di = map.doorIndex(at: t), !playerCanPass(doorIndex: di) { return .door(map.doors[di].id) }
        return nil
    }

    public func perform(_ a: UIAction) {
        switch a {
        case .none: break
        case .closeModal:
            ui.modal = nil
            ui.inventorySelection = nil
            ui.stashSelection = nil
            ui.docScroll = 0
        case .openInventory: ui.modal = .inventory; ui.inventorySelection = nil
        case .openMap: ui.modal = .map
        case .openJournal: ui.modal = .journal(.quests)
        case .openSettings: ui.modal = .settings
        case .openMenu: ui.modal = .menu; ui.confirmNewGame = false
        case .openHelp: ui.modal = .help
        case .journalTab(let t): ui.modal = .journal(JournalTab(rawValue: t) ?? .quests)
        case .toggleSneak:
            s.player.sneakToggle.toggle()
            if s.player.sneakToggle { s.player.runToggle = false; setFlag(.tutorialSneak) }
            sound(.tap, volume: 0.5)
        case .toggleRun:
            s.player.runToggle.toggle()
            if s.player.runToggle { s.player.sneakToggle = false }
            sound(.tap, volume: 0.5)
        case .park:
            parkVehicle()
        case .toggleStatus:
            ui.statusExpanded.toggle()
            setFlag(.tutorialStatus)
        case .contextInteract:
            if let q = ui.questionedBy { ui.complied = q; return }
            if s.player.hiddenIn != nil { exitHide(); return }
            if let t = ui.contextTarget { openInteraction(t) }
        case .comply:
            if let q = ui.questionedBy { ui.complied = q }
        case .unhide:
            exitHide()
        case .fanOption(let id):
            if case .fan(let t, _)? = ui.modal { perform(id, on: t) }
        case .invSelect(let slot, let idx):
            if let cur = ui.inventorySelection, cur.0 == slot && cur.1 == idx { ui.inventorySelection = nil } else { ui.inventorySelection = (slot, idx) }
        case .invMove(let to):
            if let (slot, idx) = ui.inventorySelection {
                if moveStack(from: slot, index: idx, to: to) {
                    let n = s.inventory.stacks(to).count
                    ui.inventorySelection = (to, max(0, n - 1))
                } else { toast(.cross, "Doesn't fit there") }
            }
        case .invUse:
            if let (slot, idx) = ui.inventorySelection, idx < s.inventory.stacks(slot).count { useItem(s.inventory.stacks(slot)[idx].id) }
        case .invDropToStash: break
        case .stashPut(let slot, let idx):
            if case .stash(let id)? = ui.modal { _ = stashPut(id, from: slot, index: idx) }
        case .stashTake(let idx):
            guard case .stash(let id)? = ui.modal else { return }
            let contents = stashContents(id)
            guard idx < contents.count else { return }
            if contents[idx].owner != nil && ui.stashSelection != idx {
                ui.stashSelection = idx   // first tap selects; second confirms
                return
            }
            ui.stashSelection = nil
            _ = stashTake(id, index: idx)
        case .tradeConfirm:
            if case .trade(let q)? = ui.modal, confirmTrade(q) { ui.modal = nil }
        case .tradeOpen(let id):
            if let t = Trades.byID[id] { ui.modal = .trade(quote(t)) }
        case .buy(let id): _ = buy(id)
        case .choice(let c, let i): choose(c, option: i)
        case .outfit(let o):
            ui.modal = nil
            if anyStaffSeesPlayer() { witnessCheckSoftChange() }
            beginChange(to: o)
        case .phone(let k): PhoneBook.call(self, k)
        case .setting(let key): toggleSetting(key)
        case .settingStep(let key, let d): stepSetting(key, d)
        case .minigameStart, .minigameQuit, .minigameContinue, .minigameAssist: minigameAction(a)
        case .minigameButton: break
        case .sceneContinue: sceneContinue()
        case .scroll(let what, let d):
            if what == "doc" { ui.docScroll = max(0, ui.docScroll + Double(d) * 160) }
        case .dev(let key): DevMenu.run(self, key)
        case .mapPan: break
        case .newGame: ui.platformRequest = .newGame; ui.confirmNewGame = false
        case .armNewGame: ui.confirmNewGame = true; sound(.alert, volume: 0.5)
        case .loadPreFinale: ui.platformRequest = .loadPreFinale
        case .continueGame: ui.modal = nil
        case .saveGame:
            saveRequested = true
            toast(.save, "Saved")
            ui.modal = nil
        case .docOpen(let d): openDoc(d)
        }
    }

    func witnessCheckSoftChange() {
        for i in s.npcs.indices where s.npcs[i].present {
            let def = Cast.def(s.npcs[i].id)
            if def.role.isStaff && npcCanSeePlayer(s.npcs[i], def) {
                s.npcs[i].suspicion = min(100, s.npcs[i].suspicion + 50)
                s.npcs[i].questionReason = .changingWatched
            }
        }
    }

    func useItem(_ id: ItemID) {
        switch id {
        case .snack: if removeItem(.snack) { s.player.energy = min(100, s.player.energy + 10); toast(.snack, "Ate a snack (+energy)") }
        case .coffee: if removeItem(.coffee) { s.player.energy = min(100, s.player.energy + 16); toast(.cup, "Coffee (+energy)") }
        case .peanutButter: if removeItem(.peanutButter) { s.player.energy = min(100, s.player.energy + 12); toast(.jar, "Peanut butter (+energy)") }
        case .tomatoes: if removeItem(.tomatoes) { s.player.energy = min(100, s.player.energy + 8); toast(.tomato, "Fresh tomato (+energy)") }
        case .chartCopy: openDoc(.chart)
        case .courtDocket: openDoc(.docket)
        case .transportLog: openDoc(.transportLog)
        case .letter: openDoc(.lawyerLetter)
        case .supportLetter: openDoc(.sisterLetter)
        case .witnessStatement: openDoc(.witnessTheo)
        case .lawyerCard: toast(.card, "Ruth Calloway — public defender. Number on the back.")
        default:
            if let o = Outfit.from(item: id) {
                if privateForChanging() { ui.modal = nil; beginChange(to: o) } else { toast(.change, "Find a private spot to change") }
            }
        }
        ui.inventorySelection = nil
    }

    func toggleSetting(_ key: String) {
        switch key {
        case "leftHanded": settings.leftHanded.toggle()
        case "reducedMotion": settings.reducedMotion.toggle()
        case "conesAlways": settings.conesAlways.toggle()
        case "captions": settings.captions.toggle()
        case "iconLabels": settings.iconLabels.toggle()
        case "haptics": settings.haptics.toggle()
        case "betting": settings.bettingEnabled.toggle()
        case "assist": settings.assistMinigames.toggle()
        default: break
        }
        settingsChanged = true
    }

    func stepSetting(_ key: String, _ d: Int) {
        let step = Double(d) * 0.1
        switch key {
        case "music": settings.musicVolume = clamp((settings.musicVolume + step) * 10, 0, 10).rounded() / 10
        case "sfx": settings.sfxVolume = clamp((settings.sfxVolume + step) * 10, 0, 10).rounded() / 10
        case "voice": settings.voiceVolume = clamp((settings.voiceVolume + step) * 10, 0, 10).rounded() / 10
        case "zoom": settings.zoom = clamp(settings.zoom + Double(d) * 4, 22, 42); ui.cameraSnap = true
        case "clock":
            let rates = [0.5, 0.75, 1.0, 1.25, 1.5]
            let i = rates.firstIndex(where: { abs($0 - settings.clockRate) < 0.01 }) ?? 2
            settings.clockRate = rates[clamp(i + d, 0, rates.count - 1)]
        case "difficulty":
            let all = Difficulty.allCases
            let i = all.firstIndex(of: settings.difficulty) ?? 1
            settings.difficulty = all[clamp(i + d, 0, all.count - 1)]
        default: break
        }
        settingsChanged = true
    }
}
