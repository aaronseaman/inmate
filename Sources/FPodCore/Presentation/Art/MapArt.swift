import Foundation

/// Campus overview for the map screen (structure only; discovery is overlaid live).
enum MapArt {
    static let scale = 4.0   // points per tile in the overview texture

    static func overview(_ map: WorldMap) -> Drawing {
        var s: [Shape] = []
        let W = 160.0 * scale, H = 116.0 * scale
        s.append(Shape(.rect(Rect(0, 0, W, H), radius: 0), fill: Palette.woods.lighter(0.25)))
        // Grounds inside the inner fence.
        s.append(Shape(.rect(Rect(9 * scale, 9 * scale, 142 * scale, 99 * scale), radius: 6), fill: Palette.grass.lighter(0.2)))
        s.append(Shape(.rect(Rect(8 * scale, 8 * scale, 144 * scale, 101 * scale), radius: 6), fill: nil, stroke: Palette.slate.alpha(0.5), lineWidth: 1.2))
        s.append(Shape(.rect(Rect(4 * scale, 4 * scale, 152 * scale, 109 * scale), radius: 8), fill: nil, stroke: Palette.slate.alpha(0.35), lineWidth: 1))
        for z in map.zones where z.district != .perimeter && z.district != .grounds && z.district != .service {
            for r in z.rects {
                let rr = Rect(Double(r.x) * scale, Double(r.y) * scale, Double(r.w) * scale, Double(r.h) * scale)
                s.append(Shape(.rect(rr, radius: 1.5), fill: z.outdoor ? Palette.concrete.lighter(0.1) : Palette.ivory.darker(0.04)))
            }
        }
        return Drawing(size: Vec2(W, H), anchor: Vec2(0, 0), shapes: s)
    }
}
