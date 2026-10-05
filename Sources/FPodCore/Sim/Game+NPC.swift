import Foundation

extension Game {
    static let staffEntry = "corridor.e"

    func updateNPCs(_ dt: Double) {
        for i in s.npcs.indices {
            var n = s.npcs[i]
            let def = Cast.def(n.id)
            updatePresence(&n, def)
            if n.present {
                stepAI(&n, def, dt)
                moveAlongPath(&n, def, dt)
            }
            if s.player.escortedBy == n.id {
                if escortTrail.last.map({ $0.distance(to: n.pos) > 0.25 }) ?? true { escortTrail.append(n.pos) }
            }
            if n.bubbleTimer > 0 {
                n.bubbleTimer -= dt
                if n.bubbleTimer <= 0 { n.bubble = []; n.bubbleCaption = "" }
            }
            s.npcs[i] = n
        }
    }

    // MARK: Presence

    func onShift(_ def: NPCDef) -> Bool {
        guard let sh = def.shift else { return def.role == .peer }
        let m = Int(s.minute)
        return m >= sh.start && m < sh.end
    }

    func updatePresence(_ n: inout NPCState, _ def: NPCDef) {
        if def.role == .lawyer || def.role == .family {
            n.present = n.scriptedSpot != nil
            return
        }
        let busy = n.mode == .pursue || n.mode == .escort || n.mode == .question || n.mode == .inspect || n.mode == .scripted
        if onShift(def) {
            if !n.present {
                n.present = true
                let entry = entrySpot(for: def)
                n.pos = map.spot(entry)?.pos ?? n.pos
                n.path = []
                n.postKey = ""
                n.mode = .routine
                n.suspicion = 0
            }
        } else if n.present && def.role.isStaff && !busy {
            // Walk out, then leave.
            let exit = map.spot(entrySpot(for: def))?.pos ?? n.pos
            if n.pos.distance(to: exit) < 1.2 || !isOnScreen(n.pos) && n.pos.distance(to: s.player.pos) > 20 {
                n.present = false
                n.path = []
            } else if n.postKey != "exit" {
                n.postKey = "exit"
                setGoal(&n, def, exit, facing: nil)
            }
        }
    }

    func entrySpot(for def: NPCDef) -> String {
        switch def.role {
        case .maintenance: return "tunnels.patrol.1"
        case .k9: return "k9.a"
        case .lieutenant: return "control.seat"
        default: return Game.staffEntry
        }
    }

    func isOnScreen(_ p: Vec2) -> Bool {
        let half = viewport.size / (2 * settings.zoom)
        return abs(p.x - ui.camera.x) < half.x + 2 && abs(p.y - ui.camera.y) < half.y + 2
    }

    // MARK: Posts

    func currentPost(_ n: NPCState, _ def: NPCDef) -> Post {
        if let sp = n.scriptedSpot { return .spot(sp) }
        if let p = def.posts[activity] { return p }
        return def.fallback
    }

    /// Resolves a post into a concrete target and a key identifying it.
    func resolvePost(_ post: Post, _ n: NPCState, _ def: NPCDef) -> (pos: Vec2, facing: Facing?, key: String)? {
        switch post {
        case .offsite: return nil
        case .spot(let id):
            guard let sp = map.spot(id) else { return nil }
            return (sp.pos, sp.facing, "spot:\(id)")
        case .patrol(let ids):
            guard !ids.isEmpty else { return nil }
            let id = ids[n.patrolIndex % ids.count]
            guard let sp = map.spot(id) else { return nil }
            return (sp.pos, sp.facing, "patrol:\(id):\(n.patrolIndex)")
        case .cellCount:
            guard let c = def.cell, let sp = map.spot("fpod.cell\(c).count") else { return nil }
            let off = def.bunk == 0 ? Vec2(0, 0) : Vec2(-1.0, 0)
            return (sp.pos + off, sp.facing, "count:\(c):\(def.bunk)")
        case .bunk:
            guard let c = def.cell, let sp = map.spot("fpod.cell\(c).bunk\(def.bunk == 0 ? "A" : "B")") else { return nil }
            return (sp.pos, .left, "bunk:\(c):\(def.bunk)")
        case .medLine:
            let order = Cast.peerIDs.firstIndex(of: def.id) ?? 0
            let p = Vec2(18.5 + Double(order), order % 2 == 0 ? 56.5 : 57.4)
            return (p, .left, "med:\(order)")
        case .jobSite:
            let spots = def.jobSpots
            guard !spots.isEmpty else { return resolvePost(def.fallback, n, def) }
            let idx = (Int(s.minute) / 25 + Int(stableHash(def.id.rawValue) % 3)) % spots.count
            guard let sp = map.spot(spots[idx]) else { return nil }
            return (sp.pos, sp.facing, "job:\(spots[idx])")
        }
    }

    // MARK: Routine AI

    func stepAI(_ n: inout NPCState, _ def: NPCDef, _ dt: Double) {
        n.modeTimer += dt
        switch n.mode {
        case .routine, .resume, .count:
            routine(&n, def, dt)
        case .notice:
            n.path = []
            faceToward(&n, s.player.pos, dt)
        case .approach:
            n.repathTimer -= dt
            if n.repathTimer <= 0 {
                n.repathTimer = 0.6
                setGoal(&n, def, s.player.pos, facing: nil, force: true)
            }
            if n.pos.distance(to: s.player.pos) < 1.4 { n.path = [] }
        case .question:
            n.path = []
            faceToward(&n, s.player.pos, dt)
            n.questionTimer -= dt
        case .investigate:
            guard let lk = n.lastKnown else { n.mode = .resume; return }
            if n.path.isEmpty {
                if n.pos.distance(to: lk) < 1.3 || n.modeTimer > 12 {
                    n.mode = .search
                    n.modeTimer = 0
                    n.searchedSpots = []
                    setBubble(&n, [.search], 2)
                } else if n.goal == nil || (n.goal! - lk).length > 0.5 || n.stuckTimer > 1.5 {
                    setGoal(&n, def, lk, facing: nil, force: true)
                    if n.path.isEmpty { n.mode = .search; n.modeTimer = 0 }
                }
            }
        case .search:
            // Look around, then inspect plausible hiding spots near the last known position.
            n.heading += dt * 2.2 * (n.modeTimer.truncatingRemainder(dividingBy: 2) < 1 ? 1 : -1)
            if n.modeTimer > 2.2 {
                if let spot = nextHideToInspect(n) {
                    n.inspectTarget = spot
                    n.searchedSpots.append(spot)
                    n.mode = .inspect
                    n.modeTimer = 0
                    if let o = map.object(id: spot) {
                        let tiles = map.approachTiles(for: o)
                        if let t = tiles.min(by: { $0.center.distance(to: n.pos) < $1.center.distance(to: n.pos) }) {
                            setGoal(&n, def, t.center, facing: nil, force: true)
                        }
                    }
                } else {
                    n.mode = .resume
                    n.suspicion = min(n.suspicion, 35)
                    n.lastKnown = nil
                    n.postKey = ""
                    n.radioed = false
                    setBubble(&n, [.question], 1.5)
                }
            }
        case .inspect:
            guard let spot = n.inspectTarget, let o = map.object(id: spot) else { n.mode = .search; n.modeTimer = 0; return }
            if n.path.isEmpty {
                faceToward(&n, o.center, dt)
                if n.modeTimer > 0.4 && n.bubble != [.search] { setBubble(&n, [.search], 1.6) }
                if n.modeTimer > 1.6 || o.rect.rect.distance(to: n.pos) < 1.6 && n.modeTimer > 1.2 {
                    resolveInspection(&n, def, spot)
                }
            } else if n.modeTimer > 10 {
                n.mode = .search
                n.modeTimer = 0
            }
        case .pursue:
            n.repathTimer -= dt
            let canSee = npcCanSeePlayer(n, def)
            let target = canSee ? s.player.pos : (n.lastKnown ?? s.player.pos)
            if n.repathTimer <= 0 {
                n.repathTimer = 0.4
                setGoal(&n, def, target, facing: nil, force: true)
            }
            if canSee && n.pos.distance(to: s.player.pos) < 0.9 && s.player.hiddenIn == nil {
                let reason = n.questionReason ?? .fleeing
                captured(by: n.id, reason: reason)
                return
            }
            if !canSee && (n.path.isEmpty || n.modeTimer > 14) {
                n.mode = .search
                n.modeTimer = 0
                n.searchedSpots = []
                n.suspicion = 80
            }
        case .escort:
            if n.path.isEmpty {
                n.mode = .resume
                n.postKey = ""
                if s.player.escortedBy == n.id { finishEscort(n.id) }
            }
        case .scripted:
            if let sp = n.scriptedSpot, let spot = map.spot(sp) {
                if n.path.isEmpty && n.pos.distance(to: spot.pos) > 0.3 && n.postKey != "scripted:\(sp)" {
                    n.postKey = "scripted:\(sp)"
                    setGoal(&n, def, spot.pos, facing: spot.facing, force: true)
                }
            }
        case .follow:
            let d = n.pos.distance(to: s.player.pos)
            n.repathTimer -= dt
            if d > 2.5 && n.repathTimer <= 0 {
                n.repathTimer = 0.8
                setGoal(&n, def, s.player.pos, facing: nil, force: true)
            } else if d < 1.6 {
                n.path = []
                faceToward(&n, s.player.pos, dt)
            }
        }
    }

    func routine(_ n: inout NPCState, _ def: NPCDef, _ dt: Double) {
        if n.followPlayer {
            n.mode = .follow
            return
        }
        if n.attendTimer > 0 {
            n.attendTimer -= dt
            n.attendTotal += dt
            let d = n.pos.distance(to: s.player.pos)
            if n.attendCome && d > 1.0 {
                n.repathTimer -= dt
                if n.repathTimer <= 0 || n.path.isEmpty {
                    n.repathTimer = 0.7
                    let dir = (n.pos - s.player.pos).normalized
                    let meet = s.player.pos + (dir.lengthSquared > 0 ? dir : Vec2(0, -1)) * 0.8
                    setGoal(&n, def, meet, facing: nil, force: true)
                }
            } else {
                n.path = []
                faceToward(&n, s.player.pos, dt)
            }
            if n.attendTimer <= 0 { n.attendCome = false; n.postKey = ""; n.attendTotal = 0 }
            return
        }
        if n.repathTimer > 0 { n.repathTimer -= dt; return }
        if n.postKey == "exit" { return }
        let post = currentPost(n, def)
        guard let target = resolvePost(post, n, def) else {
            n.path = []
            return
        }
        if target.key != n.postKey {
            n.postKey = target.key
            setGoal(&n, def, target.pos, facing: target.facing)
            n.waitTimer = 0
            n.stuckTimer = 0
            return
        }
        if n.path.isEmpty {
            let arrived = n.pos.distance(to: target.pos) < 0.6
            if arrived {
                if let f = target.facing { n.heading = approachAngle(n.heading, f.angle, dt * 4) }
                if case .patrol(let ids) = post {
                    n.waitTimer += dt
                    let dwell = 2.0 + Double(stableHash("\(def.id.rawValue)\(n.patrolIndex)") % 40) / 10.0
                    if n.waitTimer > dwell {
                        n.waitTimer = 0
                        n.patrolIndex = (n.patrolIndex + 1) % max(1, ids.count)
                    }
                }
                if n.mode == .resume { n.mode = .routine }
                // Ambient mumbles and pictograms.
                n.mumbleTimer -= dt
                if n.mumbleTimer <= 0 {
                    n.mumbleTimer = 14 + Double(stableHash("\(def.id)\(Int(s.minute))") % 20)
                    ambientChatter(&n, def)
                }
            } else {
                n.stuckTimer += dt
                if n.stuckTimer > 2.0 {
                    n.stuckTimer = 0
                    let ok = setGoal(&n, def, target.pos, facing: target.facing, force: true)
                    if !ok {
                        n.failCount += 1
                        if n.failCount > 6 && !isOnScreen(n.pos) && !isOnScreen(target.pos) {
                            // Keep schedules intact offscreen.
                            n.pos = target.pos
                            n.failCount = 0
                        }
                    } else { n.failCount = 0 }
                }
            }
        }
    }

    func ambientChatter(_ n: inout NPCState, _ def: NPCDef) {
        guard isOnScreen(n.pos) else { return }
        if def.role == .peer {
            var opts: [[Icon]] = [[.happy], [.music], [.zzz], [.question]]
            if let w = def.wants.first { opts.append([Items.def(w).icon, .question]) }
            if activity.isCount { opts = [[.count]] }
            if activity == .rec { opts.append([.ball]) }
            let pick = opts[Int(stableHash("\(def.id)\(s.day)\(Int(s.minute))") % UInt64(opts.count))]
            setBubble(&n, pick, 2.2)
            mumble(def.id)
        } else if def.role.isStaff && activity.isCount && def.role == .co {
            setBubble(&n, [.count], 2.0)
        }
    }

    // MARK: Movement

    @discardableResult
    func setGoal(_ n: inout NPCState, _ def: NPCDef, _ target: Vec2, facing: Facing?, force: Bool = false) -> Bool {
        if !force, let g = n.goal, (g - target).length < 0.2, !n.path.isEmpty { return true }
        n.goal = target
        n.goalFacing = facing
        let start = n.pos.tile
        guard let goalTile = map.nearestWalkable(target.tile, maxRadius: 3) else { n.path = []; return false }
        guard let tiles = Navigation.findPath(map, from: start, to: goalTile, canPass: { self.npcCanPassTile($0, def) }) else {
            n.path = []
            return false
        }
        var wps = Navigation.waypoints(map, tiles)
        if wps.count > 1 { wps.removeFirst() }
        if goalTile == target.tile, map.walkableStatic(target.tile) {
            if wps.isEmpty { wps = [target] } else { wps[wps.count - 1] = target }
        }
        n.path = wps
        n.pathIndex = 0
        return true
    }

    func npcSpeed(_ n: NPCState, _ def: NPCDef) -> Double {
        var base: Double
        switch n.mode {
        case .pursue: base = 3.9
        case .approach: base = 2.4
        case .investigate: base = 2.3
        case .escort: base = 2.0
        case .inspect: base = 2.0
        case .follow: base = 2.4
        default: base = 2.1
        }
        if Cast.def(n.id).role == .peer && n.id == .abe { base = 1.3 }
        return base * def.pace
    }

    func moveAlongPath(_ n: inout NPCState, _ def: NPCDef, _ dt: Double) {
        guard n.pathIndex < n.path.count else {
            n.moving = false
            n.path = []
            n.pathIndex = 0
            return
        }
        var remaining = npcSpeed(n, def) * dt
        var moved = 0.0
        while remaining > 0 && n.pathIndex < n.path.count {
            let t = n.path[n.pathIndex]
            let d = t - n.pos
            let len = d.length
            // Respect doors that locked since planning.
            let nextTile = (n.pos + d.normalized * min(len, 0.45)).tile
            if nextTile != n.pos.tile && map.inBounds(nextTile) && !npcCanPassTile(map.idx(nextTile), def) {
                n.path = []
                n.pathIndex = 0
                n.repathTimer = 1.5
                break
            }
            if len > 1e-4 { n.heading = approachAngle(n.heading, d.angle, dt * 10) }
            if len <= remaining {
                n.pos = t
                remaining -= len
                moved += len
                n.pathIndex += 1
            } else {
                n.pos = n.pos + d / len * remaining
                moved += remaining
                remaining = 0
            }
        }
        if n.pathIndex >= n.path.count {
            n.path = []
            n.pathIndex = 0
            if let f = n.goalFacing { n.heading = f.angle }
        }
        n.moving = moved > 1e-4
        n.running = n.mode == .pursue
        n.animPhase += moved * 1.7
    }

    func faceToward(_ n: inout NPCState, _ p: Vec2, _ dt: Double) {
        let d = p - n.pos
        if d.length > 0.01 { n.heading = approachAngle(n.heading, d.angle, dt * 6) }
    }

    func setBubble(_ n: inout NPCState, _ icons: [Icon], _ seconds: Double, caption: String = "") {
        n.bubble = icons
        n.bubbleTimer = seconds
        n.bubbleCaption = caption
    }

    public func bubble(_ id: NPCID, _ icons: [Icon], seconds: Double = 2.6, caption: String = "") {
        withNPC(id) { n in
            n.bubble = icons
            n.bubbleTimer = seconds
            n.bubbleCaption = caption
        }
    }

    // MARK: Escort

    func startEscort(by id: NPCID, to spot: String) {
        guard let sp = map.spot(spot) else { return }
        s.player.escortedBy = id
        escortTrail = [s.player.pos]
        s.player.path = []
        s.player.hiddenIn = nil
        withNPC(id) { n in
            n.mode = .escort
            n.modeTimer = 0
            let def = Cast.def(id)
            setGoal(&n, def, sp.pos, facing: sp.facing, force: true)
            if n.path.isEmpty { n.pos = sp.pos }
        }
    }

    func finishEscort(_ id: NPCID) {
        s.player.escortedBy = nil
        escortTrail = []
        s.player.caughtImmunity = max(s.player.caughtImmunity, 90)
        if let n = npc(id), let t = map.nearestWalkable((n.pos + Vec2.fromAngle(n.heading) * 0.0).tile, maxRadius: 2) {
            if s.player.pos.distance(to: n.pos) > 2.5 { s.player.pos = t.center }
        }
    }
}
