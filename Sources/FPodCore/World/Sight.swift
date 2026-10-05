import Foundation

/// Grid line-of-sight, ray casting for vision cones, and noise propagation.
public enum Sight {
    /// DDA traversal from a to b. `opaque(i)` decides blocking per tile index.
    /// The start and end tiles never block (observer and target stand in them).
    public static func clear(_ map: WorldMap, _ a: Vec2, _ b: Vec2, opaque: (Int) -> Bool) -> Bool {
        let dist = castRay(map, from: a, dir: b - a, maxDist: (b - a).length, opaque: opaque)
        return dist >= (b - a).length - 1e-6
    }

    /// Returns distance travelled before hitting an opaque tile (or maxDist).
    public static func castRay(_ map: WorldMap, from a: Vec2, dir: Vec2, maxDist: Double, opaque: (Int) -> Bool) -> Double {
        let len = dir.length
        if len < 1e-9 { return 0 }
        let dx = dir.x / len, dy = dir.y / len
        var x = Int(floor(a.x)), y = Int(floor(a.y))
        let stepX = dx > 0 ? 1 : -1, stepY = dy > 0 ? 1 : -1
        let tDeltaX = dx != 0 ? abs(1 / dx) : Double.infinity
        let tDeltaY = dy != 0 ? abs(1 / dy) : Double.infinity
        var tMaxX = dx != 0 ? ((dx > 0 ? (Double(x) + 1 - a.x) : (a.x - Double(x))) * tDeltaX) : Double.infinity
        var tMaxY = dy != 0 ? ((dy > 0 ? (Double(y) + 1 - a.y) : (a.y - Double(y))) * tDeltaY) : Double.infinity
        var t = 0.0
        while t < maxDist {
            if tMaxX < tMaxY {
                t = tMaxX; tMaxX += tDeltaX; x += stepX
            } else {
                t = tMaxY; tMaxY += tDeltaY; y += stepY
            }
            if t >= maxDist { break }
            if x < 0 || y < 0 || x >= map.width || y >= map.height { return t }
            if opaque(y * map.width + x) { return t }
        }
        return maxDist
    }

    /// Visibility fan polygon (in world coordinates) for a vision cone.
    public static func conePolygon(_ map: WorldMap, origin: Vec2, heading: Double, fov: Double, range: Double,
                                   rays: Int = 28, opaque: (Int) -> Bool) -> [Vec2] {
        var pts: [Vec2] = [origin]
        let n = max(4, rays)
        for k in 0...n {
            let a = heading - fov / 2 + fov * Double(k) / Double(n)
            let d = Vec2.fromAngle(a)
            let dist = castRay(map, from: origin, dir: d, maxDist: range, opaque: opaque)
            pts.append(origin + d * dist)
        }
        return pts
    }

    /// Noise flood: Dijkstra from source over walkable/transparent tiles.
    /// Walls block; closed doors add heavy attenuation; fences let sound through.
    /// Returns map of tile index -> remaining loudness (> 0 means audible).
    public static func propagateNoise(_ map: WorldMap, from: TilePos, loudness: Double,
                                      closedDoor: (Int) -> Bool) -> [Int: Double] {
        guard map.inBounds(from) else { return [:] }
        var best: [Int: Double] = [:]
        var heap = MinHeap<Int>()
        let s = map.idx(from)
        best[s] = 0
        heap.push(s, 0)
        let w = map.width
        while let (cur, cost) = heap.pop() {
            if cost > (best[cur] ?? .infinity) + 1e-9 { continue }
            if cost >= loudness { continue }
            let cx = cur % w, cy = cur / w
            for d in TilePos.dirs8 {
                let nx = cx + d.x, ny = cy + d.y
                guard nx >= 0, ny >= 0, nx < w, ny < map.height else { continue }
                let ni = ny * w + nx
                let k = map.kinds[ni]
                if k == .wall || k == .void || k == .window { continue }
                let diag = d.x != 0 && d.y != 0
                if diag {
                    let k1 = map.kinds[cy * w + nx], k2 = map.kinds[ny * w + cx]
                    if k1 == .wall || k1 == .void || k2 == .wall || k2 == .void || k1 == .door || k2 == .door { continue }
                }
                var c = cost + (diag ? 1.414 : 1.0)
                if k == .door && closedDoor(ni) { c += 4.0 }
                if c < (best[ni] ?? .infinity) && c < loudness {
                    best[ni] = c
                    heap.push(ni, c)
                }
            }
        }
        var out: [Int: Double] = [:]
        for (k, v) in best { out[k] = loudness - v }
        return out
    }
}
