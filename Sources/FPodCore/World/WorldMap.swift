import Foundation

/// Immutable campus geometry produced by `MapBuilder`. Dynamic door state lives
/// in the simulation; this type answers static questions fast.
public final class WorldMap {
    public let width: Int
    public let height: Int
    public private(set) var kinds: [TileKind]
    public private(set) var zoneIndex: [Int16]          // -1 = none
    public private(set) var propSolid: [Bool]
    public private(set) var propOpaque: [Bool]
    public private(set) var objectAt: [Int32]           // index into objects, -1 none
    public private(set) var doorAt: [Int32]             // index into doors, -1 none
    public let zones: [ZoneDef]
    public let objects: [WorldObject]
    public let doors: [DoorDef]
    public let spots: [String: Spot]
    public let hatches: [HatchLink]
    public let cameras: [CameraDef]
    public let districtBounds: [District: TileRect]
    public let zoneByID: [String: Int]
    public let objectByID: [String: Int]
    public let doorByID: [String: Int]
    public let labels: [(String, Vec2, District)]

    init(width: Int, height: Int, kinds: [TileKind], zoneIndex: [Int16], propSolid: [Bool], propOpaque: [Bool],
         zones: [ZoneDef], objects: [WorldObject], doors: [DoorDef], spots: [String: Spot], hatches: [HatchLink],
         cameras: [CameraDef], labels: [(String, Vec2, District)]) {
        self.width = width
        self.height = height
        self.kinds = kinds
        self.zoneIndex = zoneIndex
        self.propSolid = propSolid
        self.propOpaque = propOpaque
        self.zones = zones
        self.objects = objects
        self.doors = doors
        self.spots = spots
        self.hatches = hatches
        self.cameras = cameras
        self.labels = labels
        var zb: [String: Int] = [:]
        for (i, z) in zones.enumerated() { zb[z.id] = i }
        zoneByID = zb
        var ob: [String: Int] = [:]
        var oat = [Int32](repeating: -1, count: width * height)
        for (i, o) in objects.enumerated() {
            ob[o.id] = i
            o.rect.forEach { p in
                if p.x >= 0 && p.y >= 0 && p.x < width && p.y < height { oat[p.y * width + p.x] = Int32(i) }
            }
        }
        objectByID = ob
        objectAt = oat
        var db: [String: Int] = [:]
        var dat = [Int32](repeating: -1, count: width * height)
        for (i, d) in doors.enumerated() {
            db[d.id] = i
            dat[d.tile.y * width + d.tile.x] = Int32(i)
        }
        doorByID = db
        doorAt = dat
        var bounds: [District: TileRect] = [:]
        for z in zones {
            for r in z.rects {
                if let b = bounds[z.district] {
                    let nx = min(b.x, r.x), ny = min(b.y, r.y)
                    let mx = max(b.maxX, r.maxX), my = max(b.maxY, r.maxY)
                    bounds[z.district] = TileRect(nx, ny, mx - nx + 1, my - ny + 1)
                } else {
                    bounds[z.district] = r
                }
            }
        }
        districtBounds = bounds
    }

    @inline(__always) public func inBounds(_ p: TilePos) -> Bool { p.x >= 0 && p.y >= 0 && p.x < width && p.y < height }
    @inline(__always) public func idx(_ p: TilePos) -> Int { p.y * width + p.x }
    @inline(__always) public func pos(_ i: Int) -> TilePos { TilePos(i % width, i / width) }

    public func kind(_ p: TilePos) -> TileKind { inBounds(p) ? kinds[idx(p)] : .void }

    /// Static walkability (ignores doors' lock state; door tiles count as walkable).
    public func walkableStatic(_ p: TilePos) -> Bool {
        guard inBounds(p) else { return false }
        let i = idx(p)
        return kinds[i].walkableBase && !propSolid[i]
    }

    public func zone(at p: TilePos) -> ZoneDef? {
        guard inBounds(p) else { return nil }
        let z = zoneIndex[idx(p)]
        return z >= 0 ? zones[Int(z)] : nil
    }
    public func zone(at v: Vec2) -> ZoneDef? { zone(at: v.tile) }
    public func zone(id: String) -> ZoneDef? { zoneByID[id].map { zones[$0] } }
    public func object(id: String) -> WorldObject? { objectByID[id].map { objects[$0] } }
    public func door(id: String) -> DoorDef? { doorByID[id].map { doors[$0] } }
    public func object(at p: TilePos) -> WorldObject? {
        guard inBounds(p) else { return nil }
        let o = objectAt[idx(p)]
        return o >= 0 ? objects[Int(o)] : nil
    }
    public func doorIndex(at p: TilePos) -> Int? {
        guard inBounds(p) else { return nil }
        let d = doorAt[idx(p)]
        return d >= 0 ? Int(d) : nil
    }
    public func spot(_ id: String) -> Spot? { spots[id] }

    public func district(at p: TilePos) -> District? {
        if let z = zone(at: p) { return z.district }
        // Door/wall tiles: look at neighbours.
        for d in TilePos.dirs4 {
            if let z = zone(at: p + d) { return z.district }
        }
        return nil
    }

    /// Nearest statically walkable tile to `p` (spiral search).
    public func nearestWalkable(_ p: TilePos, maxRadius: Int = 8, filter: ((TilePos) -> Bool)? = nil) -> TilePos? {
        if walkableStatic(p) && (filter?(p) ?? true) { return p }
        for r in 1...maxRadius {
            var best: TilePos?
            var bestD = Int.max
            for dy in -r...r {
                for dx in -r...r where abs(dx) == r || abs(dy) == r {
                    let q = TilePos(p.x + dx, p.y + dy)
                    if walkableStatic(q) && (filter?(q) ?? true) {
                        let d = dx * dx + dy * dy
                        if d < bestD { bestD = d; best = q }
                    }
                }
            }
            if let b = best { return b }
        }
        return nil
    }

    /// Tiles adjacent to an object where an agent can stand to use it.
    public func approachTiles(for o: WorldObject) -> [TilePos] {
        var out: [TilePos] = []
        let r = o.rect.expanded(1)
        r.forEach { p in
            if !o.rect.contains(p) && walkableStatic(p) && doorIndex(at: p) == nil { out.append(p) }
        }
        return out
    }
}
