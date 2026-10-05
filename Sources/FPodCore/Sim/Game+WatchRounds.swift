import Foundation

/// Yellow watch "closer rounds": a floor officer comes to see the player at intervals.
public struct WatchCheckState: Codable, Equatable {
    /// Absolute game minute the next check starts.
    public var nextAt: Double
    /// Staff member on the way, while a check is in progress.
    public var by: NPCID?
    public var startedAt: Double?
    public var passed: Int
    public var missed: Int

    public init(nextAt: Double) {
        self.nextAt = nextAt
        self.by = nil
        self.startedAt = nil
        self.passed = 0
        self.missed = 0
    }
}

extension Game {
    /// Game minutes between checks, and how long the checker has to lay eyes on the player.
    public static let watchCheckInterval = 50.0
    public static let watchCheckWindow = 30.0
    /// Missing this many checks during one yellow watch raises it to red.
    public static let watchCheckMissesToRed = 2

    static let watchCheckRoles: Set<Role> = [.co, .tech, .nurse]

    /// Game minutes a checker has; never under ~30 real seconds at fast clock settings.
    var watchCheckWindowMinutes: Double { Game.watchCheckWindow * max(1, settings.clockRate) }

    var watchChecksPaused: Bool {
        transition != nil || s.player.escortedBy != nil || activity == .lightsOut || activity.isCount
            || map.zone(at: s.player.pos)?.cls == .isolation
    }

    func updateWatchChecks() {
        guard s.watch == .yellow else {
            if let by = s.watchCheck?.by { releaseChecker(by) }
            s.watchCheck = nil
            return
        }
        let now = s.absMinute
        var wc = s.watchCheck ?? WatchCheckState(nextAt: now + 15)
        if let by = wc.by, let started = wc.startedAt {
            if watchChecksPaused {
                // A count, a scene or an escort supersedes the check; no penalty.
                releaseChecker(by)
                wc.by = nil; wc.startedAt = nil; wc.nextAt = now + 10
                s.watchCheck = wc
                return
            }
            guard let n = npc(by), n.present else {
                // The checker went off shift; someone else will come.
                wc.by = nil; wc.startedAt = nil; wc.nextAt = now + 5
                s.watchCheck = wc
                return
            }
            if s.player.hiddenIn == nil && n.pos.distance(to: s.player.pos) < 4.5 && npcCanSeePlayer(n, Cast.def(by)) {
                wc.passed += 1
                wc.by = nil; wc.startedAt = nil
                wc.nextAt = now + Game.watchCheckInterval + jitter(wc)
                withNPC(by) { m in m.attendCome = false; m.attendTimer = min(m.attendTimer, 1.5) }
                bubble(by, [.clipboard, .check], seconds: 2.2, caption: "Seen. Carry on.")
                stat("watchChecksPassed")
            } else if now - started > watchCheckWindowMinutes {
                wc.by = nil; wc.startedAt = nil
                s.watchCheck = wc
                missWatchCheck(by: by)
                return
            }
            s.watchCheck = wc
            return
        }
        guard now >= wc.nextAt else { s.watchCheck = wc; return }
        if watchChecksPaused { wc.nextAt = now + 5; s.watchCheck = wc; return }
        if let by = pickWatchChecker() {
            wc.by = by
            wc.startedAt = now
            s.watchCheck = wc
            withNPC(by) { m in
                m.attendTimer = watchCheckWindowMinutes / max(0.1, settings.clockRate) + 4
                m.attendCome = true
                m.attendTotal = 0
                m.repathTimer = 0
            }
            bubble(by, [.eye, .clipboard], seconds: 2.4, caption: "Watch check.")
            toast(.eye, "Watch check: \(Cast.def(by).name) is coming to see you")
        } else {
            // Nobody on the floor nearby: the check comes over the intercom.
            wc.nextAt = now + Game.watchCheckInterval + jitter(wc)
            s.watchCheck = wc
            if s.player.hiddenIn != nil {
                missWatchCheck(by: nil)
            } else {
                toast(.bell, "Intercom watch check: you answered")
                wc.passed += 1
                s.watchCheck = wc
            }
        }
    }

    func jitter(_ wc: WatchCheckState) -> Double {
        Double(stableHash("wc\(s.seed)\(s.day)\(wc.passed + wc.missed)") % 15)
    }

    /// Nearest free floor officer, preferring one already in the player's district.
    func pickWatchChecker() -> NPCID? {
        let district = map.zone(at: s.player.pos)?.district
        var best: (NPCID, Double)?
        for n in s.npcs where n.present && !n.followPlayer && n.attendTimer <= 0 {
            let def = Cast.def(n.id)
            guard Game.watchCheckRoles.contains(def.role), n.mode == .routine || n.mode == .resume else { continue }
            let d = n.pos.distance(to: s.player.pos)
            guard d < 45 else { continue }
            let score = d + (map.zone(at: n.pos)?.district == district ? 0 : 15)
            if score < (best?.1 ?? .infinity) { best = (n.id, score) }
        }
        return best?.0
    }

    func releaseChecker(_ id: NPCID) {
        withNPC(id) { m in m.attendCome = false; m.attendTimer = 0; m.postKey = "" }
    }

    func missWatchCheck(by: NPCID?) {
        var wc = s.watchCheck ?? WatchCheckState(nextAt: s.absMinute)
        wc.missed += 1
        wc.nextAt = s.absMinute + Game.watchCheckInterval * 0.6
        s.watchCheck = wc
        logIncident(.missedWatchCheck, witness: by, outcome: wc.missed >= Game.watchCheckMissesToRed ? "Raised to red watch" : "Yellow watch extended")
        haptic(.warning)
        if let id = by {
            // They go looking where they expected to find you.
            withNPC(id) { m in
                m.attendCome = false; m.attendTimer = 0
                m.suspicion = max(m.suspicion, 50)
                m.lastKnown = s.player.hideReturn ?? s.player.pos
                m.mode = .investigate
                m.modeTimer = 0
                m.path = []
            }
            bubble(id, [.question, .eye], seconds: 2.4, caption: "Merritt? Where'd you go?")
        }
        if wc.missed >= Game.watchCheckMissesToRed {
            setWatch(.red, hours: 12, reason: "Missed watch checks")
        } else {
            s.watchUntil = max(s.watchUntil, s.absMinute + 6 * 60)
            toast(.eye, "Missed a watch check — yellow watch extended", danger: true)
        }
        adjustTrust(-1, "Missed watch check")
    }
}
