import Foundation

/// Programmatic room-and-door map authoring. Rooms are carved from void;
/// walls are generated automatically around indoor floor; doors are cut into
/// those walls explicitly with stable IDs.
public final class MapBuilder {
    public let width: Int
    public let height: Int
    var kinds: [TileKind]
    var zoneIndex: [Int16]
    var zones: [ZoneDef] = []
    var objects: [WorldObject] = []
    var doors: [DoorDef] = []
    var spots: [String: Spot] = [:]
    var hatches: [HatchLink] = []
    var cameras: [CameraDef] = []
    var labels: [(String, Vec2, District)] = []
    var forcedWalls: [TileRect] = []
    var autoID = 0
    public private(set) var problems: [String] = []

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        kinds = [TileKind](repeating: .void, count: width * height)
        zoneIndex = [Int16](repeating: -1, count: width * height)
    }

    @inline(__always) func i(_ x: Int, _ y: Int) -> Int { y * width + x }
    func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }

    public func fill(_ r: TileRect, _ k: TileKind) {
        r.forEach { p in if inBounds(p.x, p.y) { kinds[i(p.x, p.y)] = k } }
    }

    @discardableResult
    public func zone(_ id: String, _ name: String, _ r: TileRect, _ district: District, _ cls: ZoneClass,
                     ground: TileKind = .floor, cell: Int? = nil, label: Bool = true) -> TileRect {
        let zi: Int
        if let existing = zones.firstIndex(where: { $0.id == id }) {
            zi = existing
            zones[zi].rects.append(r)
        } else {
            zi = zones.count
            zones.append(ZoneDef(id: id, name: name, district: district, cls: cls, rects: [r], outdoor: ground.outdoor, cellNumber: cell))
            if label { labels.append((name, r.center, district)) }
        }
        r.forEach { p in
            guard inBounds(p.x, p.y) else { problems.append("zone \(id) out of bounds"); return }
            kinds[i(p.x, p.y)] = ground
            zoneIndex[i(p.x, p.y)] = Int16(zi)
        }
        return r
    }

    /// Paint ground kind inside an existing zone area without changing zone membership.
    public func paint(_ r: TileRect, _ k: TileKind) {
        r.forEach { p in if inBounds(p.x, p.y) { kinds[i(p.x, p.y)] = k } }
    }

    public func fenceLine(_ r: TileRect) { fill(r, .fence) }
    public func wallLine(_ r: TileRect) { forcedWalls.append(r) }
    public func water(_ r: TileRect) { fill(r, .water) }

    public func window(_ x: Int, _ y: Int) {
        guard inBounds(x, y) else { return }
        kinds[i(x, y)] = .window
    }

    public func door(_ id: String, _ x: Int, _ y: Int, vertical: Bool, kind: DoorKind = .interior,
                     rule: AccessRule = .open, name: String = "Door") {
        guard inBounds(x, y) else { problems.append("door \(id) out of bounds"); return }
        if doors.contains(where: { $0.id == id }) { problems.append("duplicate door \(id)") }
        kinds[i(x, y)] = .door
        doors.append(DoorDef(id: id, tile: TilePos(x, y), vertical: vertical, kind: kind, rule: rule, name: name))
    }

    @discardableResult
    public func obj(_ kind: ObjKind, _ x: Int, _ y: Int, w: Int = 1, h: Int = 1, facing: Facing = .down,
                    id: String? = nil, variant: Int = 0) -> String {
        let oid: String
        if let id = id { oid = id } else { autoID += 1; oid = "\(kind.rawValue)#\(autoID)" }
        if objects.contains(where: { $0.id == oid }) { problems.append("duplicate object \(oid)") }
        let zi = inBounds(x, y) ? zoneIndex[i(x, y)] : -1
        let zid = zi >= 0 ? zones[Int(zi)].id : ""
        objects.append(WorldObject(id: oid, kind: kind, tile: TilePos(x, y), w: w, h: h, facing: facing, zone: zid, variant: variant))
        return oid
    }

    public func spot(_ id: String, _ x: Double, _ y: Double, _ facing: Facing = .down) {
        if spots[id] != nil { problems.append("duplicate spot \(id)") }
        spots[id] = Spot(id: id, pos: Vec2(x, y), facing: facing)
    }

    public func hatch(_ id: String, a: TilePos, b: TilePos, rule: AccessRule, discoveredBy: Flag?) {
        hatches.append(HatchLink(id: id, a: a, b: b, rule: rule, discoveredBy: discoveredBy))
    }

    public func camera(_ id: String, _ x: Double, _ y: Double, heading: Double, sweep: Double = 0, period: Double = 8,
                       range: Double = 8, fov: Double = 70 * .pi / 180) {
        cameras.append(CameraDef(id: id, pos: Vec2(x, y), heading: heading, sweep: sweep, period: period, range: range, fov: fov))
    }

    public func finalize() -> WorldMap {
        // Auto walls: any non-indoor tile (void or painted ground) 8-adjacent to indoor
        // floor/tunnel becomes wall. Doors, windows, fences and water keep their kind.
        var newKinds = kinds
        for y in 0..<height {
            for x in 0..<width {
                let k0 = kinds[i(x, y)]
                if k0 == .floor || k0 == .tunnel || k0 == .door || k0 == .window || k0 == .fence || k0 == .water { continue }
                var adj = false
                for dy in -1...1 {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        let nx = x + dx, ny = y + dy
                        guard inBounds(nx, ny) else { continue }
                        let k = kinds[i(nx, ny)]
                        if k == .floor || k == .tunnel { adj = true }
                    }
                }
                if adj { newKinds[i(x, y)] = .wall }
            }
        }
        for r in forcedWalls { r.forEach { p in if inBounds(p.x, p.y) { newKinds[i(p.x, p.y)] = .wall } } }
        kinds = newKinds
        // Structural tiles belong to no zone.
        for k in 0..<(width * height) where kinds[k] == .wall || kinds[k] == .door || kinds[k] == .window || kinds[k] == .void || kinds[k] == .fence {
            zoneIndex[k] = -1
        }
        // Doors must separate two walkable sides.
        for d in doors {
            let a: TilePos, b: TilePos
            if d.vertical { a = TilePos(d.tile.x - 1, d.tile.y); b = TilePos(d.tile.x + 1, d.tile.y) } else {
                a = TilePos(d.tile.x, d.tile.y - 1); b = TilePos(d.tile.x, d.tile.y + 1)
            }
            func ok(_ p: TilePos) -> Bool { inBounds(p.x, p.y) && kinds[i(p.x, p.y)].walkableBase }
            if !ok(a) || !ok(b) { problems.append("door \(d.id) at \(d.tile.x),\(d.tile.y) does not connect two walkable tiles") }
        }
        var propSolid = [Bool](repeating: false, count: width * height)
        var propOpaque = [Bool](repeating: false, count: width * height)
        for o in objects {
            o.rect.forEach { p in
                guard inBounds(p.x, p.y) else { problems.append("object \(o.id) out of bounds"); return }
                if o.kind.solid { propSolid[i(p.x, p.y)] = true }
                if o.kind.tall { propOpaque[i(p.x, p.y)] = true }
                if kinds[i(p.x, p.y)] == .wall || kinds[i(p.x, p.y)] == .void {
                    problems.append("object \(o.id) placed on wall at \(p.x),\(p.y)")
                }
            }
        }
        // Objects' zone fixed after all zones exist.
        var objs = objects
        for k in objs.indices {
            let t = objs[k].tile
            if inBounds(t.x, t.y) {
                let zi = zoneIndex[i(t.x, t.y)]
                if zi >= 0 { objs[k].zone = zones[Int(zi)].id }
            }
        }
        return WorldMap(width: width, height: height, kinds: kinds, zoneIndex: zoneIndex, propSolid: propSolid,
                        propOpaque: propOpaque, zones: zones, objects: objs, doors: doors, spots: spots,
                        hatches: hatches, cameras: cameras, labels: labels)
    }
}
