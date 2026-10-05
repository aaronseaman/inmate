import Foundation

extension Game {
    public var countWarningMinutes: Double { 3 }
    public var countGraceMinutes: Double { 2 }

    func updateSchedule() {
        let block = currentBlock
        if lastBlock != block.activity || lastBlockDay != s.day {
            let previous = lastBlock
            lastBlock = block.activity
            lastBlockDay = s.day
            onBlockStart(block, previous: previous)
        }
        updateCount()
        updateLightsOut()
        updateAppointments()
        updateWatchExpiry()
    }

    func onBlockStart(_ b: ScheduleBlock, previous: Activity?) {
        emit(.blockStarted(b.activity))
        for i in s.npcs.indices { s.npcs[i].postKey = ""; s.npcs[i].repathTimer = s.rng.double(0, 2.5) }
        // Missed shift bookkeeping for the block that just ended.
        if let prev = previous, let job = s.player.job, prev == .work || prev == .afternoon {
            let key = "d\(s.day).\(prev.rawValue)"
            if !s.shiftDoneKeys.contains(key) && (s.restrictions[.noJob].map { $0 <= s.absMinute } ?? true) && s.day > 1 {
                logIncident(.missedShift, witness: Jobs.def(job).supervisor, outcome: "Shift marked absent")
                adjustStaff(Jobs.def(job).supervisor, -3)
                adjustTrust(-2, "Missed shift")
                toast(.work, "Missed your \(Jobs.def(job).title.lowercased()) shift", danger: true)
            }
        }
        switch b.activity {
        case .wakeCount, .eveningCount:
            sound(.buzzer)
            haptic(.warning)
        case .lightsOut:
            sound(.buzzer, volume: 0.6)
            toast(.moon, "Lights out — sleep at your bunk")
        case .sleep:
            break
        default:
            sound(.chime, volume: 0.7)
            toast(Schedule.icon(b.activity), "\(b.activity.title) · \(Schedule.clockString(Double(b.start)))–\(Schedule.clockString(Double(b.end)))")
        }
        if b.activity == .rec { audioCommands.append(.music(.day)) }
        if b.activity == .freeTime || b.activity == .settle { audioCommands.append(.music(.night)) }
        if b.activity == .medPass && s.day == 1 {
            // Med pass is the first story decision of the day.
        }
    }

    // MARK: Count

    var isCountActive: Bool { activity.isCount }

    func playerInOwnCell() -> Bool {
        guard s.player.hiddenIn == nil || (s.player.hiddenIn?.hasPrefix("fpod.cell\(s.player.cell).") ?? false) else { return false }
        return map.zone(at: s.player.pos)?.id == "fpod.cell\(s.player.cell)"
    }

    /// Count blocks for today (story days can move them).
    var countStarts: [Double] {
        Schedule.blocks(day: s.day, storyOverrides: s.storyOverrides[s.day] ?? []).filter { $0.activity.isCount }.map { Double($0.start) }
    }

    func updateCount() {
        let m = s.minute
        for start in countStarts {
            // Warning
            if m >= start - countWarningMinutes && m < start && !(s.countState.activeDay == s.day && s.countState.activeStart == Int(start)) {
                s.countState = CountState(activeDay: s.day, activeStart: Int(start), warned: true, resolved: false, present: false)
                sound(.chime)
                haptic(.warning)
                toast(.count, "Count in 3 minutes — get to cell F-\(s.player.cell)", danger: !playerInOwnCell())
            }
        }
        guard isCountActive else { return }
        let start = Double(currentBlock.start)
        if !(s.countState.activeDay == s.day && s.countState.activeStart == Int(start)) {
            s.countState = CountState(activeDay: s.day, activeStart: Int(start), warned: true, resolved: false, present: false)
        }
        if s.countState.resolved { return }
        let inCell = playerInOwnCell()
        if m >= start + countGraceMinutes {
            s.countState.resolved = true
            if inCell {
                s.countState.present = true
                countCleared(late: false)
            } else {
                countMissed()
            }
        } else if inCell && m >= start {
            s.countState.present = true
        }
    }

    func countCleared(late: Bool) {
        emit(.countCleared)
        if !has(.firstCountDone) { setFlag(.firstCountDone) }
        sound(.success, volume: 0.5)
        if late {
            logIncident(.lateCount, witness: countOfficer, outcome: "Recounted; noted as late")
            adjustStaff(countOfficer, -2)
            toast(.count, "Recounted — late, but present")
        } else {
            toast(.check, "Count clear")
            adjustTrust(1, "Present for count")
        }
    }

    var countOfficer: NPCID { s.minute < 840 ? .haskins : .reed }

    func countMissed() {
        emit(.countMissed)
        s.missedCounts.append(s.day)
        s.facilityAlert = min(3, s.facilityAlert + 1.2)
        toast(.count, "Missed count — staff are looking for you", danger: true)
        haptic(.error)
        sound(.alert)
        log("Missed count")
        // Staff search starts from the pod, not from the player's position.
        for id in [countOfficer, NPCID.strick] {
            withNPC(id) { n in
                guard n.present else { return }
                n.mode = .investigate
                n.suspicion = max(n.suspicion, 70)
                n.questionReason = .missedCount
                n.lastKnown = self.map.spot("fpod.center")?.pos
                n.path = []
                n.modeTimer = 0
            }
        }
        s.countState.present = false
    }

    /// Called when the player walks into their own cell while a missed-count search is on.
    func checkLateReturn() {
        guard s.countState.resolved, !s.countState.present, s.countState.activeDay == s.day else { return }
        guard playerInOwnCell() else { return }
        s.countState.present = true
        s.countState.lateLogged = true
        countCleared(late: true)
        endSearches(reason: .missedCount)
    }

    func endSearches(reason: IncidentKind) {
        for i in s.npcs.indices where s.npcs[i].questionReason == reason {
            s.npcs[i].mode = .resume
            s.npcs[i].suspicion = min(s.npcs[i].suspicion, 20)
            s.npcs[i].questionReason = nil
            s.npcs[i].path = []
            s.npcs[i].postKey = ""
        }
    }

    // MARK: Lights out & sleep

    func updateLightsOut() {
        guard activity == .lightsOut else { return }
        if s.minute >= 1410 {
            if playerInOwnCell() || s.player.hiddenIn?.hasPrefix("fpod.cell\(s.player.cell)") == true {
                goToSleep()
            } else if s.countState.activeStart != 1410 {
                s.countState.activeStart = 1410
                // Out after lights out: escorted back, then sleep.
                logIncident(.curfew, witness: .reed, outcome: "Escorted to cell")
                applyConsequence(for: .curfew, witness: .reed, searched: false)
                goToSleep()
            }
        }
    }

    public func canSleepNow() -> Bool {
        (activity == .lightsOut || activity == .settle || (activity == .freeTime && s.minute >= 1200)) && playerInOwnCellLoose()
    }

    func playerInOwnCellLoose() -> Bool { map.zone(at: s.player.pos)?.id == "fpod.cell\(s.player.cell)" || s.player.hiddenIn?.hasPrefix("fpod.cell\(s.player.cell)") == true }

    func goToSleep() {
        guard transition == nil else { return }
        transition = Scenes.sleep(self)
    }

    /// Advances to the next morning. Called by the sleep scene.
    func startNewDay() {
        s.day += 1
        s.minute = 355
        s.tradesToday = [:]
        s.purchasesToday = 0
        s.trustGainedToday = 0
        s.mealsToday = 0
        s.player.energy = min(100, max(s.player.energy, 40) + 50)
        // Med pass is a daily decision.
        s.flags.remove(.tookMeds)
        s.flags.remove(.medDeclined)
        s.player.hiddenIn = nil
        s.player.path = []
        s.player.mode = .walk
        s.player.escortedBy = nil
        s.player.vehicle = nil
        s.player.changing = 0
        s.facilityAlert = 0
        s.lockdown = false
        if let sp = map.spot("fpod.cell\(s.player.cell).bunkA") { s.player.pos = sp.pos }
        // Radio upkeep: a radio drains batteries every two days.
        if s.inventory.count(.radio) > 0 || (s.stashes["fpod.cell\(s.player.cell).locker"]?.contains { $0.id == .radio } ?? false) {
            s.batteryDays += 1
            if s.batteryDays >= 2 {
                s.batteryDays = 0
                if removeItem(.batteries, 1) { toast(.battery, "Radio used a pair of batteries") } else { toast(.radio, "Radio's dead — needs batteries (2 cr)") }
            }
        }
        for i in s.npcs.indices {
            let def = Cast.def(s.npcs[i].id)
            s.npcs[i].mode = .routine
            s.npcs[i].suspicion = 0
            s.npcs[i].lastKnown = nil
            s.npcs[i].path = []
            s.npcs[i].postKey = ""
            s.npcs[i].recognizedDisguise = false
            s.npcs[i].questionReason = nil
            s.npcs[i].followPlayer = false
            s.npcs[i].scriptedSpot = nil
            if let c = def.cell, let sp = map.spot("fpod.cell\(c).bunk\(def.bunk == 0 ? "A" : "B")") { s.npcs[i].pos = sp.pos }
        }
        s.restrictions = s.restrictions.filter { $0.value > s.absMinute }
        let today = s.day
        s.appointments.removeAll { $0.day < today - 1 }
        lastBlock = nil
        emit(.dayStarted(s.day))
        reviewNightFootage()
        dailyStoryHooks()
        refreshDoors(instant: true)
        ui.camera = s.player.pos
        saveRequested = true
    }

    // MARK: Appointments

    func updateAppointments() {
        stageAppointments()
        let m = Int(s.minute)
        for i in s.appointments.indices {
            let ap = s.appointments[i]
            guard ap.day == s.day, !ap.attended else { continue }
            let key = "appt.warn.\(ap.id).\(ap.day)"
            if m >= ap.start - 15 && m < ap.start && !s.usedInteractions.contains(key) {
                s.usedInteractions.insert(key)
                toast(ap.icon, "\(ap.title) at \(Schedule.clockString(Double(ap.start)))")
                sound(.chime, volume: 0.6)
            }
            if m >= ap.end {
                // Missed appointments are rescheduled, never lost.
                let missKey = "appt.miss.\(ap.id).\(ap.day)"
                if !s.usedInteractions.contains(missKey) {
                    s.usedInteractions.insert(missKey)
                    var next = ap
                    next.day = s.day + 1
                    s.appointments.append(next)
                    toast(ap.icon, "Missed: \(ap.title). Rescheduled for tomorrow.")
                }
            }
        }
    }

    public func markAppointmentAttended(_ id: String) {
        for i in s.appointments.indices where s.appointments[i].id == id && s.appointments[i].day == s.day {
            s.appointments[i].attended = true
        }
    }

    // MARK: Watch

    func updateWatchExpiry() {
        let now = s.absMinute
        if s.watch != .green && now >= s.watchUntil {
            // A 72-hour watch ends on time even without a review; the review only ends it sooner.
            if s.watch72 { setFlag(.watch72Reviewed); s.watchReviewProgress = 0 }
            let was = s.watch
            s.watch = was == .red ? .yellow : .green
            s.watchUntil = was == .red ? now + 12 * 60 : 0
            s.watch72 = false
            toast(.eye, "Watch lowered to \(s.watch.short)")
            emitWatchChanged()
        }
        for (r, until) in s.restrictions where until <= now {
            s.restrictions[r] = nil
            toast(.check, "\(r.title) lifted")
        }
    }

    func emitWatchChanged() {
        for i in s.npcs.indices {
            s.npcs[i].postKey = ""
            if s.watch != .red && s.npcs[i].followPlayer {
                s.npcs[i].followPlayer = false
                s.npcs[i].mode = .resume
            }
        }
    }

    public var watchHoursLeft: Double { max(0, (s.watchUntil - s.absMinute) / 60) }

    func setWatch(_ level: WatchLevel, hours: Int, reason: String) {
        let until = s.absMinute + Double(hours) * 60
        if level > s.watch || (level == s.watch && until > s.watchUntil) {
            s.watch = level
            s.watchUntil = until
            s.watchReason = reason
            toast(.eye, "Watch: \(level.short) for \(hours)h — \(reason)", danger: level == .red)
            emitWatchChanged()
            log("Watch \(level.short) \(hours)h: \(reason)")
        }
    }

    func dailyStoryHooks() {
        Story.dailyHooks(self)
    }
}

extension Game {
    /// Group, a clean count and a worked shift each count toward an early watch review.
    public static let watchReviewNeeded = 3

    func noteWatchProgress(_ what: String) {
        guard s.watch72 else { return }
        let key = "watchprog.\(what).d\(s.day)"
        guard !s.usedInteractions.contains(key) else { return }
        s.usedInteractions.insert(key)
        s.watchReviewProgress = min(Game.watchReviewNeeded, s.watchReviewProgress + 1)
        toast(.eye, s.watchReviewProgress >= Game.watchReviewNeeded ? "Early review available — see Dr. Sato" : "Review progress \(s.watchReviewProgress)/\(Game.watchReviewNeeded)")
    }

    public var watchReviewReady: Bool { s.watch72 && s.watchReviewProgress >= Game.watchReviewNeeded }

    /// Cameras record when nobody is at the monitors; Lt. Gaines reviews the night's
    /// footage in the morning. Plausible roles pass; unexplained presence is noted.
    func reviewNightFootage() {
        guard let footage = s.footage, !footage.isEmpty else { return }
        s.footage = nil
        let places = Array(Set(footage)).sorted().prefix(2).joined(separator: ", ")
        let outcome = applyConsequence(for: .restrictedArea, witness: .gaines, searched: false)
        logIncident(.restrictedArea, witness: .gaines, outcome: "Night footage: \(places). \(outcome)")
        toast(.camera, "Night footage reviewed: you were seen in \(places)", danger: true)
    }
}
