import Foundation

/// Tile-aware A* with door permissions and no corner cutting.
public enum Navigation {
    /// - Parameters:
    ///   - canPass: called for door tiles (index) — returns false when locked for this agent.
    ///   - extraBlocked: optional dynamic blocking (e.g. occupied hide spots); never blocks start/goal.
    public static func findPath(_ map: WorldMap, from: TilePos, to: TilePos,
                                canPass: (Int) -> Bool,
                                extraBlocked: ((Int) -> Bool)? = nil,
                                maxExpansions: Int = 60000) -> [TilePos]? {
        guard map.inBounds(from), map.inBounds(to) else { return nil }
        if from == to { return [from] }
        let w = map.width
        let start = map.idx(from), goal = map.idx(to)
        func walkable(_ i: Int) -> Bool {
            if !map.kinds[i].walkableBase || map.propSolid[i] { return false }
            if map.doorAt[i] >= 0 && !canPass(i) { return false }
            if i != start && i != goal, let eb = extraBlocked, eb(i) { return false }
            return true
        }
        guard walkable(goal) else { return nil }
        var g = [Float](repeating: .infinity, count: map.width * map.height)
        var came = [Int32](repeating: -1, count: map.width * map.height)
        var closed = [Bool](repeating: false, count: map.width * map.height)
        var open = MinHeap<Int>()
        g[start] = 0
        func h(_ i: Int) -> Double {
            let dx = Double(abs(i % w - to.x)), dy = Double(abs(i / w - to.y))
            return (dx + dy) + (1.41421356 - 2) * min(dx, dy)
        }
        open.push(start, h(start))
        var expansions = 0
        while let (cur, _) = open.pop() {
            if cur == goal { break }
            if closed[cur] { continue }
            closed[cur] = true
            expansions += 1
            if expansions > maxExpansions { return nil }
            let cx = cur % w, cy = cur / w
            let curIsDoor = map.doorAt[cur] >= 0
            for d in TilePos.dirs8 {
                let nx = cx + d.x, ny = cy + d.y
                guard nx >= 0, ny >= 0, nx < w, ny < map.height else { continue }
                let ni = ny * w + nx
                if closed[ni] || !walkable(ni) { continue }
                let diag = d.x != 0 && d.y != 0
                if diag {
                    // No corner cutting and no diagonal moves through doors.
                    if curIsDoor || map.doorAt[ni] >= 0 { continue }
                    if !walkable(cy * w + nx) || !walkable(ny * w + cx) { continue }
                }
                var cost: Float = diag ? 1.41421356 : 1
                if map.doorAt[ni] >= 0 { cost += 0.4 }
                let ng = g[cur] + cost
                if ng < g[ni] {
                    g[ni] = ng
                    came[ni] = Int32(cur)
                    open.push(ni, Double(ng) + h(ni))
                }
            }
        }
        guard came[goal] >= 0 else { return nil }
        var path: [TilePos] = []
        var c = goal
        while c != start {
            path.append(map.pos(c))
            c = Int(came[c])
        }
        path.append(from)
        return path.reversed()
    }

    /// Converts a tile path into smoothed waypoints. Doors stay as mandatory waypoints.
    public static func waypoints(_ map: WorldMap, _ path: [TilePos], radius: Double = 0.28) -> [Vec2] {
        guard path.count > 1 else { return path.map { $0.center } }
        var anchors: [Int] = [0]
        for (k, p) in path.enumerated() where k > 0 && k < path.count - 1 {
            if map.doorIndex(at: p) != nil { anchors.append(k) }
        }
        anchors.append(path.count - 1)
        var out: [Vec2] = []
        for s in 0..<(anchors.count - 1) {
            let a = anchors[s], b = anchors[s + 1]
            var i = a
            if out.isEmpty { out.append(path[a].center) }
            while i < b {
                var j = b
                while j > i + 1 {
                    if clearLine(map, path[i].center, path[j].center, radius: radius) { break }
                    j -= 1
                }
                out.append(path[j].center)
                i = j
            }
        }
        return out
    }

    /// True if a disc of `radius` can travel straight from a to b over static walkable tiles,
    /// without entering any door tile except at the endpoints.
    public static func clearLine(_ map: WorldMap, _ a: Vec2, _ b: Vec2, radius: Double) -> Bool {
        let d = b - a
        let len = d.length
        let steps = max(1, Int(len / 0.2))
        let startT = a.tile, endT = b.tile
        for s in 0...steps {
            let p = a + d * (Double(s) / Double(steps))
            for off in [Vec2(-radius, -radius), Vec2(radius, -radius), Vec2(-radius, radius), Vec2(radius, radius)] {
                let t = (p + off).tile
                if !map.walkableStatic(t) { return false }
                if t != startT && t != endT && map.doorIndex(at: t) != nil { return false }
            }
        }
        return true
    }
}
