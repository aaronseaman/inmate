import Foundation

/// Static floor-plan art for 16×16-tile chunks: ground, walls with a low south face,
/// windows, fences and furniture. Rendered once per chunk and cached.
public enum ChunkArt {
    public static let size = 16

    enum Floor { case lino, tile, wood, carpet, checker, cold, cell }

    static func floorStyle(_ z: ZoneDef?) -> (Floor, RGBA) {
        guard let z = z else { return (.lino, Palette.floor) }
        let id = z.id
        if id == "fpod.showers" { return (.tile, Palette.turquoise.lighter(0.62)) }
        if id.hasPrefix("kitchen.") && id != "kitchen.dining" { return (.checker, RGBA(hex: 0xE7ECE8)) }
        if id == "support.chapel" || id == "admin.office" || id == "admin.hearing" || id == "support.office" { return (.wood, RGBA(hex: 0xD9C4A4)) }
        if id == "support.library" || id == "support.lawlib" { return (.carpet, RGBA(hex: 0xC9D3C2)) }
        if id == "admin.visiting" || id == "support.quiet" { return (.carpet, RGBA(hex: 0xC7D4DE)) }
        if id.hasPrefix("obs.") { return (.cold, RGBA(hex: 0xD6DCDF)) }
        if id.hasPrefix("fpod.cell") { return (.cell, RGBA(hex: 0xD0D9DC)) }
        if id == "support.infirmary" || id == "support.ante" || id == "support.isolation" { return (.lino, RGBA(hex: 0xDAE6E1)) }
        return (.lino, z.district.floorTint)
    }

    public static func draw(cx: Int, cy: Int, tile T: Double, map: WorldMap) -> Drawing {
        let N = size
        var p = Pen(scale: T)
        let x0 = cx * N, y0 = cy * N
        func k(_ x: Int, _ y: Int) -> TileKind { map.kind(TilePos(x, y)) }
        func isWallish(_ t: TileKind) -> Bool { t == .wall || t == .window }
        // 1. Ground.
        for ty in y0..<(y0 + N) {
            for tx in x0..<(x0 + N) {
                let lx = Double(tx - x0), ly = Double(ty - y0)
                let kind = k(tx, ty)
                let h = stableHash([UInt64(tx), UInt64(ty)])
                switch kind {
                case .floor, .door:
                    var z = map.zone(at: TilePos(tx, ty))
                    if z == nil { for d in TilePos.dirs4 { if let zz = map.zone(at: TilePos(tx, ty) + d), !zz.outdoor { z = zz; break } } }
                    let (style, base) = floorStyle(z)
                    switch style {
                    case .lino, .cell, .cold:
                        let alt = (tx + ty) % 2 == 0 ? base : base.darker(0.025)
                        p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: alt)
                    case .tile:
                        p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: base)
                        p.line([(lx + 0.5, ly), (lx + 0.5, ly + 1)], color: base.darker(0.08), lw: 0.02)
                        p.line([(lx, ly + 0.5), (lx + 1, ly + 0.5)], color: base.darker(0.08), lw: 0.02)
                    case .wood:
                        p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: base)
                        for j in 0..<3 { p.line([(lx, ly + Double(j) * 0.333 + 0.01), (lx + 1, ly + Double(j) * 0.333 + 0.01)], color: base.darker(0.08), lw: 0.02) }
                        if (tx + ty * 3) % 4 == 0 { p.line([(lx + 0.6, ly), (lx + 0.6, ly + 0.333)], color: base.darker(0.08), lw: 0.02) }
                    case .carpet:
                        p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: base)
                    case .checker:
                        p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: (tx + ty) % 2 == 0 ? base : base.darker(0.07))
                    }
                case .grass:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: Palette.grass)
                    if h % 5 == 0 { p.arc(lx + 0.3 + Double(h % 7) * 0.06, ly + 0.6, 0.12, -2.6, -0.5, color: Palette.grassDark, lw: 0.04) }
                case .concrete:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: Palette.concrete)
                    if tx % 4 == 0 { p.line([(lx, ly), (lx, ly + 1)], color: Palette.concrete.darker(0.07), lw: 0.02) }
                    if ty % 4 == 0 { p.line([(lx, ly), (lx + 1, ly)], color: Palette.concrete.darker(0.07), lw: 0.02) }
                case .court:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: RGBA(hex: 0xD8BF8E))
                case .track:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: Palette.track)
                case .road:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: RGBA(hex: 0xA4A9A6))
                case .woods:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: Palette.woods)
                case .tunnel:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: (tx + ty) % 2 == 0 ? Palette.tunnel : Palette.tunnel.darker(0.03))
                case .water:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: Palette.turquoise.darker(0.1))
                case .fence:
                    // Ground beneath the fence: match a neighbour.
                    var under = Palette.grass
                    for d in TilePos.dirs4 {
                        let nk = k(tx + d.x, ty + d.y)
                        if nk == .concrete { under = Palette.concrete } else if nk == .road { under = RGBA(hex: 0xA4A9A6) }
                    }
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: under)
                case .void:
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: Palette.woodsDark)
                case .wall, .window:
                    break
                }
            }
        }
        // Court markings and woods canopy (decorative, deterministic).
        for ty in (y0 - 1)..<(y0 + N + 1) {
            for tx in (x0 - 1)..<(x0 + N + 1) where k(tx, ty) == .woods {
                let h = stableHash([UInt64(bitPattern: Int64(tx)), UInt64(bitPattern: Int64(ty)), 7])
                if h % 3 == 0 {
                    let lx = Double(tx - x0) + 0.5, ly = Double(ty - y0) + 0.5
                    let r = 0.55 + Double(h % 5) * 0.08
                    p.circle(lx + 0.12, ly + 0.16, r, fill: Palette.shadow)
                    p.circle(lx, ly, r, fill: h % 2 == 0 ? Palette.woodsDark : Palette.grassDark.darker(0.1))
                    p.circle(lx - 0.15, ly - 0.15, r * 0.55, fill: Palette.woods.lighter(0.06))
                }
            }
        }
        // 2. Floor shadows cast by walls (south/east).
        for ty in y0..<(y0 + N) {
            for tx in x0..<(x0 + N) {
                let kind = k(tx, ty)
                guard kind.walkableBase || kind == .fence else { continue }
                let lx = Double(tx - x0), ly = Double(ty - y0)
                if isWallish(k(tx, ty - 1)) { p.rect(lx, ly, 1, 0.16, fill: Palette.shadow.alpha(0.16)) }
                if isWallish(k(tx - 1, ty)) { p.rect(lx, ly, 0.1, 1, fill: Palette.shadow.alpha(0.12)) }
            }
        }
        // 3. Walls with a low south face (cinder block hint).
        for ty in y0..<(y0 + N) {
            for tx in x0..<(x0 + N) {
                let kind = k(tx, ty)
                guard isWallish(kind) else { continue }
                let lx = Double(tx - x0), ly = Double(ty - y0)
                let southOpen = !isWallish(k(tx, ty + 1)) && k(tx, ty + 1) != .void
                let top = Palette.wallTop
                if kind == .window {
                    p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: top)
                    let horiz = isWallish(k(tx - 1, ty)) || isWallish(k(tx + 1, ty))
                    if horiz {
                        p.rect(lx + 0.06, ly + 0.3, 0.88, 0.4, r: 0.04, fill: Palette.blueGray.lighter(0.35))
                        for j in 1...2 { p.line([(lx + Double(j) * 0.33, ly + 0.3), (lx + Double(j) * 0.33, ly + 0.7)], color: Palette.slate, lw: 0.04) }
                    } else {
                        p.rect(lx + 0.3, ly + 0.06, 0.4, 0.88, r: 0.04, fill: Palette.blueGray.lighter(0.35))
                        for j in 1...2 { p.line([(lx + 0.3, ly + Double(j) * 0.33), (lx + 0.7, ly + Double(j) * 0.33)], color: Palette.slate, lw: 0.04) }
                    }
                    continue
                }
                p.rect(lx - 0.012, ly - 0.012, 1.024, 1.024, fill: top)
                if (tx * 7 + ty * 3) % 5 == 0 { p.line([(lx + 0.15, ly + 0.5), (lx + 0.85, ly + 0.5)], color: top.darker(0.035), lw: 0.03) }
                if southOpen {
                    p.rect(lx, ly + 0.7, 1, 0.3, fill: Palette.wallEdge)
                    p.line([(lx, ly + 0.7), (lx + 1, ly + 0.7)], color: Palette.wallEdge.darker(0.08), lw: 0.02)
                    let off = (ty % 2 == 0) ? 0.25 : 0.75
                    p.line([(lx + off, ly + 0.72), (lx + off, ly + 0.98)], color: Palette.wallEdge.darker(0.12), lw: 0.025)
                }
            }
        }
        // 4. Fences: posts + mesh line.
        for ty in y0..<(y0 + N) {
            for tx in x0..<(x0 + N) where k(tx, ty) == .fence {
                let lx = Double(tx - x0), ly = Double(ty - y0)
                let horiz = k(tx - 1, ty) == .fence || k(tx + 1, ty) == .fence
                let vertical = k(tx, ty - 1) == .fence || k(tx, ty + 1) == .fence
                if horiz { p.line([(lx, ly + 0.5), (lx + 1, ly + 0.5)], color: Palette.slate.alpha(0.75), lw: 0.06) }
                if vertical { p.line([(lx + 0.5, ly), (lx + 0.5, ly + 1)], color: Palette.slate.alpha(0.75), lw: 0.06) }
                if (tx + ty) % 3 == 0 { p.circle(lx + 0.5, ly + 0.5, 0.1, fill: Palette.slate, shadow: true) }
                if horiz { p.line([(lx, ly + 0.36), (lx + 1, ly + 0.36)], color: Palette.slate.alpha(0.25), lw: 0.03) }
            }
        }
        // 5. Court paint.
        if let hoop = map.object(id: "yard.hoop") {
            let hx = Double(hoop.tile.x - x0) + 1.0, hy = Double(hoop.tile.y - y0)
            if abs(hx - 8) < 24 && abs(hy - 8) < 24 {
                p.rect(hx - 1.5, hy + 0.2, 3, 4.2, fill: nil, stroke: Palette.paper.alpha(0.8), lw: 0.06)
                p.arc(hx, hy + 4.4, 1.5, 0, .pi, color: Palette.paper.alpha(0.8), lw: 0.06)
                p.arc(hx, hy + 0.4, 5.5, 0.15, .pi - 0.15, color: Palette.paper.alpha(0.6), lw: 0.06)
            }
        }
        // 6. Furniture intersecting this chunk (clipped at the chunk edge).
        let area = Rect(Double(x0 - 1), Double(y0 - 1), Double(N + 2), Double(N + 2))
        for o in map.objects where o.rect.rect.intersects(area) {
            PropArt.draw(o, x: Double(o.tile.x - x0), y: Double(o.tile.y - y0), &p)
        }
        return Drawing(size: Vec2(Double(N) * T, Double(N) * T), anchor: Vec2(0, 0), shapes: p.shapes,
                       shadowOffset: Vec2(0.05 * T, 0.07 * T), shadowBlur: 0.06 * T)
    }

    /// Chunks overlapping a world-space rectangle.
    public static func chunks(covering r: Rect) -> [(Int, Int)] {
        let N = Double(size)
        let c0 = Int(floor(r.minX / N)), c1 = Int(floor((r.maxX - 0.001) / N))
        let r0 = Int(floor(r.minY / N)), r1 = Int(floor((r.maxY - 0.001) / N))
        var out: [(Int, Int)] = []
        for cy in max(0, r0)...max(0, r1) { for cx in max(0, c0)...max(0, c1) { out.append((cx, cy)) } }
        return out
    }
}
