import Foundation

/// Articulated paper-doll figures: separate parts with pivots so the presenter
/// can swing limbs, bob, squash and turn heads. Left facing = mirrored right.
public enum FigureArt {
    // Pivot offsets from the feet (tile units, y up is negative).
    public static let hipY = -0.36
    public static let shoulderY = -0.76
    public static let neckY = -0.8
    public static let headCenterY = -0.98
    public static let legSpacing = 0.085
    public static let shoulderX = 0.215

    public static func draw(_ part: FigurePart, _ a: Appearance, _ f: Facing, tile T: Double) -> Drawing {
        let skin = Palette.skins[a.skin % Palette.skins.count]
        let hair = Palette.hairs[a.hairColor % Palette.hairs.count]
        let top = a.garment.top, bottom = a.garment.bottom
        let shoe = Palette.ink.lighter(0.15)
        let ws = a.widthScale, hs = a.heightScale
        let side = f == .left || f == .right
        switch part {
        case .shadow:
            var p = Pen(scale: T)
            p.oval(0, 0, 0.52 * ws, 0.17, fill: Palette.shadow.alpha(0.26))
            return Drawing(size: Vec2(0.52 * ws * T, 0.17 * T), anchor: Vec2(0.5, 0.5), shapes: p.shapes)
        case .legL, .legR:
            var p = Pen(scale: T)
            let w = 0.13 * ws, len = 0.38 * hs
            p.rect(0.025, 0, w, len - 0.05, r: 0.05, fill: bottom)
            if side { p.rect(0.0, len - 0.09, w + 0.07, 0.09, r: 0.04, fill: shoe) } else { p.rect(0.015, len - 0.08, w + 0.02, 0.08, r: 0.04, fill: shoe) }
            return Drawing(size: Vec2((w + 0.08) * T, len * T), anchor: Vec2(0.35, 0.04), shapes: p.shapes, shadowOffset: .zero, shadowBlur: 0)
        case .body:
            var p = Pen(scale: T)
            let bw = (side ? 0.3 : 0.42) * ws, bh = 0.44 * hs
            let W = bw + 0.06, H = bh + 0.04
            let x0 = 0.03, y0 = 0.0
            // Torso: slightly wider shoulders than hips.
            p.path([.move(Vec2(x0 + 0.02, y0 + 0.08)), .quad(Vec2(x0 + 0.02, y0), Vec2(x0 + 0.1, y0)),
                    .line(Vec2(x0 + bw - 0.1, y0)), .quad(Vec2(x0 + bw - 0.02, y0), Vec2(x0 + bw - 0.02, y0 + 0.08)),
                    .line(Vec2(x0 + bw - 0.05, y0 + bh - 0.04)), .quad(Vec2(x0 + bw - 0.06, y0 + bh), Vec2(x0 + bw - 0.1, y0 + bh)),
                    .line(Vec2(x0 + 0.1, y0 + bh)), .quad(Vec2(x0 + 0.06, y0 + bh), Vec2(x0 + 0.05, y0 + bh - 0.04)), .close],
                   fill: top, shadow: true)
            let mid = x0 + bw / 2
            let detail = top.darker(0.16)
            if f == .down {
                switch a.garment {
                case .scrubs, .nurse:
                    p.poly([(mid - 0.07, y0), (mid, y0 + 0.11), (mid + 0.07, y0)], fill: detail)
                    p.rect(mid + 0.05, y0 + 0.17, 0.08, 0.07, r: 0.02, fill: detail)
                case .co:
                    p.circle(mid - 0.09, y0 + 0.13, 0.03, fill: Palette.ochre)
                    p.rect(x0 + 0.05, y0 + bh - 0.1, bw - 0.1, 0.05, fill: Palette.ink)
                    p.line([(mid, y0 + 0.02), (mid, y0 + bh - 0.1)], color: detail, lw: 0.015)
                case .whiteCoat:
                    p.poly([(mid - 0.08, y0), (mid, y0 + 0.16), (mid + 0.08, y0)], fill: Palette.slate)
                    p.line([(mid, y0 + 0.16), (mid, y0 + bh)], color: Palette.blueGray, lw: 0.02)
                    p.rect(mid + 0.04, y0 + 0.24, 0.09, 0.08, r: 0.02, fill: nil, stroke: Palette.blueGray, lw: 0.012)
                case .kitchen:
                    p.rect(mid - 0.11, y0 + 0.1, 0.22, bh - 0.12, r: 0.04, fill: Palette.paper)
                    p.line([(mid - 0.11, y0 + 0.1), (mid - 0.14, y0)], color: Palette.paper.darker(0.1), lw: 0.02)
                case .maintenance:
                    p.line([(mid, y0 + 0.02), (mid, y0 + bh)], color: detail, lw: 0.02)
                    p.rect(mid - 0.14, y0 + 0.1, 0.08, 0.05, r: 0.01, fill: Palette.ochre)
                case .ppe:
                    p.rect(x0 - 0.02, y0 + 0.02, bw + 0.04, bh + 0.02, r: 0.08, fill: top.lighter(0.1))
                case .chaplain:
                    p.rect(mid - 0.03, y0 + 0.01, 0.06, 0.04, fill: Palette.paper)
                case .tech:
                    p.poly([(mid - 0.08, y0), (mid - 0.02, y0 + 0.07), (mid + 0.02, y0 + 0.07), (mid + 0.08, y0)], fill: Palette.paper)
                case .cardigan, .sweater:
                    for k in 0..<3 { p.circle(mid, y0 + 0.1 + Double(k) * 0.1, 0.018, fill: detail) }
                case .suit:
                    p.poly([(mid - 0.07, y0), (mid, y0 + 0.2), (mid + 0.07, y0)], fill: Palette.paper)
                    p.poly([(mid - 0.02, y0 + 0.04), (mid + 0.02, y0 + 0.04), (mid + 0.025, y0 + 0.2), (mid, y0 + 0.24), (mid - 0.025, y0 + 0.2)], fill: Palette.coral.darker(0.1))
                case .workShirt:
                    p.rect(mid + 0.04, y0 + 0.08, 0.08, 0.08, r: 0.02, fill: detail)
                case .visitor, .casual, .laundry:
                    p.arc(mid, y0 - 0.02, 0.07, 0.3, 2.84, color: detail, lw: 0.02)
                }
            } else if f == .up {
                p.line([(mid, y0 + 0.04), (mid, y0 + 0.1)], color: detail, lw: 0.015)
            } else {
                if a.garment == .co { p.circle(x0 + bw - 0.08, y0 + 0.13, 0.025, fill: Palette.ochre) }
                if a.garment == .kitchen { p.rect(x0 + bw - 0.08, y0 + 0.1, 0.06, bh - 0.12, r: 0.02, fill: Palette.paper) }
            }
            return Drawing(size: Vec2(W * T, H * T), anchor: Vec2(0.5, 1.0), shapes: p.shapes, shadowOffset: Vec2(0.03 * T, 0.04 * T), shadowBlur: 0.03 * T)
        case .armL, .armR:
            var p = Pen(scale: T)
            let w = 0.1, len = 0.34 * hs
            p.rect(0.01, 0, w, len * 0.68, r: 0.05, fill: top.darker(0.06))
            p.circle(0.01 + w / 2, len - 0.06, 0.055, fill: skin)
            return Drawing(size: Vec2((w + 0.02) * T, len * T), anchor: Vec2(0.5, 0.06), shapes: p.shapes, shadowOffset: .zero, shadowBlur: 0)
        case .head:
            var p = Pen(scale: T)
            let D = 0.44
            let cx = D / 2, cy = D / 2, r = 0.165
            // Neck
            p.rect(cx - 0.05, cy + r - 0.06, 0.1, 0.1, r: 0.03, fill: skin.darker(0.08))
            if f == .down {
                p.circle(cx - r + 0.005, cy + 0.01, 0.035, fill: skin.darker(0.05))
                p.circle(cx + r - 0.005, cy + 0.01, 0.035, fill: skin.darker(0.05))
            }
            p.circle(cx, cy, r, fill: skin, shadow: true)
            let eye = Palette.ink
            switch f {
            case .down:
                p.circle(cx - 0.055, cy + 0.01, 0.018, fill: eye)
                p.circle(cx + 0.055, cy + 0.01, 0.018, fill: eye)
                p.arc(cx, cy + 0.035, 0.04, 0.5, 2.64, color: skin.darker(0.35), lw: 0.012)
                p.circle(cx - 0.09, cy + 0.055, 0.022, fill: Palette.coral.alpha(0.18))
                p.circle(cx + 0.09, cy + 0.055, 0.022, fill: Palette.coral.alpha(0.18))
            case .right, .left:
                p.circle(cx + 0.09, cy + 0.005, 0.017, fill: eye)
                p.poly([(cx + r - 0.01, cy + 0.0), (cx + r + 0.03, cy + 0.035), (cx + r - 0.01, cy + 0.05)], fill: skin)
                p.circle(cx - 0.02, cy + 0.015, 0.035, fill: skin.darker(0.06))
            case .up:
                break
            }
            // Face accessories.
            switch a.accessory {
            case .glasses, .glassesBeard:
                if f == .down {
                    p.circle(cx - 0.055, cy + 0.01, 0.038, fill: nil, stroke: Palette.ink, lw: 0.012)
                    p.circle(cx + 0.055, cy + 0.01, 0.038, fill: nil, stroke: Palette.ink, lw: 0.012)
                    p.line([(cx - 0.018, cy + 0.01), (cx + 0.018, cy + 0.01)], color: Palette.ink, lw: 0.01)
                } else if f != .up {
                    p.circle(cx + 0.09, cy + 0.005, 0.036, fill: nil, stroke: Palette.ink, lw: 0.012)
                    p.line([(cx + 0.055, cy + 0.0), (cx - 0.04, cy - 0.01)], color: Palette.ink, lw: 0.01)
                }
            default: break
            }
            if a.accessory == .beard || a.accessory == .glassesBeard {
                if f == .down { p.path([.move(Vec2(cx - r + 0.03, cy + 0.03)), .quad(Vec2(cx, cy + r + 0.07), Vec2(cx + r - 0.03, cy + 0.03)), .line(Vec2(cx + 0.06, cy + 0.06)), .quad(Vec2(cx, cy + 0.1), Vec2(cx - 0.06, cy + 0.06)), .close], fill: hair) }
                else if f != .up { p.path([.move(Vec2(cx - 0.02, cy + 0.04)), .quad(Vec2(cx + 0.02, cy + r + 0.06), Vec2(cx + r, cy + 0.06)), .line(Vec2(cx + 0.06, cy + 0.06)), .close], fill: hair) }
            }
            if a.accessory == .mustache && f != .up {
                if f == .down { p.rect(cx - 0.05, cy + 0.045, 0.1, 0.025, r: 0.012, fill: hair) } else { p.rect(cx + 0.06, cy + 0.045, 0.08, 0.022, r: 0.01, fill: hair) }
            }
            if a.accessory == .stubble && f == .down {
                p.path([.move(Vec2(cx - r + 0.04, cy + 0.05)), .quad(Vec2(cx, cy + r + 0.03), Vec2(cx + r - 0.04, cy + 0.05)), .close], fill: hair.alpha(0.22))
            }
            if a.accessory == .earring && f == .down { p.circle(cx + r - 0.0, cy + 0.06, 0.012, fill: Palette.ochre) }
            return Drawing(size: Vec2(D * T, D * T), anchor: Vec2(0.5, 0.86), shapes: p.shapes, shadowOffset: Vec2(0.025 * T, 0.03 * T), shadowBlur: 0.025 * T)
        case .hair:
            var p = Pen(scale: T)
            let D = 0.44
            let cx = D / 2, cy = D / 2, r = 0.165
            let back = f == .up
            let sideRight = f == .right || f == .left
            func cap(_ depth: Double) {
                // Hair cap covering the top of the head down to `depth`.
                p.path([.move(Vec2(cx - r - 0.008, cy + depth)), .quad(Vec2(cx - r - 0.02, cy - r - 0.03), Vec2(cx, cy - r - 0.025)),
                        .quad(Vec2(cx + r + 0.02, cy - r - 0.03), Vec2(cx + r + 0.008, cy + depth)),
                        .quad(Vec2(cx, cy - r * 0.35), Vec2(cx - r - 0.008, cy + depth)), .close], fill: hair)
            }
            switch a.hair {
            case .bald:
                if back { p.arc(cx, cy, r * 0.9, 0.3, 2.8, color: hair.alpha(0.4), lw: 0.03) }
            case .buzz:
                if back { p.circle(cx, cy, r + 0.004, fill: hair.alpha(0.55)) } else { cap(-0.03); }
            case .short, .sidePart:
                if back { p.circle(cx, cy - 0.005, r + 0.012, fill: hair) } else {
                    cap(0.0)
                    if a.hair == .sidePart && !sideRight { p.poly([(cx - 0.02, cy - r - 0.02), (cx + 0.06, cy - r), (cx + 0.1, cy - 0.06)], fill: hair.darker(0.1)) }
                    if sideRight { p.rect(cx - r - 0.01, cy - 0.06, 0.12, 0.12, r: 0.05, fill: hair) }
                }
            case .curls, .afro:
                let big = a.hair == .afro ? 0.07 : 0.035
                if back { p.circle(cx, cy - 0.01, r + big, fill: hair) } else {
                    for k in 0..<9 {
                        let ang = -Double.pi + Double(k) * (Double.pi / 8)
                        p.circle(cx + cos(ang) * (r + big * 0.4), cy - 0.02 + sin(ang) * (r + big * 0.4), 0.05 + big * 0.5, fill: hair)
                    }
                    if sideRight { p.circle(cx - r * 0.6, cy + 0.02, 0.07 + big * 0.4, fill: hair) }
                }
            case .bun:
                if back { p.circle(cx, cy - 0.005, r + 0.01, fill: hair); p.circle(cx, cy - 0.04, 0.06, fill: hair.darker(0.08)) } else {
                    cap(0.01)
                    p.circle(sideRight ? cx - r * 0.8 : cx, cy - r - 0.04, 0.065, fill: hair)
                }
            case .long, .ponytail:
                if back {
                    p.circle(cx, cy - 0.005, r + 0.012, fill: hair)
                    if a.hair == .long { p.rect(cx - r + 0.01, cy, 2 * r - 0.02, r + 0.08, r: 0.06, fill: hair) } else { p.rect(cx - 0.035, cy + 0.04, 0.07, r + 0.06, r: 0.035, fill: hair) }
                } else {
                    cap(0.03)
                    if a.hair == .long && !sideRight {
                        p.rect(cx - r - 0.02, cy - 0.02, 0.06, r + 0.08, r: 0.03, fill: hair)
                        p.rect(cx + r - 0.04, cy - 0.02, 0.06, r + 0.08, r: 0.03, fill: hair)
                    }
                    if sideRight { p.rect(cx - r - 0.02, cy - 0.04, 0.1, a.hair == .long ? r + 0.1 : 0.12, r: 0.04, fill: hair) }
                    if a.hair == .ponytail && sideRight { p.rect(cx - r - 0.06, cy - 0.01, 0.07, 0.18, r: 0.035, fill: hair) }
                }
            case .braids, .locs:
                if back { p.circle(cx, cy, r + 0.012, fill: hair) }
                else { cap(0.02) }
                let n = a.hair == .locs ? 6 : 4
                for k in 0..<n {
                    let x = cx - r + 0.02 + Double(k) * (2 * r - 0.04) / Double(max(1, n - 1))
                    if !sideRight || x < cx { p.rect(x - 0.022, cy - 0.02, 0.044, r + 0.1, r: 0.022, fill: hair.darker(Double(k % 2) * 0.08)) }
                }
            case .mohawk:
                if back { p.rect(cx - 0.035, cy - r - 0.06, 0.07, 2 * r, r: 0.035, fill: hair) } else {
                    p.rect(cx - 0.035 + (sideRight ? -0.03 : 0), cy - r - 0.07, 0.07, r * 0.9, r: 0.035, fill: hair)
                    p.arc(cx, cy, r - 0.01, -2.8, -0.34, color: hair.alpha(0.35), lw: 0.02)
                }
            case .gray:
                if back { p.circle(cx, cy - 0.005, r + 0.008, fill: hair) } else {
                    p.path([.move(Vec2(cx - r - 0.005, cy + 0.02)), .quad(Vec2(cx - r, cy - r * 0.6), Vec2(cx - r * 0.55, cy - r * 0.75)),
                            .line(Vec2(cx - r * 0.4, cy - r * 0.2)), .quad(Vec2(cx - r * 0.7, cy - 0.02), Vec2(cx - r - 0.005, cy + 0.02)), .close], fill: hair)
                    p.path([.move(Vec2(cx + r + 0.005, cy + 0.02)), .quad(Vec2(cx + r, cy - r * 0.6), Vec2(cx + r * 0.55, cy - r * 0.75)),
                            .line(Vec2(cx + r * 0.4, cy - r * 0.2)), .quad(Vec2(cx + r * 0.7, cy - 0.02), Vec2(cx + r + 0.005, cy + 0.02)), .close], fill: hair)
                }
            }
            switch a.accessory {
            case .cap:
                let capColor = a.garment == .co ? Palette.navy.darker(0.15) : (a.garment == .maintenance ? Palette.slate : Palette.coral)
                p.path([.move(Vec2(cx - r - 0.01, cy - 0.02)), .quad(Vec2(cx - r, cy - r - 0.04), Vec2(cx, cy - r - 0.04)),
                        .quad(Vec2(cx + r, cy - r - 0.04), Vec2(cx + r + 0.01, cy - 0.02)), .close], fill: capColor)
                if f == .down { p.rect(cx - r * 0.85, cy - 0.04, r * 1.7, 0.05, r: 0.025, fill: capColor.darker(0.15)) }
                else if sideRight { p.rect(cx, cy - 0.045, r + 0.06, 0.04, r: 0.02, fill: capColor.darker(0.15)) }
                if a.garment == .co && f == .down { p.circle(cx, cy - r + 0.02, 0.022, fill: Palette.ochre) }
            case .headband:
                p.rect(cx - r, cy - r * 0.55, 2 * r, 0.045, r: 0.02, fill: Palette.coral)
            case .bandana:
                p.rect(cx - r, cy - r * 0.7, 2 * r, 0.07, r: 0.03, fill: Palette.turquoise)
            case .headscarf:
                p.path([.move(Vec2(cx - r - 0.02, cy + 0.05)), .quad(Vec2(cx - r - 0.03, cy - r - 0.05), Vec2(cx, cy - r - 0.05)),
                        .quad(Vec2(cx + r + 0.03, cy - r - 0.05), Vec2(cx + r + 0.02, cy + 0.05)),
                        .quad(Vec2(cx, cy - r * 0.4), Vec2(cx - r - 0.02, cy + 0.05)), .close], fill: Palette.ochre.darker(0.05))
                if back { p.circle(cx, cy, r + 0.02, fill: Palette.ochre.darker(0.05)) }
            case .kufi:
                p.path([.move(Vec2(cx - r * 0.85, cy - r * 0.45)), .quad(Vec2(cx, cy - r - 0.06), Vec2(cx + r * 0.85, cy - r * 0.45)), .close], fill: Palette.paper)
            default: break
            }
            return Drawing(size: Vec2(D * T, D * T), anchor: Vec2(0.5, 0.86), shapes: p.shapes, shadowOffset: .zero, shadowBlur: 0)
        case .prop:
            return Drawing(size: Vec2(0.01, 0.01), anchor: Vec2(0.5, 0.5), shapes: [])
        }
    }

    /// Normalizes an appearance so parts that don't depend on some fields share textures.
    public static func key(_ part: FigurePart, _ a: Appearance, _ f: Facing) -> ArtKey {
        var n = a
        let face: Facing = f == .left ? .right : f
        switch part {
        case .shadow: n = Appearance(skin: 0, hair: .bald, hairColor: 0, garment: .scrubs, width: a.widthScale, height: 1)
            return .figure(.shadow, n, .down)
        case .legL, .legR:
            n = Appearance(skin: 0, hair: .bald, hairColor: 0, garment: a.garment, width: a.widthScale, height: a.heightScale)
            return .figure(.legL, n, face == .right ? .right : .down)
        case .armL, .armR:
            n = Appearance(skin: a.skin, hair: .bald, hairColor: 0, garment: a.garment, width: 1, height: a.heightScale)
            return .figure(.armL, n, .down)
        case .body:
            n = Appearance(skin: 0, hair: .bald, hairColor: 0, garment: a.garment, width: a.widthScale, height: a.heightScale)
            return .figure(.body, n, face)
        case .head:
            n = Appearance(skin: a.skin, hair: .bald, hairColor: a.hairColor, accessory: a.accessory, garment: .scrubs, width: 1, height: 1)
            return .figure(.head, n, face)
        case .hair:
            n = Appearance(skin: 0, hair: a.hair, hairColor: a.hairColor, accessory: a.accessory, garment: a.garment, width: 1, height: 1)
            return .figure(.hair, n, face)
        case .prop:
            return .figure(.prop, a, face)
        }
    }
}
