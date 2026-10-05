import Foundation

enum Pose { case normal, interact, caught, carry, hidden }

extension Game {
    var viewRect: Rect {
        let half = viewTiles / 2
        return Rect(ui.camera.x - half.x, ui.camera.y - half.y, half.x * 2, half.y * 2)
    }

    func buildWorld(into items: inout [RenderItem], polys: inout [PolyItem]) {
        let view = viewRect.insetBy(-2)
        // 1. Static chunks.
        for (cx, cy) in ChunkArt.chunks(covering: view) {
            let pos = Vec2(Double(cx * ChunkArt.size), Double(cy * ChunkArt.size))
            items.append(RenderItem(id: "chunk.\(cx).\(cy)", art: .chunk(cx, cy), pos: pos, z: 0, layer: .world))
        }
        // 2. Doors.
        for (i, d) in map.doors.enumerated() where view.contains(d.tile.center) {
            let step = Int((doorOpen[i] * 4).rounded())
            items.append(RenderItem(id: "door.\(d.id)", art: .door(d.kind, d.vertical, step), pos: Vec2(Double(d.tile.x), Double(d.tile.y)), z: 1, layer: .world))
        }
        // 3. Cameras.
        for c in map.cameras where view.contains(c.pos) {
            items.append(RenderItem(id: "cam.\(c.id)", art: .marker(5), pos: c.pos, z: 5, layer: .world, rotation: cameraHeading(c)))
            if let poly = cameraPolys[c.id] {
                let susp = cameraSuspicion[c.id] ?? 0
                let col = susp > 30 ? Palette.coral.alpha(0.2) : Palette.ochre.alpha(0.13)
                polys.append(PolyItem(id: "camcone.\(c.id)", points: poly, fill: col, stroke: nil, lineWidth: 0, z: 2, layer: .world))
            }
        }
        // 4. Vision cones.
        for (id, poly) in conePolys {
            guard let n = npc(id) else { continue }
            polys.append(PolyItem(id: "cone.\(id.rawValue)", points: poly, fill: coneColor(n), stroke: nil, lineWidth: 0, z: 2.1, layer: .world))
        }
        // 5. Noise pulses.
        for (k, np) in noisePulses.enumerated() where view.contains(np.pos) {
            let t = np.age / 0.9
            let r = np.radius * (0.25 + 0.75 * t)
            items.append(RenderItem(id: "noise.\(k)", art: .named("noise", 64, np.danger ? 1 : 0), pos: np.pos, z: 3.5, layer: .world,
                                    scaleX: r * 2 * settings.zoom / 64, scaleY: r * 2 * settings.zoom / 64, alpha: (1 - t) * 0.8))
        }
        // 6. Interaction highlight.
        if let t = ui.contextTarget, ui.modal == nil || isFan {
            appendHighlight(t, &items)
        }
        if case .fan(let t, _)? = ui.modal { appendHighlight(t, &items) }
        // 7. Tap marker.
        if let tm = ui.tapMarker, ui.realTime - tm.time < 0.8, !s.player.path.isEmpty {
            let a = 1 - (ui.realTime - tm.time) / 0.8
            items.append(RenderItem(id: "tapmark", art: .marker(0), pos: tm.pos, z: 3.6, layer: .world, scaleX: 0.8 + a * 0.3, scaleY: 0.8 + a * 0.3, alpha: a))
        }
        // 8. Characters.
        for n in s.npcs where n.present && view.contains(n.pos) {
            let def = Cast.def(n.id)
            var pose = Pose.normal
            if n.mode == .inspect && n.path.isEmpty { pose = .interact }
            let seated = def.usesWheelchair
            if seated, let wi = Vehicle.allCases.firstIndex(of: .wheelchair) {
                // Abe's own chair: drawn between legs and body so he reads as seated.
                items.append(RenderItem(id: "\(n.id.rawValue).chair", art: .named("vehicle", wi, 0), pos: n.pos + Vec2(0, -0.22),
                                        z: 10 + n.pos.y * 0.02 - 0.0042, layer: .world, rotation: n.heading))
            }
            appendFigure(id: n.id.rawValue, pos: n.pos, heading: n.heading, look: def.look, moving: seated ? false : n.moving,
                         mode: n.running ? .run : .walk, phase: n.animPhase, pose: pose, seed: Double(stableHash(n.id.rawValue) % 100), &items)
            // Bubble and suspicion badge.
            let headTop = n.pos + Vec2(0, -1.38 * def.look.heightScale)
            if !n.bubble.isEmpty {
                let alert = n.bubble.contains(.exclaim) || n.bubble.contains(.stop)
                let pop = settings.reducedMotion ? 1 : min(1, (2.6 - max(0, n.bubbleTimer)) * 8 + 0.6)
                items.append(RenderItem(id: "bubble.\(n.id.rawValue)", art: .bubble(n.bubble, alert), pos: headTop, z: 2000 + n.pos.y * 0.01, layer: .world,
                                        scaleX: min(1, pop), scaleY: min(1, pop)))
            } else if def.role.isStaff, let icon = suspicionIcon(n) {
                let bg = n.suspicion >= 75 ? Palette.coral : Palette.ochre
                items.append(RenderItem(id: "susp.\(n.id.rawValue)", art: .badge(icon, Int(settings.zoom * 0.6), bg, Palette.paper),
                                        pos: headTop - Vec2(0.3, 0.5), z: 1900 + n.pos.y * 0.01, layer: .world))
            }
            if n.mode == .inspect, let spot = n.inspectTarget, let o = map.object(id: spot), n.path.isEmpty {
                let d = o.center - n.pos
                items.append(RenderItem(id: "searchcue.\(n.id.rawValue)", art: .marker(2), pos: n.pos + Vec2(0, -0.5), z: 3.7, layer: .world,
                                        rotation: d.angle, scaleX: max(1, d.length), scaleY: 1, alpha: 0.85))
            }
        }
        // Player.
        let p = s.player
        if p.hiddenIn == nil {
            items.append(RenderItem(id: "player.ring", art: .shape(ShapeSpec(.ring, w: settings.zoom * 0.62, h: settings.zoom * 0.26, fill: nil, stroke: Palette.turquoise.darker(0.1), lineWidth: 2)),
                                    pos: p.pos - Vec2(0.31, 0.13), z: 9 + p.pos.y * 0.02, layer: .world))
            let look = Cast.playerLook.wearing(Garment(p.outfit))
            var pose = Pose.normal
            if p.changing > 0 { pose = .interact }
            if p.escortedBy != nil { pose = .caught }
            if let v = p.vehicle, !(v == .wheelchair && has(.abeRiding)), let vi = Vehicle.allCases.firstIndex(of: v) {
                // Equipment rides just ahead of the player, turning with them.
                let ahead = p.pos + Vec2.fromAngle(p.heading, 0.62)
                items.append(RenderItem(id: "player.vehicle", art: .named("vehicle", vi, 0), pos: ahead, z: 9 + ahead.y * 0.02 + 0.005,
                                        layer: .world, rotation: p.heading))
            }
            appendFigure(id: "player", pos: p.pos, heading: p.heading, look: look, moving: p.moving, mode: p.mode, phase: p.animPhase, pose: pose, seed: 7, &items)
            if p.changing > 0 {
                let frac = 1 - p.changing / Game.changeSeconds
                items.append(RenderItem(id: "player.change", art: .named("progress", Int(frac * 20), 0), pos: p.pos + Vec2(0, -1.6), z: 2100, layer: .world))
            }
        } else if let id = p.hiddenIn, let o = map.object(id: id) {
            items.append(RenderItem(id: "player.hidden", art: .marker(3), pos: o.center, z: 1800, layer: .world,
                                    scaleX: 0.9 + 0.08 * sin(ui.realTime * 3), scaleY: 0.9 + 0.08 * sin(ui.realTime * 3)))
        }
        // 9. Objective marker.
        if let m = primaryObjective.marker, let wp = markerPosition(m), view.contains(wp) {
            let close = wp.distance(to: s.player.pos) < 1.6
            if !close {
                let bob = settings.reducedMotion ? 0 : sin(ui.realTime * 3) * 0.12
                items.append(RenderItem(id: "objective.marker", art: .marker(1), pos: wp + Vec2(0, -1.6 + bob), z: 2200, layer: .world))
            }
        }
    }

    var isFan: Bool { if case .fan? = ui.modal { return true }; return false }

    func coneColor(_ n: NPCState) -> RGBA {
        switch n.mode {
        case .pursue: return Palette.coral.alpha(0.3)
        case .investigate, .search, .inspect: return Palette.coral.alpha(0.2)
        case .approach, .question: return Palette.ochre.alpha(0.26)
        case .notice: return Palette.ochre.alpha(0.18)
        default: return Palette.paper.alpha(n.suspicion > 10 ? 0.22 : 0.16)
        }
    }

    func suspicionIcon(_ n: NPCState) -> Icon? {
        switch n.mode {
        case .notice: return .question
        case .approach, .question: return .exclaim
        case .investigate, .search, .inspect: return .search
        case .pursue: return .exclaim
        default: return n.suspicion >= 25 ? .question : nil
        }
    }

    func markerPosition(_ m: Marker) -> Vec2? {
        switch m {
        case .npc(let id): return npc(id).flatMap { $0.present ? $0.pos + Vec2(0, -0.2) : nil }
        case .object(let id): return map.object(id: id)?.center
        case .spot(let id): return map.spot(id)?.pos
        case .zone(let id):
            guard let z = map.zone(id: id) else { return nil }
            if map.zone(at: s.player.pos)?.id == id { return nil }
            return z.rects.first?.center
        }
    }

    func appendHighlight(_ t: TargetRef, _ items: inout [RenderItem]) {
        switch t {
        case .npc(let id):
            if let n = npc(id) { items.append(RenderItem(id: "highlight", art: .highlight(1, 1), pos: n.pos + Vec2(0, -0.1), z: 3, layer: .world)) }
        case .object(let id):
            if let o = map.object(id: id) { items.append(RenderItem(id: "highlight", art: .highlight(o.w, o.h), pos: o.center, z: 3, layer: .world)) }
        case .door(let id):
            if let d = map.door(id: id) { items.append(RenderItem(id: "highlight", art: .highlight(1, 1), pos: d.tile.center, z: 3, layer: .world)) }
        }
    }

    /// Articulated figure: shadow, legs, body, arms, head, hair — animated from phase and mode.
    func appendFigure(id: String, pos: Vec2, heading: Double, look: Appearance, moving: Bool, mode: MoveMode, phase: Double,
                      pose: Pose, seed: Double, _ items: inout [RenderItem]) {
        let f = Facing(angle: heading)
        let mir: Double = f == .left ? -1 : 1
        let side = f == .left || f == .right
        let t = ui.realTime
        let calm = settings.reducedMotion
        let ws = look.widthScale, hs = look.heightScale
        let stride = phase * .pi
        let sw = moving ? sin(stride) : 0
        var legAmp = 0.38, armAmp = 0.42, bobAmp = 0.03
        switch mode {
        case .run: legAmp = 0.62; armAmp = 0.75; bobAmp = 0.055
        case .sneak: legAmp = 0.22; armAmp = 0.12; bobAmp = 0.015
        case .walk: break
        }
        if calm { bobAmp *= 0.4 }
        let crouch = mode == .sneak ? 0.07 : 0.0
        let bob = moving ? -abs(sin(stride)) * bobAmp : 0.0
        let breathe = moving || calm ? 0 : 0.012 * sin(t * 2.1 + seed)
        let lean = side && mode == .run && moving ? 0.1 * mir : 0
        let z0 = 10 + pos.y * 0.02
        let hipY = FigureArt.hipY * hs + crouch + bob
        let shoulderY = FigureArt.shoulderY * hs + crouch * 1.3 + bob
        let neckY = FigureArt.neckY * hs + crouch * 1.3 + bob
        func item(_ part: FigurePart, _ suffix: String, _ p: Vec2, _ z: Double, rot: Double = 0, sx: Double = 1, sy: Double = 1) {
            items.append(RenderItem(id: "\(id).\(suffix)", art: FigureArt.key(part, look, f), pos: p, z: z, layer: .world,
                                    rotation: rot, scaleX: sx * mir, scaleY: sy))
        }
        // Shadow
        items.append(RenderItem(id: "\(id).shadow", art: FigureArt.key(.shadow, look, .down), pos: pos + Vec2(0, -0.02), z: z0 - 0.009, layer: .world,
                                scaleX: moving ? 1 - abs(sw) * 0.08 : 1, scaleY: 1))
        // Legs
        if side {
            let a = -sw * legAmp * mir, b = sw * legAmp * mir
            item(.legL, "legL", pos + Vec2(-0.02 * mir, hipY), z0 - 0.006, rot: b)
            item(.legR, "legR", pos + Vec2(0.02 * mir, hipY), z0 - 0.004, rot: a)
        } else {
            let liftL = moving ? max(0, sin(stride)) * 0.05 : 0, liftR = moving ? max(0, -sin(stride)) * 0.05 : 0
            item(.legL, "legL", pos + Vec2(-FigureArt.legSpacing * ws, hipY - liftL), z0 - 0.006, sy: 1 - liftL * 1.2)
            item(.legR, "legR", pos + Vec2(FigureArt.legSpacing * ws, hipY - liftR), z0 - 0.005, sy: 1 - liftR * 1.2)
        }
        // Arms (back arm behind the body in side views).
        var armRotL = 0.0, armRotR = 0.0
        if side {
            armRotL = sw * armAmp * mir
            armRotR = -sw * armAmp * mir
        } else {
            armRotL = moving ? 0.12 + sw * 0.1 : 0.08
            armRotR = moving ? -0.12 + sw * 0.1 : -0.08
        }
        switch pose {
        case .interact: armRotR = side ? -1.1 * mir : -0.5
        case .caught: armRotL = side ? -0.5 * mir : 0.45; armRotR = side ? -0.6 * mir : -0.45
        case .carry: armRotL = side ? -0.9 * mir : 0.3; armRotR = side ? -1.0 * mir : -0.3
        default: break
        }
        if mode == .sneak && pose == .normal { armRotL *= 0.5; armRotR *= 0.5 }
        let shoulderXOff = side ? 0.02 : FigureArt.shoulderX * ws
        let armLPos = pos + Vec2(side ? -0.03 * mir : -shoulderXOff, shoulderY + 0.02)
        let armRPos = pos + Vec2(side ? 0.03 * mir : shoulderXOff, shoulderY + 0.02)
        if side { item(.armL, "armL", armLPos, z0 - 0.003, rot: armRotL) }
        // Body
        item(.body, "body", pos + Vec2(0, hipY + 0.02), z0, rot: lean, sy: 1 + breathe)
        if !side {
            item(.armL, "armL", armLPos, z0 + 0.001, rot: armRotL, sx: f == .up ? 1 : 1)
            item(.armR, "armR", armRPos, z0 + 0.002, rot: armRotR)
        } else {
            item(.armR, "armR", armRPos, z0 + 0.002, rot: armRotR)
        }
        // Head + hair (tilt for idle glances, droop when caught).
        var tilt = calm ? 0 : (moving ? 0 : 0.06 * sin(t * 0.6 + seed))
        if pose == .caught { tilt = 0.15 * mir }
        let headPos = pos + Vec2(lean * 0.3, neckY + (pose == .caught ? 0.04 : 0))
        item(.head, "head", headPos, z0 + 0.003, rot: tilt)
        item(.hair, "hair", headPos, z0 + 0.004, rot: tilt)
    }
}
