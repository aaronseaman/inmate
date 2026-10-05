import Foundation

extension Game {
    public static let walkSpeed = 2.5
    public static let sneakSpeed = 1.4
    public static let runSpeed = 4.2
    public static let interactRadius = 1.25
    public static let playerRadius = 0.28
    public static let changeSeconds = 2.5

    public var effectiveMode: MoveMode {
        if s.player.vehicle != nil { return .walk }
        if s.player.sneakToggle { return .sneak }
        if (s.player.runToggle || s.player.runOnce) && s.player.energy > 8 { return .run }
        return .walk
    }

    var playerSpeed: Double {
        if let v = s.player.vehicle { return v.speed }
        var sp: Double
        switch effectiveMode {
        case .walk: sp = Game.walkSpeed
        case .sneak: sp = Game.sneakSpeed
        case .run: sp = Game.runSpeed
        }
        if s.player.energy < 15 { sp *= 0.85 }
        return sp
    }

    // MARK: Update

    func updatePlayer(_ dt: Double) {
        var p = s.player
        defer { s.player = p }
        p.mode = effectiveMode
        if p.changing > 0 {
            p.changing -= dt
            p.moving = false
            if p.changing <= 0 {
                p.changing = 0
                if let o = p.changingTo { s.player = p; finishChange(o); p = s.player }
            }
            return
        }
        if p.hiddenIn != nil { p.moving = false; return }
        if let esc = p.escortedBy, let en = npc(esc) {
            // Follow the escort's breadcrumb trail (never through walls), a step behind.
            var budget = dt * 2.6
            p.moving = false
            while budget > 0, let target = escortTrail.first, p.pos.distance(to: en.pos) > 1.0 {
                let d = target - p.pos
                if d.length < 0.05 { escortTrail.removeFirst(); continue }
                let step = min(d.length, budget)
                p.pos = p.pos + d.normalized * step
                p.heading = d.angle
                budget -= step
                p.moving = true
                p.animPhase += step * 1.7
                if step >= d.length - 1e-6 { escortTrail.removeFirst() }
            }
            trackZone(&p)
            return
        }
        var moved = 0.0
        let dev = ui.devMove
        if dev.lengthSquared > 0.01 {
            p.path = []
            let v = dev.normalized * playerSpeed * dt
            let before = p.pos
            p.pos = slide(p.pos, by: v)
            moved = (p.pos - before).length
            if moved > 1e-4 { p.heading = v.angle }
        } else if p.pathIndex < p.path.count {
            var remaining = playerSpeed * dt
            while remaining > 0 && p.pathIndex < p.path.count {
                let target = p.path[p.pathIndex]
                let d = target - p.pos
                let len = d.length
                // Doors can lock mid-walk (schedule change): stop at the threshold.
                let nextTile = (p.pos + d.normalized * min(len, 0.45)).tile
                if let di = map.doorIndex(at: nextTile), nextTile != p.pos.tile, !playerCanPass(doorIndex: di) {
                    let (icon, text) = doorRequirement(map.doors[di])
                    toast(icon, "\(map.doors[di].name): \(text)")
                    sound(.doorLock, at: map.doors[di].tile.center, volume: 0.6)
                    p.path = []
                    p.pathIndex = 0
                    ui.pendingTarget = nil
                    break
                }
                if len <= remaining {
                    p.pos = target
                    remaining -= len
                    moved += len
                    p.pathIndex += 1
                } else {
                    p.pos = p.pos + d / len * remaining
                    moved += remaining
                    remaining = 0
                }
                if len > 1e-4 { p.heading = d.angle }
            }
            if p.pathIndex >= p.path.count {
                p.path = []
                p.pathIndex = 0
                p.runOnce = false
            }
        }
        p.moving = moved > 1e-4
        if p.moving {
            let speed = moved / max(dt, 1e-4)
            p.animPhase += moved * 1.7
            p.noiseTimer -= dt
            if p.noiseTimer <= 0 {
                p.noiseTimer = 0.5
                let loud: Double
                if let v = p.vehicle { loud = v.noise } else {
                    switch p.mode {
                    case .run: loud = 6.0
                    case .walk: loud = 1.8
                    case .sneak: loud = 0.6
                    }
                }
                s.player = p
                makeNoise(at: p.pos, loudness: loud, suspicious: p.mode == .run || p.vehicle == .floorBuffer, source: .player)
                p = s.player
                sound(p.mode == .run ? .stepRun : (p.mode == .sneak ? .stepSoft : .step), volume: p.mode == .sneak ? 0.25 : 0.45)
            }
            if p.mode == .run {
                p.energy = max(0, p.energy - dt * 0.9)
                if p.outfit != .tanScrubs { p.outfitCondition = max(0, p.outfitCondition - dt * 0.6) }
            }
            _ = speed
        }
        trackZone(&p)
        s.player = p
        checkLateReturn()
        p = s.player
        // Close enough to a tapped person (who may be walking toward us)? Open right away.
        if let t = ui.pendingTarget, case .npc(let id) = t {
            s.player = p
            if canInteract(with: t) {
                ui.pendingTarget = nil
                stopWalking()
                openInteraction(t)
                p = s.player
            } else if let n = npc(id) {
                // They've seen you coming: keep them waiting while you approach (bounded).
                if n.pos.distance(to: p.pos) < 16 {
                    withNPC(id) { m in if m.attendTimer > 0 && m.attendTimer < 1.5 && m.attendTotal < 20 { m.attendTimer = 1.5 } }
                }
                // Re-aim at a target who moved.
                pendingRetarget -= dt
                if pendingRetarget <= 0, let end = p.path.last, end.distance(to: n.pos) > 1.3 {
                    pendingRetarget = 0.6
                    if let ap = approachPoint(for: t), walk(to: ap) { ui.pendingTarget = t }
                    p = s.player
                }
                if p.path.isEmpty && n.attendCome && n.attendTimer > 0 { return }
            }
        }
        // Arrived next to a tapped target?
        if let t = ui.pendingTarget, p.path.isEmpty {
            s.player = p
            if canInteract(with: t) {
                ui.pendingTarget = nil
                openInteraction(t)
            } else if case .npc(let id) = t, let n = npc(id), n.present, n.pos.distance(to: p.pos) < 14, pendingRetries < 4,
                      let ap = approachPoint(for: t), walk(to: ap) {
                pendingRetries += 1
                ui.pendingTarget = t
            } else {
                ui.pendingTarget = nil
                pendingRetries = 0
                toast(.question, "Can't reach that from here")
            }
            p = s.player
        }
        if ui.pendingTarget == nil { pendingRetries = 0 }
    }

    func trackZone(_ p: inout PlayerState) {
        if let z = map.zone(at: p.pos) {
            if z.id != p.lastZone {
                p.lastZone = z.id
                emit(.zoneEntered(z.id))
            }
            if z.district != p.lastDistrict {
                p.lastDistrict = z.district
                if !settings.reducedMotion { ui.districtFade = 1 }
                ui.cameraSnap = true
            }
        }
    }

    /// Circle-vs-grid sliding movement (keyboard dev controls, vehicles).
    func slide(_ pos: Vec2, by v: Vec2) -> Vec2 {
        var p = pos
        let r = Game.playerRadius
        func blocked(_ q: Vec2) -> Bool {
            for off in [Vec2(-r, -r), Vec2(r, -r), Vec2(-r, r), Vec2(r, r)] {
                let t = (q + off).tile
                guard map.inBounds(t) else { return true }
                let i = map.idx(t)
                if !map.kinds[i].walkableBase || map.propSolid[i] { return true }
                if map.doorAt[i] >= 0 && !playerCanPass(doorIndex: Int(map.doorAt[i])) { return true }
            }
            return false
        }
        let nx = Vec2(p.x + v.x, p.y)
        if !blocked(nx) { p = nx }
        let ny = Vec2(p.x, p.y + v.y)
        if !blocked(ny) { p = ny }
        return p
    }

    // MARK: Path planning

    /// Plans a path to a world point. Returns false if unreachable.
    @discardableResult
    public func walk(to point: Vec2, run: Bool = false) -> Bool {
        guard s.player.hiddenIn == nil, s.player.changing <= 0, s.player.escortedBy == nil else { return false }
        let goalTile = point.tile
        guard let target = map.nearestWalkable(goalTile, maxRadius: 4) else { return false }
        let start = s.player.pos.tile
        if let tiles = Navigation.findPath(map, from: start, to: target, canPass: { self.playerCanPassTile($0) }, extraBlocked: nil) {
            var wps = Navigation.waypoints(map, tiles)
            if !wps.isEmpty { wps[0] = s.player.pos }
            // End exactly at tapped point when it's walkable in the target tile.
            if target == goalTile, map.walkableStatic(goalTile) {
                wps[wps.count - 1] = point
            }
            s.player.path = wps
            s.player.pathIndex = wps.count > 1 ? 1 : 0
            s.player.runOnce = run
            return true
        }
        // Explain the blocking door, and walk as far as possible.
        if let tiles = Navigation.findPath(map, from: start, to: target, canPass: { _ in true }) {
            for (k, t) in tiles.enumerated() {
                if let di = map.doorIndex(at: t), !playerCanPass(doorIndex: di) {
                    let (icon, text) = doorRequirement(map.doors[di])
                    toast(icon, "\(map.doors[di].name): \(text)")
                    sound(.doorLock, volume: 0.5)
                    let partial = Array(tiles[0..<k])
                    if partial.count > 1 {
                        var wps = Navigation.waypoints(map, partial)
                        wps[0] = s.player.pos
                        s.player.path = wps
                        s.player.pathIndex = 1
                    }
                    return false
                }
            }
        }
        toast(.cross, "No way through")
        return false
    }

    public func stopWalking() {
        s.player.path = []
        s.player.pathIndex = 0
        ui.pendingTarget = nil
    }

    // MARK: Changing clothes

    public func privateForChanging() -> Bool {
        if s.watch == .red { return false }
        guard let z = map.zone(at: s.player.pos) else { return false }
        return z.id == "fpod.cell\(s.player.cell)" || z.id == "fpod.showers" || z.cls == .closet || z.id == "voc.laundry" || z.id == "support.ante"
    }

    func beginChange(to o: Outfit) {
        if s.player.vehicle != nil { parkVehicle() }
        guard s.player.changing <= 0 else { return }
        if o != .tanScrubs && s.inventory.count(o.item) == 0 { return }
        if o == .tanScrubs && s.player.outfit == .tanScrubs { return }
        stopWalking()
        s.player.changing = Game.changeSeconds
        s.player.changingTo = o
        sound(.swish, volume: 0.6)
    }

    func finishChange(_ o: Outfit) {
        let old = s.player.outfit
        if old == o { return }
        // Swap: the worn outfit goes into carried inventory as a folded item.
        if o != .tanScrubs { _ = removeItem(o.item, 1) }
        if old != .tanScrubs { _ = addItem(old.item, 1, preferred: .carried, force: true) }
        else { _ = addItem(.tanScrubs, 1, preferred: .carried, force: true) }
        if o == .tanScrubs { _ = removeItem(.tanScrubs, 1) }
        s.player.outfit = o
        s.player.outfitCondition = o == .tanScrubs ? 100 : (s.outfitConditions[o] ?? 90)
        if old != .tanScrubs { s.outfitConditions[old] = s.player.outfitCondition }
        for i in s.npcs.indices { s.npcs[i].recognizedDisguise = false }
        toast(.shirt, "Wearing: \(o.title)")
        sound(.swish)
        stat("outfitChanges")
    }

    // MARK: Hiding

    func enterHide(_ objectID: String) {
        if s.player.vehicle != nil { parkVehicle() }
        guard let def = hideSpotByObject[objectID], let o = map.object(id: objectID) else { return }
        let occupants = occupiedHides.contains(objectID) ? 1 : 0
        guard occupants < def.capacity else { toast(.hide, "Occupied"); return }
        stopWalking()
        s.player.hiddenIn = objectID
        s.player.hideReturn = s.player.pos
        s.player.pos = o.center
        occupiedHides.insert(objectID)
        sound(.swish, volume: 0.5)
        if !has(.firstHide) { setFlag(.firstHide) }
        // Anyone who watched you go in remembers which spot.
        for i in s.npcs.indices where Cast.def(s.npcs[i].id).role.isStaff && s.npcs[i].present {
            if npcSeesPoint(s.npcs[i], o.center, range: Cast.def(s.npcs[i].id).role.vision.range) && s.npcs[i].suspicion >= 25 {
                s.npcs[i].sawPlayerEnterHide = objectID
            }
        }
        stat("hides")
    }

    public func exitHide() {
        guard let id = s.player.hiddenIn else { return }
        s.player.hiddenIn = nil
        occupiedHides.remove(id)
        if let o = map.object(id: id) {
            let back = s.player.hideReturn ?? o.center
            let tiles = map.approachTiles(for: o)
            let best = tiles.min { $0.center.distance(to: back) < $1.center.distance(to: back) }
            s.player.pos = (map.walkableStatic(back.tile) && map.object(at: back.tile) == nil) ? back : (best?.center ?? back)
        }
        s.player.hideReturn = nil
        sound(.swish, volume: 0.4)
    }
}
