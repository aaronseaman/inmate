import Foundation

extension Game {
    // MARK: Conditions

    public func eval(_ c: Cond) -> Bool {
        switch c {
        case .always: return true
        case .never: return false
        case .flag(let f): return has(f)
        case .notFlag(let f): return !has(f)
        case .has(let i, let n): return s.inventory.count(i) >= n
        case .hasAny(let ids): return ids.contains { s.inventory.count($0) > 0 }
        case .credits(let n): return s.credits >= n
        case .trustTier(let n): return trustTier >= n
        case .peer(let id, let n): return (s.peerRep[id] ?? 0) >= n
        case .staff(let id, let n): return (s.staffOpinion[id] ?? 0) >= n
        case .favor(let id, let n): return (s.favors[id] ?? 0) >= n
        case .activity(let acts): return acts.contains(activity)
        case .minuteBetween(let a, let b): return Int(s.minute) >= a && Int(s.minute) < b
        case .dayAtLeast(let d): return s.day >= d
        case .weekend: return Schedule.isWeekend(s.day)
        case .questActive(let q): return s.quests[q]?.status == .active
        case .questStage(let q, let n): return s.quests[q]?.status == .active && s.quests[q]?.stage == n
        case .questStageAtLeast(let q, let n):
            guard let p = s.quests[q] else { return false }
            return p.status == .done || (p.status == .active && p.stage >= n)
        case .questDone(let q): return s.quests[q]?.status == .done
        case .questNotStarted(let q): return (s.quests[q]?.status ?? .inactive) == .inactive
        case .questAvailable(let q):
            guard (s.quests[q]?.status ?? .inactive) == .inactive, let d = Quests.byID[q] else { return false }
            return eval(d.prerequisite)
        case .job(let j): return s.player.job == j
        case .noJob: return s.player.job == nil
        case .outfit(let o): return s.player.outfit == o
        case .watchAtMost(let w): return s.watch <= w
        case .zone(let z): return map.zone(at: s.player.pos)?.id == z
        case .unobserved: return !anyStaffSeesPlayer()
        case .shiftDone: return s.shiftDoneKeys.contains("d\(s.day).\(activity.rawValue)")
        case .vehicle(let v): return s.player.vehicle == v
        case .betting: return settings.bettingEnabled
        case .watch72: return s.watch72
        case .watchReviewReady: return watchReviewReady
        case .npcHere(let id): return npc(id).map { $0.present && $0.pos.distance(to: s.player.pos) < 6 } ?? false
        case .dailyOnce(let k): return !s.usedInteractions.contains("daily.\(k).d\(s.day)")
        case .countFlags(let fs, let n): return fs.filter { has($0) }.count >= n
        case .hasOwned(let item, let owner): return s.inventory.all.contains { $0.1.id == item && $0.1.owner == owner }
        case .inOwnCell: return playerInOwnCellLoose()
        case .stat(let k, let n): return (s.stats[k] ?? 0) >= n
        case .hiddenIn(let id): return s.player.hiddenIn == id
        case .docRead(let d): return s.docsRead.contains(d)
        case .hasJob: return s.player.job != nil
        case .shiftsWorked(let n): return s.shiftsWorked.values.reduce(0, +) >= n
        case .all(let cs): return cs.allSatisfy { eval($0) }
        case .any(let cs): return cs.contains { eval($0) }
        case .not(let c): return !eval(c)
        }
    }

    func anyStaffSeesPlayer() -> Bool {
        for n in s.npcs where n.present {
            let d = Cast.def(n.id)
            if d.role.isStaff && npcCanSeePlayer(n, d) { return true }
        }
        return false
    }

    // MARK: Effects

    public func apply(_ effects: [Effect], npc: NPCID? = nil) {
        for e in effects { apply(e, npc: npc) }
    }

    func apply(_ e: Effect, npc: NPCID?) {
        switch e {
        case .set(let f): setFlag(f)
        case .clear(let f): s.flags.remove(f)
        case .give(let i, let n):
            addItem(i, n, force: true)
            toast(Items.def(i).icon, "+\(n > 1 ? "\(n)× " : "")\(Items.def(i).name)")
            sound(.pickup, volume: 0.6)
        case .take(let i, let n):
            if removeItem(i, n) { toast(Items.def(i).icon, "−\(n > 1 ? "\(n)× " : "")\(Items.def(i).name)") }
        case .credits(let n, let why):
            if creditDelta(n, why) { toast(.coin, "\(n >= 0 ? "+" : "")\(n) credits") }
        case .trust(let n, let why): adjustTrust(n, why)
        case .staff(let id, let n): adjustStaff(id, n)
        case .peer(let id, let n): adjustPeer(id, n)
        case .favor(let id, let n):
            s.favors[id, default: 0] = max(0, s.favors[id, default: 0] + n)
            if n > 0 { toast(.favor, "\(Cast.def(id).short) owes you a favor") } else if n < 0 { toast(.favor, "Called in a favor with \(Cast.def(id).short)") }
        case .startQuest(let q): startQuest(q)
        case .stage(let q, let n): setStage(q, n)
        case .completeQuest(let q): completeQuest(q)
        case .failQuest(let q):
            s.quests[q, default: QuestProgress()].status = .failed
        case .minigame(let id, let key, let pass, let onPass, let onFail):
            startMinigame(id, key: key.replacingOccurrences(of: "{day}", with: "\(s.day)"), pass: pass, onPass: onPass, onFail: onFail, npc: npc)
        case .doc(let d): openDoc(d)
        case .bubble(let id, let icons): bubble(id, icons)
        case .toast(let icon, let text): toast(icon, text)
        case .caption(let text): ui.caption = text; ui.captionTime = 0
        case .setJob(let j): assignJob(j)
        case .watch(let level, let hours, let reason): setWatch(level, hours: hours, reason: reason)
        case .watch72(let reason):
            s.watch72 = true
            s.flags.remove(.watch72Reviewed)
            setWatch(.red, hours: 72, reason: reason)
            setFlag(.watch72Assigned)
            s.recovery = RecoveryTask(text: "Watch review: group, a clean shift, then Dr. Sato", npc: .sato, icon: .eye, fromIncident: .assault, day: s.day)
        case .incident(let k, let w):
            let outcome = applyConsequence(for: k, witness: w, searched: false)
            logIncident(k, witness: w, outcome: outcome)
        case .teleport(let spot):
            if let sp = map.spot(spot) {
                s.player.pos = sp.pos
                s.player.heading = sp.facing.angle
                s.player.path = []
                ui.camera = sp.pos
                ui.cameraSnap = true
                if let z = map.zone(at: sp.pos) { s.player.lastZone = z.id; s.player.lastDistrict = z.district }
            }
        case .advanceMinutes(let m): advanceTime(minutes: m)
        case .scene(let id): transition = Scenes.make(id, self)
        case .trade(let id):
            if let t = Trades.byID[id] { ui.modal = .trade(quote(t)) }
        case .sound(let sfx): sound(sfx)
        case .appointment(let id, let off, let start, let end, let title, let icon, let spot, let npcID, let quest):
            let day = s.day + off
            if !s.appointments.contains(where: { $0.id == id && $0.day == day && !$0.attended }) {
                s.appointments.append(Appointment(id: id, day: day, start: start, end: end, title: title, icon: icon, spot: spot, npc: npcID, quest: quest))
                toast(icon, "Scheduled: \(title) — \(off == 0 ? "today" : Schedule.dayName(day)) \(Schedule.clockString(Double(start)))")
            }
        case .wear(let o):
            s.player.outfit = o
            s.player.outfitCondition = 100
        case .energy(let d): s.player.energy = clamp(s.player.energy + d, 0, 100)
        case .condition(let d): s.player.outfitCondition = clamp(s.player.outfitCondition + d, 0, 100)
        case .reward(let key, let spec):
            if claimReward(key, spec, reason: "Reward") {
                if spec.credits != 0 { toast(.coin, "+\(spec.credits) credits") }
                for (i, n) in spec.items { toast(Items.def(i).icon, "+\(n > 1 ? "\(n)× " : "")\(Items.def(i).name)") }
            }
        case .restrict(let r, let hours):
            s.restrictions[r] = s.absMinute + Double(hours) * 60
            toast(.lock, "\(r.title) for \(hours)h", danger: true)
        case .lockdown(let on):
            s.lockdown = on
            if on { setFlag(.lockdownActive); toast(.lock, "Lockdown — everyone to their cells", danger: true); sound(.buzzer) } else { s.flags.remove(.lockdownActive) }
        case .npcGoto(let id, let spot):
            withNPC(id) { n in
                if spot.isEmpty {
                    n.scriptedSpot = nil
                    n.mode = .resume
                    n.postKey = ""
                } else {
                    n.scriptedSpot = spot
                    n.mode = .scripted
                    n.postKey = ""
                    n.present = true
                    if Cast.def(id).role == .lawyer || Cast.def(id).role == .family, let sp = self.map.spot(spot) {
                        n.pos = sp.pos
                    }
                }
            }
        case .npcFollowPlayer(let id, let on):
            withNPC(id) { n in n.followPlayer = on; if !on { n.mode = .resume; n.postKey = "" } }
        case .shakedown(let cell):
            _ = cell
            transition = Scenes.shakedown(self)
        case .ending(let en): startEnding(en)
        case .savePreFinale:
            setFlag(.preFinaleSaved)
            ui.preFinaleSaveRequested = true
        case .ifThen(let c, let a, let b): apply(eval(c) ? a : b, npc: npc)
        case .openCommissary: ui.modal = .commissary
        case .openStash(let id): ui.modal = .stash(id)
        case .cellAssign(let n):
            s.player.cell = n
            toast(.cellDoor, "Moved to cell F-\(n)")
        case .music(let mood):
            if let m = mood { audioCommands.append(.music(m)) } else { audioCommands.append(.duck(1)) }
        case .reviewWatch:
            setFlag(.watch72Reviewed)
            s.watch72 = false
            s.watch = .green
            s.watchUntil = 0
            s.recovery = nil
            emitWatchChanged()
            toast(.eye, "Watch review complete — back to green")
            sound(.success)
        case .choice(let c): ui.modal = .choice(c)
        case .lowerWatch(let level, let hours):
            s.watch72 = false
            if level < s.watch {
                s.watch = level
                s.watchUntil = level == .green ? 0 : s.absMinute + Double(hours) * 60
                emitWatchChanged()
                toast(.eye, "Watch lowered to \(level.short)")
            }
        case .keepAppointment(let id): markAppointmentAttended(id)
        case .vehicle(let v): setVehicle(v)
        case .meal: eatMeal()
        case .markDaily(let k): s.usedInteractions.insert("daily.\(k).d\(s.day)")
        case .call(let who):
            placeCall(who)
        case .visitor(let who, let spot):
            withNPC(who) { n in
                if spot.isEmpty { n.scriptedSpot = nil; n.present = false; n.mode = .routine } else if let sp = map.spot(spot) {
                    n.scriptedSpot = spot; n.pos = sp.pos; n.heading = sp.facing.angle; n.present = true; n.mode = .scripted; n.path = []
                }
            }
        case .concealedRide(let spot, let pusher): transition = Scenes.concealedRide(self, to: spot, pusher: pusher)
        case .sellDrawing(let fallback, let why): sellDrawing(fallback: fallback, reason: why)
        case .putInStash(let container, let item, let n):
            s.stashes[container, default: []].append(ItemStack(item, n))
        case .returnOwned(let item, let owner):
            for slot in Slot.allCases {
                var st = s.inventory.stacks(slot)
                if let i = st.firstIndex(where: { $0.id == item && $0.owner == owner }) {
                    st[i].qty -= 1
                    if st[i].qty <= 0 { st.remove(at: i) }
                    s.inventory.set(slot, st)
                    toast(Items.def(item).icon, "Returned \(Items.def(item).name.lowercased()) to \(Cast.def(owner).short)")
                    break
                }
            }
        }
    }

    func setFlag(_ f: Flag) {
        if !s.flags.contains(f) {
            s.flags.insert(f)
            emit(.flagSet(f))
        }
    }

    /// Skips time safely: never jumps past the next count without placing the player there.
    func advanceTime(minutes: Int) {
        var target = s.minute + Double(minutes)
        for c in countStarts where s.minute < c && target >= c - 4 {
            target = min(target, c - 4)
        }
        s.minute = min(target, 1439)
    }

    func assignJob(_ j: JobID?) {
        s.player.job = j
        if let j = j {
            let def = Jobs.def(j)
            setFlag(.workAssigned)
            toast(def.icon, "Assigned: \(def.title)")
            if let u = def.uniform, s.inventory.count(u.item) == 0 { addItem(u.item, 1, force: true) }
            if j == .janitorial && s.inventory.count(.janitorKey) == 0 { addItem(.janitorKey, 1, preferred: .pocket, force: true) }
            if j == .kitchen { setFlag(.kitchenWhitesIssued) }
            if j == .laundry { setFlag(.laundryWhitesIssued) }
            if j == .library { setFlag(.libraryCardIssued) }
            if j == .infirmary { setFlag(.ppeRouteKnown) }
        } else {
            toast(.work, "No job assignment")
        }
    }

    // MARK: Quests

    func startQuest(_ q: QuestID) {
        guard (s.quests[q]?.status ?? .inactive) == .inactive, let def = Quests.byID[q] else { return }
        s.quests[q] = QuestProgress(status: .active, stage: 0, startedDay: s.day, finishedDay: 0)
        if def.kind == .main { toast(def.icon, "Main: \(def.title)") } else { toast(def.icon, "New errand: \(def.title)") }
        emit(.questStarted(q))
        sound(.paper, volume: 0.6)
        log("Quest started: \(def.title)")
    }

    func setStage(_ q: QuestID, _ n: Int) {
        guard let def = Quests.byID[q] else { return }
        if (s.quests[q]?.status ?? .inactive) == .inactive { startQuest(q) }
        guard s.quests[q]?.status == .active else { return }
        if n >= def.stages.count { completeQuest(q); return }
        if n > (s.quests[q]?.stage ?? 0) {
            s.quests[q]?.stage = n
            sound(.paper, volume: 0.4)
        }
    }

    func completeQuest(_ q: QuestID) {
        guard let def = Quests.byID[q], s.quests[q]?.status != .done else { return }
        if s.quests[q] == nil { s.quests[q] = QuestProgress() }
        s.quests[q]?.status = .done
        let today = s.day
        s.quests[q]?.finishedDay = today
        toast(.star, "\(def.kind == .main ? "Done" : "Errand done"): \(def.title)")
        sound(.success)
        log("Quest done: \(def.title)")
        stat("quests.done")
        saveRequested = true
    }

    func checkQuests() {
        for def in Quests.all {
            let st = s.quests[def.id]?.status ?? .inactive
            if st == .inactive {
                if def.autoStart && eval(def.prerequisite) { startQuest(def.id) }
                continue
            }
            guard st == .active, var p = s.quests[def.id] else { continue }
            var guardN = 0
            while p.status == .active && p.stage < def.stages.count, let cw = def.stages[p.stage].completeWhen, eval(cw), guardN < 8 {
                guardN += 1
                let stage = def.stages[p.stage]
                apply(stage.onComplete)
                p = s.quests[def.id] ?? p
                if p.status != .active { break }
                if p.stage + 1 >= def.stages.count {
                    completeQuest(def.id)
                    p = s.quests[def.id] ?? p
                } else {
                    p.stage += 1
                    s.quests[def.id] = p
                    sound(.paper, volume: 0.4)
                }
            }
        }
    }

    public var activeMainQuest: (QuestDef, StageDef)? {
        for def in Quests.all where def.kind == .main {
            if let p = s.quests[def.id], p.status == .active, p.stage < def.stages.count { return (def, def.stages[p.stage]) }
        }
        return nil
    }

    public var activeMainQuests: [(QuestDef, StageDef)] {
        Quests.all.compactMap { def in
            guard def.kind == .main, let p = s.quests[def.id], p.status == .active, p.stage < def.stages.count else { return nil }
            return (def, def.stages[p.stage])
        }
    }

    public var activeSideQuests: [(QuestDef, StageDef)] {
        Quests.all.compactMap { def in
            guard def.kind == .side, let p = s.quests[def.id], p.status == .active, p.stage < def.stages.count else { return nil }
            return (def, def.stages[p.stage])
        }
    }

    /// The single prominent objective: recovery first, then appointments/count, then main quest.
    public var primaryObjective: (icon: Icon, text: String, marker: Marker?) {
        if isCountActive || (s.countState.warned && !s.countState.resolved && s.countState.activeDay == s.day && s.minute >= Double(s.countState.activeStart) - countWarningMinutes) {
            if !playerInOwnCell() { return (.count, "Count — get to cell F-\(s.player.cell)", .zone("fpod.cell\(s.player.cell)")) }
        }
        if activity == .lightsOut || (activity == .settle && s.minute >= 1280), !playerInOwnCellLoose() {
            return (.bed, "Back to cell F-\(s.player.cell)", .zone("fpod.cell\(s.player.cell)"))
        }
        if let ap = appointmentActive { return (ap.icon, ap.title, .spot(ap.spot)) }
        if let (_, st) = activeMainQuest { return (st.icon, st.objective, st.marker) }
        if let r = s.recovery { return (r.icon, r.text, .npc(r.npc)) }
        return (Schedule.icon(activity), activity.title, nil)
    }

    // MARK: Docs & choices

    public func openDoc(_ d: DocID) {
        ui.modal = .doc(d)
        if !s.docsRead.contains(d) {
            s.docsRead.insert(d)
            emit(.docRead(d))
        }
        sound(.paper)
    }

    public func choose(_ c: ChoiceID, option index: Int) {
        guard let def = Choices.byID[c], index < def.options.count else { return }
        let opt = def.options[index]
        guard eval(opt.when) else { return }
        ui.modal = nil
        apply(opt.effects)
        log("Choice \(c.rawValue): \(opt.label)")
        processEvents()
    }
}
