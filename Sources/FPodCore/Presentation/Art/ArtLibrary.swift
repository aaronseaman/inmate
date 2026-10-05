import Foundation

/// Turns an ArtKey into a vector Drawing (points). Pure: depends only on the key,
/// the tile size and the static map, so platform caches can key textures by ArtKey.
public final class ArtLibrary {
    public let tileSize: Double
    let map: WorldMap

    public init(tileSize: Double, map: WorldMap = WorldShared.map) {
        self.tileSize = tileSize
        self.map = map
    }

    public func drawing(_ key: ArtKey) -> Drawing {
        let T = tileSize
        switch key {
        case .chunk(let cx, let cy):
            return ChunkArt.draw(cx: cx, cy: cy, tile: T, map: map)
        case .door(let kind, let vertical, let open):
            return UIArt.door(kind, vertical: vertical, open: Double(open) / 4.0, tile: T)
        case .figure(let part, let a, let f):
            return FigureArt.draw(part, a, f, tile: T)
        case .prop(let kind, let w, let h, let variant):
            var p = Pen(scale: T)
            let o = WorldObject(id: "dyn", kind: kind, tile: TilePos(0, 0), w: w, h: h, facing: .down, zone: "", variant: variant)
            PropArt.draw(o, x: 0, y: 0, &p)
            return Drawing(size: Vec2(Double(w) * T, Double(h) * T), anchor: Vec2(0, 0), shapes: p.shapes,
                           shadowOffset: Vec2(0.05 * T, 0.07 * T), shadowBlur: 0.06 * T)
        case .icon(let icon, let size, let color):
            return IconArt.draw(icon, size: Double(size), color: color)
        case .badge(let icon, let size, let bg, let fg):
            return UIArt.badge(icon, size: Double(size), bg: bg, fg: fg)
        case .bubble(let icons, let alert):
            return UIArt.bubble(icons, alert: alert, tile: T)
        case .panel(let w, let h, let style):
            return UIArt.panel(Double(w), Double(h), style)
        case .shape(let spec):
            return UIArt.shape(spec)
        case .text(let spec):
            return UIArt.text(spec)
        case .button(let w, let h, let style):
            return UIArt.button(Double(w), Double(h), style)
        case .marker(let kind):
            return UIArt.marker(kind, tile: T)
        case .highlight(let w, let h):
            return UIArt.highlight(Double(w), Double(h), tile: T)
        case .mapOverview:
            return MapArt.overview(map)
        case .named(let name, let a, let b):
            return UIArt.named(name, a, b, tile: T)
        }
    }
}

enum UIArt {
    static func panel(_ w: Double, _ h: Double, _ style: PanelStyle) -> Drawing {
        var shapes: [Shape] = []
        let r = Rect(0, 0, w, h)
        switch style {
        case .card:
            shapes.append(Shape(.rect(r, radius: 14), fill: Palette.paper, shadow: true))
        case .sheet:
            shapes.append(Shape(.rect(r, radius: 18), fill: Palette.paper, shadow: true))
            shapes.append(Shape(.rect(Rect(22, 0, max(0, w - 44), 4), radius: 2), fill: Palette.turquoise.alpha(0.55)))
        case .chip:
            shapes.append(Shape(.rect(r, radius: h / 2), fill: Palette.paper.alpha(0.96), shadow: true))
        case .dark:
            shapes.append(Shape(.rect(r, radius: 12), fill: Palette.navy, shadow: true))
        case .toast:
            shapes.append(Shape(.rect(r, radius: h / 2), fill: Palette.ivory, shadow: true))
        case .danger:
            shapes.append(Shape(.rect(r, radius: min(h / 2, 12)), fill: Palette.coral, shadow: true))
        case .inset:
            shapes.append(Shape(.rect(r, radius: 10), fill: Palette.blueGray.alpha(0.45)))
        case .bar:
            shapes.append(Shape(.rect(r, radius: h / 2), fill: Palette.blueGray.alpha(0.7)))
        case .scrim:
            shapes.append(Shape(.rect(r, radius: 0), fill: Palette.ink.alpha(0.38)))
        case .highlight:
            shapes.append(Shape(.rect(r, radius: 10), fill: Palette.turquoise.alpha(0.22)))
        case .paperLine:
            shapes.append(Shape(.rect(r, radius: 0), fill: Palette.slate.alpha(0.18)))
        }
        if style == .card || style == .sheet || style == .chip || style == .toast {
            let rimRadius = style == .sheet ? 18.0 : (style == .card ? 14.0 : h / 2)
            shapes.append(Shape(.rect(r.insetBy(0.7), radius: max(0, rimRadius - 0.7)),
                                fill: nil, stroke: Palette.white.alpha(0.55), lineWidth: 0.8))
        }
        return Drawing(size: Vec2(w, h), anchor: Vec2(0, 0), shapes: shapes, shadowOffset: Vec2(1.2, 2), shadowBlur: 2.2)
    }

    static func button(_ w: Double, _ h: Double, _ style: ButtonStyle) -> Drawing {
        var s: [Shape] = []
        let r = Rect(0, 0, w, h)
        let round = min(w, h) / 2
        switch style {
        case .round:
            s.append(Shape(.ellipse(r), fill: Palette.paper, shadow: true))
            s.append(Shape(.ellipse(r.insetBy(0.9)), fill: nil, stroke: Palette.white.alpha(0.8), lineWidth: 1.2))
        case .roundLarge:
            s.append(Shape(.ellipse(r), fill: Palette.paper, shadow: true))
            s.append(Shape(.ellipse(r.insetBy(3)), fill: nil, stroke: Palette.turquoise, lineWidth: 3))
            s.append(Shape(.ellipse(r.insetBy(5.4)), fill: nil, stroke: Palette.white, lineWidth: 1.2))
        case .pill:
            s.append(Shape(.rect(r, radius: round), fill: Palette.paper, shadow: true))
        case .primary:
            s.append(Shape(.rect(r, radius: min(round, 14)), fill: Palette.navy, shadow: true))
        case .danger:
            s.append(Shape(.rect(r, radius: min(round, 14)), fill: Palette.coral, shadow: true))
        case .toggleOn:
            s.append(Shape(.ellipse(r), fill: Palette.turquoise.darker(0.12), shadow: true))
        case .toggleOff:
            s.append(Shape(.ellipse(r), fill: Palette.paper, shadow: true))
            s.append(Shape(.ellipse(r.insetBy(2.2)), fill: nil, stroke: Palette.blueGray, lineWidth: 1.6))
            s.append(Shape(.ellipse(r.insetBy(4)), fill: nil, stroke: Palette.white, lineWidth: 1.1))
        case .tab:
            s.append(Shape(.rect(r, radius: 10), fill: Palette.blueGray.alpha(0.35)))
        case .tabActive:
            s.append(Shape(.rect(r, radius: 10), fill: Palette.navy))
        case .ghost:
            s.append(Shape(.rect(r.insetBy(1), radius: min(round, 12)), fill: nil, stroke: Palette.slate.alpha(0.5), lineWidth: 1.5))
        case .tile:
            s.append(Shape(.rect(r, radius: 10), fill: Palette.ivory, shadow: true))
        case .tileSelected:
            s.append(Shape(.rect(r, radius: 10), fill: Palette.turquoise.darker(0.1), shadow: true))
        case .disabled:
            s.append(Shape(.rect(r, radius: min(round, 14)), fill: Palette.blueGray.alpha(0.35)))
        }
        return Drawing(size: Vec2(w, h), anchor: Vec2(0, 0), shapes: s, shadowOffset: Vec2(1.2, 2.0), shadowBlur: 2.2)
    }

    static func badge(_ icon: Icon, size: Double, bg: RGBA, fg: RGBA) -> Drawing {
        var s: [Shape] = [Shape(.ellipse(Rect(0, 0, size, size)), fill: bg, shadow: true)]
        s.append(Shape(.ellipse(Rect(0.7, 0.7, size - 1.4, size - 1.4)), fill: nil, stroke: Palette.white.alpha(0.5), lineWidth: 0.8))
        let inner = IconArt.draw(icon, size: size * 0.62, color: fg)
        for var sh in inner.shapes { sh.geom = offset(sh.geom, Vec2(size * 0.19, size * 0.19)); s.append(sh) }
        return Drawing(size: Vec2(size, size), anchor: Vec2(0, 0), shapes: s, shadowOffset: Vec2(1, 1.6), shadowBlur: 1.5)
    }

    /// Pictogram speech bubble: paper card with a tail; anchor at the tail tip.
    static func bubble(_ icons: [Icon], alert: Bool, tile T: Double) -> Drawing {
        let isz = max(14, T * 0.52)
        let pad = isz * 0.28
        let n = max(1, icons.count)
        let w = Double(n) * isz + Double(n - 1) * pad * 0.5 + pad * 2
        let h = isz + pad * 2
        var s: [Shape] = []
        let body = Rect(0, 0, w, h)
        s.append(Shape(.rect(body, radius: h * 0.42), fill: Palette.paper, stroke: alert ? Palette.coral : nil, lineWidth: alert ? 2 : 0, shadow: true))
        s.append(Shape(.poly([Vec2(w / 2 - h * 0.18, h - 1), Vec2(w / 2, h + h * 0.32), Vec2(w / 2 + h * 0.18, h - 1)]), fill: Palette.paper, shadow: false))
        for (k, ic) in icons.enumerated() {
            let color: RGBA = (ic == .exclaim || ic == .stop) ? Palette.coral : (ic == .zzz ? Palette.navy : Palette.ink)
            let d = IconArt.draw(ic, size: isz, color: color)
            let ox = pad + Double(k) * (isz + pad * 0.5)
            for var sh in d.shapes { sh.geom = offset(sh.geom, Vec2(ox, pad)); s.append(sh) }
        }
        return Drawing(size: Vec2(w, h + h * 0.34), anchor: Vec2(0.5, 1.0), shapes: s, shadowOffset: Vec2(1, 1.6), shadowBlur: 1.6)
    }

    static func shape(_ spec: ShapeSpec) -> Drawing {
        let r = Rect(0, 0, spec.w, spec.h)
        var g: Geom
        switch spec.kind {
        case .rect: g = .rect(r, radius: spec.radius)
        case .circle: g = .ellipse(r)
        case .ring: g = .ellipse(r.insetBy(spec.lineWidth / 2))
        case .capsule: g = .rect(r, radius: min(spec.w, spec.h) / 2)
        case .diamond: g = .poly([Vec2(spec.w / 2, 0), Vec2(spec.w, spec.h / 2), Vec2(spec.w / 2, spec.h), Vec2(0, spec.h / 2)])
        case .triangle: g = .poly([Vec2(spec.w / 2, 0), Vec2(spec.w, spec.h), Vec2(0, spec.h)])
        case .cone: g = .poly([Vec2(0, spec.h / 2), Vec2(spec.w, 0), Vec2(spec.w, spec.h)])
        }
        let fill = spec.kind == .ring ? nil : spec.fill
        let stroke = spec.kind == .ring ? (spec.stroke ?? spec.fill) : spec.stroke
        return Drawing(size: Vec2(spec.w, spec.h), anchor: Vec2(0, 0), shapes: [Shape(g, fill: fill, stroke: stroke, lineWidth: spec.lineWidth, shadow: spec.shadow)],
                       shadowOffset: Vec2(1, 1.6), shadowBlur: 1.6)
    }

    static func text(_ spec: TextSpec) -> Drawing {
        let lh = TextMetrics.lineHeight(spec.size)
        var s: [Shape] = []
        for (k, line) in spec.lines.enumerated() {
            let x: Double
            switch spec.align {
            case .left: x = 0
            case .center: x = spec.width / 2
            case .right: x = spec.width
            }
            s.append(Shape(.text(TextRun(line, pos: Vec2(x, Double(k) * lh), size: spec.size, weight: spec.weight, color: spec.color, align: spec.align))))
        }
        return Drawing(size: Vec2(spec.width, Double(max(1, spec.lines.count)) * lh), anchor: Vec2(0, 0), shapes: s)
    }

    static func door(_ kind: DoorKind, vertical: Bool, open: Double, tile T: Double) -> Drawing {
        var p = Pen(scale: T)
        let color: RGBA
        switch kind {
        case .cell: color = Palette.slate
        case .secure: color = Palette.navy.lighter(0.1)
        case .gate: color = Palette.slate.alpha(0.8)
        case .hatch: color = Palette.metal
        case .interior: color = Palette.wood.darker(0.05)
        }
        // Frame (threshold) and a sliding leaf that retracts as it opens.
        let leaf = 1.0 - open * 0.85
        if vertical {
            p.rect(0.3, 0.0, 0.4, 1.0, fill: Palette.wallEdge.alpha(0.55))
            p.rect(0.36, 0.0, 0.28, leaf, r: 0.05, fill: color, shadow: true)
            if kind == .cell { for k in 0..<3 { p.line([(0.36, 0.2 + Double(k) * 0.25 * leaf), (0.64, 0.2 + Double(k) * 0.25 * leaf)], color: Palette.blueGray, lw: 0.03) } }
            if kind == .secure { p.circle(0.5, leaf * 0.5, 0.06, fill: open > 0.5 ? Palette.statusGreen : Palette.coral) }
        } else {
            p.rect(0.0, 0.3, 1.0, 0.4, fill: Palette.wallEdge.alpha(0.55))
            p.rect(0.0, 0.36, leaf, 0.28, r: 0.05, fill: color, shadow: true)
            if kind == .cell { for k in 0..<4 { p.line([(0.12 + Double(k) * 0.24 * leaf, 0.36), (0.12 + Double(k) * 0.24 * leaf, 0.64)], color: Palette.blueGray, lw: 0.03) } }
            if kind == .secure { p.circle(leaf * 0.5, 0.5, 0.06, fill: open > 0.5 ? Palette.statusGreen : Palette.coral) }
        }
        return Drawing(size: Vec2(T, T), anchor: Vec2(0, 0), shapes: p.shapes, shadowOffset: Vec2(0.04 * T, 0.05 * T), shadowBlur: 0.04 * T)
    }

    static func marker(_ kind: Int, tile T: Double) -> Drawing {
        var p = Pen(scale: T)
        switch kind {
        case 0: // tap destination
            p.circle(0.5, 0.5, 0.26, fill: nil, stroke: Palette.navy.alpha(0.7), lw: 0.06)
            p.circle(0.5, 0.5, 0.08, fill: Palette.navy.alpha(0.7))
            return Drawing(size: Vec2(T, T), anchor: Vec2(0.5, 0.5), shapes: p.shapes)
        case 1: // objective chevron
            p.path([.move(Vec2(0.26, 0.1)), .line(Vec2(0.74, 0.1)),
                    .quad(Vec2(0.81, 0.1), Vec2(0.77, 0.17)), .line(Vec2(0.55, 0.57)),
                    .quad(Vec2(0.5, 0.65), Vec2(0.45, 0.57)), .line(Vec2(0.23, 0.17)),
                    .quad(Vec2(0.19, 0.1), Vec2(0.26, 0.1)), .close],
                   fill: Palette.ochre, stroke: Palette.ochre.darker(0.12), lw: 0.025, shadow: true)
            p.line([(0.28, 0.13), (0.72, 0.13)], color: Palette.ochre.lighter(0.35), lw: 0.025)
            return Drawing(size: Vec2(T, T * 0.7), anchor: Vec2(0.5, 1.0), shapes: p.shapes)
        case 2: // search cue (flashlight wedge)
            p.wedge(0.1, 0.5, 0.9, -0.5, 0.5, fill: Palette.ochre.alpha(0.35))
            return Drawing(size: Vec2(T, T), anchor: Vec2(0.1, 0.5), shapes: p.shapes)
        case 3: // hidden player peek
            p.circle(0.5, 0.5, 0.2, fill: Palette.paper.alpha(0.85), shadow: true)
            p.circle(0.44, 0.5, 0.04, fill: Palette.ink); p.circle(0.56, 0.5, 0.04, fill: Palette.ink)
            return Drawing(size: Vec2(T, T), anchor: Vec2(0.5, 0.5), shapes: p.shapes)
        case 4: // changing progress ring background
            p.circle(0.5, 0.5, 0.4, fill: nil, stroke: Palette.paper.alpha(0.9), lw: 0.08)
            return Drawing(size: Vec2(T, T), anchor: Vec2(0.5, 0.5), shapes: p.shapes)
        default: // security camera body
            p.rect(0.25, 0.3, 0.5, 0.4, r: 0.08, fill: Palette.slate, shadow: true)
            p.circle(0.68, 0.5, 0.1, fill: Palette.ink); p.circle(0.34, 0.4, 0.05, fill: Palette.coral)
            return Drawing(size: Vec2(T, T), anchor: Vec2(0.5, 0.5), shapes: p.shapes)
        }
    }

    /// Target outline: a single clear paper ring under the chosen interactable.
    static func highlight(_ w: Double, _ h: Double, tile T: Double) -> Drawing {
        let W = w * T, H = h * T
        let s = [Shape(.rect(Rect(1.5, 1.5, W - 3, H - 3), radius: min(W, H) * 0.3), fill: Palette.turquoise.alpha(0.12), stroke: Palette.turquoise.darker(0.15), lineWidth: 2.5)]
        return Drawing(size: Vec2(W, H), anchor: Vec2(0.5, 0.5), shapes: s)
    }

    static func named(_ name: String, _ a: Int, _ b: Int, tile T: Double) -> Drawing {
        switch name {
        case "progress":
            // Pie progress, a = 0...20
            var p = Pen(scale: T)
            p.wedge(0.5, 0.5, 0.36, -.pi / 2, -.pi / 2 + 2 * .pi * Double(a) / 20.0, fill: Palette.turquoise.alpha(0.85))
            return Drawing(size: Vec2(T, T), anchor: Vec2(0.5, 0.5), shapes: p.shapes)
        case "stars":
            var p = Pen(scale: 1)
            for k in 0..<3 { p.star(16 + Double(k) * 34, 16, 14, fill: k < a ? Palette.ochre : Palette.blueGray) }
            return Drawing(size: Vec2(100, 32), anchor: Vec2(0, 0), shapes: p.shapes)
        case "trustdots":
            var p = Pen(scale: 1)
            for k in 0..<5 { p.circle(7 + Double(k) * 16, 7, 6, fill: k < a ? Palette.turquoise.darker(0.15) : Palette.blueGray) }
            return Drawing(size: Vec2(84, 14), anchor: Vec2(0, 0), shapes: p.shapes)
        case "meter":
            // a = fill 0...100, b = color index
            let colors = [Palette.statusGreen, Palette.statusYellow, Palette.coral, Palette.turquoise, Palette.ochre]
            let w = 120.0, h = 10.0
            let s = [Shape(.rect(Rect(0, 0, w, h), radius: 5), fill: Palette.blueGray.alpha(0.6)),
                     Shape(.rect(Rect(0, 0, max(h, w * Double(a) / 100.0), h), radius: 5), fill: colors[b % colors.count])]
            return Drawing(size: Vec2(w, h), anchor: Vec2(0, 0), shapes: s)
        case "vehicle":
            return VehicleArt.drawing(Vehicle.allCases[min(max(0, a), Vehicle.allCases.count - 1)], tile: T)
        case "suit":
            return ChessArt.suit(a, size: Double(b))
        case "chess":
            // a = piece (1 pawn ... 6 king; negative = black), b = size in points.
            return ChessArt.piece(a, size: Double(b))
        case "fade":
            return Drawing(size: Vec2(Double(a), Double(b)), anchor: Vec2(0, 0), shapes: [Shape(.rect(Rect(0, 0, Double(a), Double(b)), radius: 0), fill: Palette.ink)])
        case "noise":
            var p = Pen(scale: 1)
            p.circle(Double(a) / 2, Double(a) / 2, Double(a) / 2 - 2, fill: nil, stroke: (b == 1 ? Palette.coral : Palette.slate).alpha(0.7), lw: 2.5)
            return Drawing(size: Vec2(Double(a), Double(a)), anchor: Vec2(0.5, 0.5), shapes: p.shapes)
        default:
            return Drawing(size: Vec2(1, 1), anchor: Vec2(0, 0), shapes: [])
        }
    }

    static func offset(_ g: Geom, _ d: Vec2) -> Geom {
        switch g {
        case .rect(let r, let rad): return .rect(r.offsetBy(d), radius: rad)
        case .ellipse(let r): return .ellipse(r.offsetBy(d))
        case .poly(let pts): return .poly(pts.map { $0 + d })
        case .polyline(let pts): return .polyline(pts.map { $0 + d })
        case .path(let ops):
            return .path(ops.map { op in
                switch op {
                case .move(let v): return .move(v + d)
                case .line(let v): return .line(v + d)
                case .quad(let c, let v): return .quad(c + d, v + d)
                case .cubic(let a, let b, let v): return .cubic(a + d, b + d, v + d)
                case .close: return .close
                }
            })
        case .text(var t): t.pos = t.pos + d; return .text(t)
        }
    }
}
