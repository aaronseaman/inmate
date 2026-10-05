import Foundation

/// Movable equipment, drawn facing +x (east) and rotated with the player.
enum VehicleArt {
    static func drawing(_ v: Vehicle, tile T: Double) -> Drawing {
        var p = Pen(scale: T, origin: Vec2(0.05 * T, 0.1 * T))
        let ink = Palette.ink, metal = Palette.metal
        switch v {
        case .janitorCart:
            p.rect(0, 0.05, 0.9, 0.6, r: 0.1, fill: Palette.ochre, shadow: true)
            p.circle(0.3, 0.35, 0.19, fill: Palette.slate.lighter(0.3))
            p.circle(0.3, 0.35, 0.12, fill: Palette.turquoise.lighter(0.3))
            p.rect(0.56, 0.15, 0.26, 0.4, r: 0.05, fill: Palette.paper)
            p.line([(0.7, 0.35), (1.05, 0.05)], color: Palette.wood.darker(0.2), lw: 0.06)
        case .laundryCart:
            p.rect(0, 0, 0.95, 0.7, r: 0.12, fill: Palette.blueGray.lighter(0.15), shadow: true)
            p.rect(0.08, 0.08, 0.79, 0.54, r: 0.08, fill: Palette.ivory)
            p.oval(0.15, 0.15, 0.4, 0.25, fill: Palette.tan.lighter(0.3))
            p.oval(0.42, 0.32, 0.36, 0.22, fill: Palette.paper)
        case .wheelchair:
            p.circle(0.45, 0.05, 0.12, fill: ink, shadow: true)
            p.circle(0.45, 0.65, 0.12, fill: ink, shadow: true)
            p.rect(0.2, 0.12, 0.5, 0.46, r: 0.08, fill: Palette.navy.lighter(0.2))
            p.line([(0.1, 0.12), (0.1, 0.58)], color: metal, lw: 0.06)
        case .floorBuffer:
            p.circle(0.55, 0.35, 0.34, fill: Palette.slate.darker(0.2), shadow: true)
            p.circle(0.55, 0.35, 0.22, fill: Palette.coral.darker(0.1))
            p.line([(0.55, 0.35), (0.05, 0.35)], color: metal.darker(0.2), lw: 0.07)
        }
        // Pivot near the cart's center so it swings naturally with the player.
        return Drawing(size: Vec2(1.15 * T, 0.9 * T), anchor: Vec2(0.5 / 1.15, 0.45 / 0.9), shapes: p.shapes)
    }
}
