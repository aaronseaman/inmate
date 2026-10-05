import Foundation

/// Floor-plan furniture: restrained rounded shapes, two or three tones, soft paper shadow.
/// Drawn in tile units through a Pen scaled to points.
enum PropArt {
    static func draw(_ o: WorldObject, x: Double, y: Double, _ p: inout Pen) {
        let w = Double(o.w), h = Double(o.h)
        let ink = Palette.ink, paper = Palette.paper
        let metal = Palette.metal, wood = Palette.wood, slate = Palette.slate
        let vert = h > w
        switch o.kind {
        case .bunk:
            p.rect(x + 0.06, y + 0.06, w - 0.12, h - 0.12, r: 0.1, fill: slate, shadow: true)
            p.rect(x + 0.12, y + 0.12, w - 0.24, h - 0.24, r: 0.08, fill: Palette.ivory)
            // Pillow at the head end, blanket over most of the mattress.
            let headTop = o.facing != .up
            if vert {
                p.rect(x + 0.18, headTop ? y + 0.18 : y + h - 0.5, w - 0.36, 0.3, r: 0.1, fill: paper)
                p.rect(x + 0.12, headTop ? y + 0.6 : y + 0.12, w - 0.24, h - 0.72, r: 0.08, fill: Palette.tan.darker(0.05))
                p.line([(x + 0.14, headTop ? y + 0.9 : y + h - 0.9), (x + w - 0.14, headTop ? y + 0.9 : y + h - 0.9)], color: Palette.tan.darker(0.25), lw: 0.04)
            } else {
                p.rect(x + 0.18, y + 0.18, 0.3, h - 0.36, r: 0.1, fill: paper)
                p.rect(x + 0.6, y + 0.12, w - 0.72, h - 0.24, r: 0.08, fill: Palette.tan.darker(0.05))
            }
        case .bed:
            p.rect(x + 0.08, y + 0.08, w - 0.16, h - 0.16, r: 0.12, fill: metal, shadow: true)
            p.rect(x + 0.14, y + 0.14, w - 0.28, h - 0.28, r: 0.1, fill: paper)
            p.rect(x + 0.3, y + 0.22, w - 0.6, 0.34, r: 0.12, fill: Palette.ivory)
            p.rect(x + 0.14, y + 0.9, w - 0.28, h - 1.1, r: 0.1, fill: Palette.turquoise.lighter(0.35))
        case .mattress:
            p.rect(x + 0.1, y + 0.1, w - 0.2, h - 0.2, r: 0.16, fill: Palette.blueGray, shadow: true)
            p.line([(x + 0.2, y + h * 0.5), (x + w - 0.2, y + h * 0.5)], color: Palette.blueGray.darker(0.1), lw: 0.04)
        case .table:
            let top = o.zone.hasPrefix("visit") || o.zone.hasPrefix("admin") ? wood.lighter(0.2) : Palette.blueGray.lighter(0.25)
            p.rect(x + 0.08, y + 0.1, w - 0.16, h - 0.2, r: 0.16, fill: top, shadow: true)
            if o.zone.hasPrefix("kitchen.dining") {
                for k in 0..<Int(w) { p.rect(x + Double(k) + 0.25, y + 0.3, 0.5, h - 0.6, r: 0.08, fill: Palette.ivory.darker(0.04)) }
            } else if o.zone.hasPrefix("fpod") {
                p.rect(x + w * 0.5 - 0.3, y + h * 0.5 - 0.2, 0.6, 0.4, r: 0.06, fill: Palette.ivory)
            }
        case .bench:
            p.rect(x + 0.04, y + 0.2, w - 0.08, h - 0.4, r: 0.1, fill: wood, shadow: true)
            p.line([(x + 0.1, y + h * 0.5), (x + w - 0.1, y + h * 0.5)], color: wood.darker(0.15), lw: 0.03)
        case .chair:
            p.rect(x + 0.2, y + 0.22, 0.6, 0.6, r: 0.14, fill: Palette.turquoise.darker(0.05), shadow: true)
            p.rect(x + 0.2, y + 0.16, 0.6, 0.16, r: 0.06, fill: Palette.turquoise.darker(0.25))
        case .tv:
            p.rect(x + 0.1, y + 0.08, w - 0.2, h - 0.16, r: 0.06, fill: ink, shadow: true)
            p.rect(x + 0.16, y + 0.14, w - 0.32, h - 0.28, r: 0.04, fill: Palette.turquoise.darker(0.2))
            p.rect(x + 0.2, y + 0.2, (w - 0.4) * 0.5, (h - 0.4) * 0.4, r: 0.03, fill: Palette.turquoise.lighter(0.25))
        case .desk:
            p.rect(x + 0.06, y + 0.12, w - 0.12, h - 0.24, r: 0.08, fill: wood.lighter(0.1), shadow: true)
            p.rect(x + w * 0.62, y + 0.2, w * 0.28, h - 0.4, r: 0.04, fill: slate)
            p.rect(x + 0.2, y + 0.24, w * 0.3, h - 0.5, r: 0.02, fill: paper)
        case .counter:
            p.rect(x + 0.04, y + 0.06, w - 0.08, h - 0.12, r: 0.06, fill: Palette.wallTop, shadow: true)
            p.rect(x + 0.04, y + h - 0.2, w - 0.08, 0.14, r: 0.04, fill: Palette.wallEdge)
        case .shelf, .stack:
            p.rect(x + 0.06, y + 0.04, w - 0.12, h - 0.08, r: 0.06, fill: wood.darker(0.1), shadow: true)
            let colors = [Palette.ochre, Palette.coral, Palette.turquoise, Palette.navy, Palette.tan, Palette.slate, Palette.blueGray]
            let n = Int(max(w, h) * 4)
            for k in 0..<n {
                let c = colors[(k * 3 + o.variant + Int(o.tile.x)) % colors.count]
                if vert {
                    p.rect(x + 0.14, y + 0.08 + Double(k) * (h - 0.16) / Double(n), w - 0.28, (h - 0.16) / Double(n) - 0.03, r: 0.02, fill: c)
                } else {
                    p.rect(x + 0.08 + Double(k) * (w - 0.16) / Double(n), y + 0.14, (w - 0.16) / Double(n) - 0.03, h - 0.28, r: 0.02, fill: c)
                }
            }
        case .locker:
            p.rect(x + 0.1, y + 0.08, w - 0.2, h - 0.16, r: 0.06, fill: metal.darker(0.08), shadow: true)
            for k in 0..<3 { p.line([(x + 0.25, y + 0.25 + Double(k) * 0.12), (x + 0.75, y + 0.25 + Double(k) * 0.12)], color: metal.darker(0.3), lw: 0.04) }
            p.circle(x + 0.72, y + 0.68, 0.06, fill: Palette.ochre)
        case .toilet:
            p.rect(x + 0.24, y + 0.1, 0.52, 0.24, r: 0.08, fill: metal.lighter(0.4), shadow: true)
            p.oval(x + 0.22, y + 0.3, 0.56, 0.6, fill: metal.lighter(0.55), shadow: true)
            p.oval(x + 0.32, y + 0.42, 0.36, 0.38, fill: Palette.blueGray)
        case .sink:
            p.rect(x + 0.1, y + 0.12, w - 0.2, h - 0.24, r: 0.16, fill: metal.lighter(0.5), shadow: true)
            p.oval(x + 0.24, y + 0.28, w - 0.48, h - 0.5, fill: Palette.blueGray)
            p.rect(x + w * 0.5 - 0.04, y + 0.14, 0.08, 0.18, r: 0.03, fill: slate)
        case .shower:
            p.rect(x + 0.04, y + 0.04, w - 0.08, h - 0.08, r: 0.06, fill: Palette.turquoise.lighter(0.55))
            for k in 1..<Int(h * 3) { p.line([(x + 0.06, y + Double(k) / 3), (x + w - 0.06, y + Double(k) / 3)], color: Palette.turquoise.lighter(0.3), lw: 0.02) }
            p.circle(x + w * 0.5, y + h * 0.5, 0.06, fill: slate)
            p.line([(x + 0.08, y + 0.1), (x + w - 0.08, y + 0.1)], color: Palette.coral.lighter(0.2), lw: 0.06)
        case .divider:
            p.rect(x + 0.38, y + 0.02, 0.24, h - 0.04, r: 0.06, fill: slate.lighter(0.2), shadow: true)
        case .washer, .dryer:
            p.rect(x + 0.08, y + 0.08, w - 0.16, h - 0.16, r: 0.1, fill: paper, shadow: true)
            p.circle(x + w * 0.5, y + h * 0.56, 0.26, fill: slate.lighter(0.3))
            p.circle(x + w * 0.5, y + h * 0.56, 0.18, fill: o.kind == .washer ? Palette.turquoise.lighter(0.25) : Palette.blueGray)
            p.rect(x + 0.18, y + 0.14, 0.3, 0.08, r: 0.03, fill: Palette.blueGray)
        case .foldTable:
            p.rect(x + 0.06, y + 0.1, w - 0.12, h - 0.2, r: 0.1, fill: paper, shadow: true)
            for k in 0..<Int(w) { p.rect(x + Double(k) + 0.2, y + 0.3, 0.6, 0.4, r: 0.06, fill: [Palette.tan, Palette.blueGray, Palette.ivory][k % 3]) }
        case .hamper:
            p.rect(x + 0.12, y + 0.12, w - 0.24, h - 0.24, r: 0.22, fill: wood, shadow: true)
            p.circle(x + 0.42, y + 0.44, 0.16, fill: Palette.ivory); p.circle(x + 0.6, y + 0.56, 0.14, fill: Palette.tan)
        case .mopBucket:
            p.circle(x + 0.5, y + 0.55, 0.32, fill: Palette.ochre, shadow: true)
            p.circle(x + 0.5, y + 0.55, 0.2, fill: Palette.blueGray)
            p.line([(x + 0.5, y + 0.55), (x + 0.86, y + 0.1)], color: wood.darker(0.2), lw: 0.07)
        case .closetShelf:
            p.rect(x + 0.06, y + 0.06, w - 0.12, h - 0.12, r: 0.06, fill: wood.lighter(0.05), shadow: true)
            let n = Int(max(w, h) * 2)
            for k in 0..<n {
                let c = [Palette.ivory, Palette.tan, Palette.navy, Palette.blueGray, Palette.ochre][(k + o.variant + o.tile.y) % 5]
                if vert { p.rect(x + 0.16, y + 0.14 + Double(k) * (h - 0.28) / Double(n), w - 0.32, (h - 0.28) / Double(n) - 0.06, r: 0.05, fill: c) }
                else { p.rect(x + 0.14 + Double(k) * (w - 0.28) / Double(n), y + 0.16, (w - 0.28) / Double(n) - 0.06, h - 0.32, r: 0.05, fill: c) }
            }
        case .stove:
            p.rect(x + 0.06, y + 0.08, w - 0.12, h - 0.16, r: 0.06, fill: slate, shadow: true)
            for k in 0..<Int(w) { p.circle(x + Double(k) + 0.5, y + 0.5, 0.22, fill: ink.lighter(0.15)); p.circle(x + Double(k) + 0.5, y + 0.5, 0.1, fill: Palette.coral.darker(0.1)) }
        case .prepTable:
            p.rect(x + 0.06, y + 0.1, w - 0.12, h - 0.2, r: 0.06, fill: metal.lighter(0.25), shadow: true)
            p.rect(x + 0.4, y + 0.4, 1.0, 0.7, r: 0.06, fill: wood.lighter(0.2))
            p.circle(x + w - 0.8, y + h * 0.5, 0.25, fill: Palette.coral.lighter(0.1)); p.circle(x + w - 1.4, y + h * 0.5, 0.2, fill: Palette.statusGreen)
        case .dishRack:
            p.rect(x + 0.06, y + 0.1, w - 0.12, h - 0.2, r: 0.06, fill: metal, shadow: true)
            for k in 0..<Int(w * 4) { p.line([(x + 0.15 + Double(k) * 0.25, y + 0.2), (x + 0.15 + Double(k) * 0.25, y + h - 0.2)], color: metal.darker(0.3), lw: 0.03) }
        case .fridge:
            p.rect(x + 0.06, y + 0.06, w - 0.12, h - 0.12, r: 0.08, fill: paper, shadow: true)
            p.line([(x + w * 0.5, y + 0.1), (x + w * 0.5, y + h - 0.1)], color: Palette.blueGray, lw: 0.04)
            p.rect(x + w * 0.5 - 0.2, y + 0.3, 0.06, 0.3, r: 0.02, fill: slate); p.rect(x + w * 0.5 + 0.14, y + 0.3, 0.06, 0.3, r: 0.02, fill: slate)
        case .pantry:
            p.rect(x + 0.06, y + 0.06, w - 0.12, h - 0.12, r: 0.06, fill: wood.darker(0.05), shadow: true)
            let n = Int(max(w, h) * 3)
            for k in 0..<n {
                let c = [Palette.ochre, Palette.coral.lighter(0.2), Palette.ivory, Palette.statusGreen.lighter(0.2)][(k + o.tile.x) % 4]
                if vert { p.circle(x + w * 0.5, y + 0.3 + Double(k) * (h - 0.6) / Double(max(1, n - 1)), 0.13, fill: c) }
                else { p.rect(x + 0.14 + Double(k) * (w - 0.28) / Double(n), y + 0.22, (w - 0.28) / Double(n) - 0.05, h - 0.44, r: 0.04, fill: c) }
            }
        case .crate:
            p.rect(x + 0.1, y + 0.1, w - 0.2, h - 0.2, r: 0.05, fill: wood, shadow: true)
            p.line([(x + 0.14, y + 0.14), (x + w - 0.14, y + h - 0.14)], color: wood.darker(0.2), lw: 0.05)
            p.line([(x + 0.14, y + h * 0.5), (x + w - 0.14, y + h * 0.5)], color: wood.darker(0.2), lw: 0.04)
        case .sewing:
            p.rect(x + 0.06, y + 0.12, w - 0.12, h - 0.24, r: 0.08, fill: wood.lighter(0.15), shadow: true)
            p.rect(x + 0.3, y + 0.24, 0.9, 0.5, r: 0.12, fill: Palette.turquoise.darker(0.15))
            p.rect(x + 0.5, y + 0.34, 0.5, 0.18, r: 0.06, fill: paper)
        case .workbench:
            p.rect(x + 0.06, y + 0.08, w - 0.12, h - 0.16, r: 0.06, fill: wood, shadow: true)
            p.rect(x + 0.4, y + 0.4, 0.8, 0.4, r: 0.04, fill: metal)
            p.line([(x + w - 1.2, y + 0.5), (x + w - 0.5, y + 1.0)], color: slate, lw: 0.08)
            p.circle(x + w - 0.6, y + h - 0.5, 0.15, fill: Palette.ochre)
        case .toolBoard:
            p.rect(x + 0.08, y + 0.04, w - 0.16, h - 0.08, r: 0.04, fill: Palette.tan, shadow: true)
            for k in 0..<Int(h * 2) { p.rect(x + 0.24, y + 0.2 + Double(k) * 0.5, 0.5, 0.12, r: 0.03, fill: slate) }
        case .console:
            p.rect(x + 0.04, y + 0.1, w - 0.08, h - 0.2, r: 0.06, fill: slate, shadow: true)
            for k in 0..<Int(w) { p.rect(x + Double(k) + 0.14, y + 0.18, 0.72, 0.38, r: 0.03, fill: Palette.turquoise.darker(0.25)) }
            for k in 0..<Int(w * 3) { p.circle(x + 0.2 + Double(k) * 0.33, y + 0.74, 0.05, fill: [Palette.statusGreen, Palette.ochre, Palette.coral][k % 3]) }
        case .keyCabinet:
            p.rect(x + 0.08, y + 0.06, w - 0.16, h - 0.12, r: 0.05, fill: metal.darker(0.15), shadow: true)
            for k in 0..<Int(h * 3) { p.circle(x + 0.5, y + 0.3 + Double(k) * 0.33, 0.06, fill: Palette.ochre) }
        case .phone:
            p.rect(x + 0.22, y + 0.16, 0.56, 0.68, r: 0.1, fill: slate, shadow: true)
            p.rect(x + 0.3, y + 0.22, 0.16, 0.56, r: 0.07, fill: ink)
            for k in 0..<3 { p.circle(x + 0.6, y + 0.32 + Double(k) * 0.16, 0.04, fill: paper) }
        case .medWindow:
            p.rect(x + 0.04, y + 0.12, w - 0.08, h - 0.4, r: 0.08, fill: Palette.wallTop, shadow: true)
            p.rect(x + w * 0.5 - 0.18, y + 0.22, 0.36, 0.22, r: 0.06, fill: paper)
            p.circle(x + w * 0.5, y + 0.33, 0.06, fill: Palette.turquoise)
        case .commissary:
            p.rect(x + 0.04, y + 0.12, w - 0.08, h - 0.3, r: 0.08, fill: Palette.ochre.lighter(0.25), shadow: true)
            p.rect(x + 0.2, y + 0.22, 0.3, 0.3, r: 0.05, fill: Palette.coral.lighter(0.2)); p.rect(x + 0.6, y + 0.22, 0.4, 0.3, r: 0.05, fill: Palette.turquoise.lighter(0.2))
        case .noticeBoard:
            p.rect(x + 0.08, y + 0.08, w - 0.16, h - 0.16, r: 0.06, fill: Palette.ochre.darker(0.05), shadow: true)
            p.rect(x + 0.2, y + 0.18, 0.3, 0.3, r: 0.02, fill: paper)
            if max(w, h) > 1 { p.rect(x + w - 0.6, y + h - 0.6, 0.36, 0.36, r: 0.02, fill: Palette.blueGray.lighter(0.3)) }
            p.circle(x + 0.35, y + 0.2, 0.04, fill: Palette.coral)
        case .pew:
            p.rect(x + 0.04, y + 0.18, w - 0.08, h - 0.36, r: 0.1, fill: wood.darker(0.08), shadow: true)
            p.rect(x + 0.04, y + 0.12, w - 0.08, 0.14, r: 0.05, fill: wood.darker(0.25))
        case .altar:
            p.rect(x + 0.06, y + 0.12, w - 0.12, h - 0.24, r: 0.08, fill: wood.darker(0.1), shadow: true)
            p.rect(x + 0.3, y + 0.12, w - 0.6, h - 0.24, fill: Palette.paper)
            p.circle(x + 0.5, y + 0.5, 0.08, fill: Palette.ochre); p.circle(x + w - 0.5, y + 0.5, 0.08, fill: Palette.ochre)
        case .plant:
            p.circle(x + 0.5, y + 0.55, 0.26, fill: Palette.coral.darker(0.15), shadow: true)
            p.circle(x + 0.38, y + 0.42, 0.2, fill: Palette.grassDark); p.circle(x + 0.62, y + 0.4, 0.18, fill: Palette.grassDark.lighter(0.1)); p.circle(x + 0.5, y + 0.28, 0.16, fill: Palette.statusGreen)
        case .weights:
            p.rect(x + 0.2, y + 0.24, w - 0.4, h - 0.48, r: 0.12, fill: Palette.navy.lighter(0.15), shadow: true)
            p.line([(x + 0.1, y + 0.3), (x + w - 0.1, y + 0.3)], color: slate.darker(0.2), lw: 0.06)
            p.circle(x + 0.18, y + 0.3, 0.16, fill: ink); p.circle(x + w - 0.18, y + 0.3, 0.16, fill: ink)
        case .hoop:
            p.rect(x + 0.1, y + 0.02, w - 0.2, 0.22, r: 0.04, fill: paper, shadow: true)
            p.circle(x + w * 0.5, y + 0.5, 0.26, fill: nil, stroke: Palette.coral, lw: 0.08)
        case .horseshoes:
            p.rect(x + 0.0, y + 0.1, w, h - 0.2, r: 0.2, fill: Palette.ochre.lighter(0.3))
            p.circle(x + 0.5, y + 0.5, 0.07, fill: slate)
        case .garden:
            p.rect(x + 0.04, y + 0.06, w - 0.08, h - 0.12, r: 0.12, fill: Palette.wood.darker(0.25), shadow: true)
            for i in 0..<Int(w * 2) {
                for j in 0..<Int(h * 2) {
                    p.circle(x + 0.26 + Double(i) * 0.5, y + 0.28 + Double(j) * 0.48, 0.12, fill: (i + j + o.variant) % 3 == 0 ? Palette.statusGreen : Palette.grassDark)
                }
            }
        case .bleacher:
            for k in 0..<Int(h * 2) { p.rect(x + 0.04, y + 0.06 + Double(k) * 0.5, w - 0.08, 0.38, r: 0.06, fill: metal.lighter(Double(k) * 0.12), shadow: k == 0) }
        case .tree:
            p.circle(x + 0.56, y + 0.6, 0.48, fill: Palette.shadow)
            p.circle(x + 0.5, y + 0.5, 0.46, fill: Palette.woodsDark)
            p.circle(x + 0.4, y + 0.4, 0.3, fill: Palette.woods)
            p.circle(x + 0.62, y + 0.36, 0.2, fill: Palette.grassDark)
        case .tower:
            p.rect(x + 0.1, y + 0.1, w - 0.2, h - 0.2, r: 0.12, fill: slate, shadow: true)
            p.rect(x + 0.3, y + 0.3, w - 0.6, h - 0.6, r: 0.08, fill: Palette.navy)
            p.circle(x + w * 0.5, y + h * 0.5, 0.2, fill: Palette.ochre.lighter(0.3))
        case .dumpster:
            p.rect(x + 0.06, y + 0.1, w - 0.12, h - 0.2, r: 0.08, fill: Palette.grassDark.darker(0.25), shadow: true)
            p.line([(x + w * 0.5, y + 0.14), (x + w * 0.5, y + h - 0.14)], color: Palette.grassDark.darker(0.45), lw: 0.04)
        case .vent:
            if o.variant == 1 {
                p.rect(x + 0.14, y + 0.14, 0.72, 0.72, r: 0.04, fill: nil, stroke: slate.alpha(0.45), lw: 0.04)
            } else {
                p.rect(x + 0.22, y + 0.08, 0.56, 0.3, r: 0.04, fill: metal, shadow: true)
                for k in 0..<3 { p.line([(x + 0.28, y + 0.14 + Double(k) * 0.08), (x + 0.72, y + 0.14 + Double(k) * 0.08)], color: slate, lw: 0.03) }
            }
        case .drain:
            p.circle(x + 0.5, y + 0.5, 0.2, fill: metal.darker(0.2))
            p.line([(x + 0.36, y + 0.5), (x + 0.64, y + 0.5)], color: ink, lw: 0.03)
        case .hatch:
            p.rect(x + 0.12, y + 0.12, 0.76, 0.76, r: 0.06, fill: metal.darker(0.1))
            p.rect(x + 0.2, y + 0.2, 0.6, 0.6, r: 0.04, fill: nil, stroke: metal.darker(0.35), lw: 0.04)
            p.rect(x + 0.42, y + 0.44, 0.16, 0.12, r: 0.03, fill: slate)
        case .donationBox:
            p.rect(x + 0.08, y + 0.14, w - 0.16, h - 0.28, r: 0.04, fill: Palette.tan.darker(0.05), shadow: true)
            p.line([(x + 0.1, y + h * 0.5), (x + w - 0.1, y + h * 0.5)], color: Palette.tan.darker(0.3), lw: 0.04)
            p.circle(x + w * 0.5, y + h * 0.5, 0.12, fill: Palette.coral)
        case .filing:
            p.rect(x + 0.12, y + 0.08, w - 0.24, h - 0.16, r: 0.05, fill: metal, shadow: true)
            for k in 0..<3 { p.rect(x + 0.4, y + 0.22 + Double(k) * 0.22, 0.2, 0.05, r: 0.02, fill: slate) }
        case .rug:
            p.rect(x + 0.1, y + 0.1, w - 0.2, h - 0.2, r: 0.2, fill: Palette.coral.lighter(0.35))
            p.rect(x + 0.3, y + 0.3, w - 0.6, h - 0.6, r: 0.14, fill: nil, stroke: Palette.ivory, lw: 0.05)
        case .sign:
            p.rect(x + 0.16, y + 0.1, 0.68, 0.36, r: 0.06, fill: Palette.navy, shadow: true)
            p.line([(x + 0.26, y + 0.28), (x + 0.74, y + 0.28)], color: paper, lw: 0.04)
        case .lamp:
            p.circle(x + 0.5, y + 0.5, 0.42, fill: Palette.ochre.alpha(0.18))
            p.circle(x + 0.5, y + 0.5, 0.12, fill: Palette.ochre.lighter(0.3))
        case .chartRack:
            p.rect(x + 0.14, y + 0.1, 0.72, 0.8, r: 0.06, fill: slate, shadow: true)
            for k in 0..<4 { p.rect(x + 0.22, y + 0.18 + Double(k) * 0.17, 0.56, 0.12, r: 0.02, fill: [Palette.blueGray, Palette.ochre, Palette.paper, Palette.turquoise][k]) }
        case .cartBay:
            let laundry = o.id.contains("laundry")
            p.rect(x + 0.16, y + 0.14, w - 0.32, h - 0.28, r: 0.14, fill: laundry ? Palette.blueGray.lighter(0.2) : Palette.ochre, shadow: true)
            p.rect(x + 0.32, y + 0.3, w - 0.64, h - 0.6, r: 0.1, fill: laundry ? Palette.ivory : Palette.slate.lighter(0.3))
        case .ramp:
            p.rect(x + 0.06, y + 0.06, w - 0.12, h - 0.12, r: 0.06, fill: metal.lighter(0.3))
            for k in 0..<Int(h * 3) { p.line([(x + 0.12, y + 0.2 + Double(k) * 0.33), (x + w - 0.12, y + 0.2 + Double(k) * 0.33)], color: Palette.ochre, lw: 0.05) }
        case .restraintChair:
            p.rect(x + 0.18, y + 0.14, 0.64, 0.72, r: 0.12, fill: slate.darker(0.25), shadow: true)
            p.rect(x + 0.26, y + 0.24, 0.48, 0.5, r: 0.08, fill: slate)
        case .van:
            p.rect(x + 0.06, y + 0.1, w - 0.12, h - 0.2, r: 0.24, fill: paper, shadow: true)
            p.rect(x + w - 0.9, y + 0.2, 0.5, h - 0.4, r: 0.1, fill: Palette.blueGray.darker(0.1))
            p.rect(x + 0.3, y + 0.24, w - 1.4, 0.12, fill: Palette.navy)
        case .culvert:
            p.circle(x + 0.5, y + 0.5, 0.42, fill: Palette.concrete.darker(0.15), shadow: true)
            p.circle(x + 0.5, y + 0.5, 0.3, fill: ink.lighter(0.1))
            for k in 0..<4 { p.line([(x + 0.26 + Double(k) * 0.16, y + 0.24), (x + 0.26 + Double(k) * 0.16, y + 0.76)], color: metal, lw: 0.04) }
        case .kennel:
            p.rect(x + 0.1, y + 0.2, w - 0.2, h - 0.3, r: 0.1, fill: wood.darker(0.1), shadow: true)
            p.poly([(x + 0.0, y + 0.3), (x + w * 0.5, y + 0.02), (x + w, y + 0.3)], fill: Palette.coral.darker(0.15))
        case .trayCart:
            p.rect(x + 0.08, y + 0.16, w - 0.16, h - 0.32, r: 0.1, fill: metal.lighter(0.15), shadow: true)
            for k in 0..<Int(w * 2) { p.rect(x + 0.18 + Double(k) * 0.46, y + 0.28, 0.36, h - 0.56, r: 0.05, fill: Palette.ivory) }
        case .lawn:
            for k in 0..<Int(w / 2) {
                p.rect(x + Double(k) * 2, y, 1, h, fill: Palette.grass.lighter(0.08))
            }
        case .piano:
            p.rect(x + 0.06, y + 0.1, w - 0.12, h - 0.2, r: 0.06, fill: wood.darker(0.35), shadow: true)
            p.rect(x + 0.14, y + h - 0.36, w - 0.28, 0.18, fill: paper)
            for k in 0..<Int(w * 6) { p.line([(x + 0.18 + Double(k) * 0.16, y + h - 0.36), (x + 0.18 + Double(k) * 0.16, y + h - 0.26)], color: ink, lw: 0.03) }
        case .mailbox:
            p.rect(x + 0.2, y + 0.16, 0.6, 0.68, r: 0.18, fill: Palette.navy.lighter(0.15), shadow: true)
            p.rect(x + 0.32, y + 0.3, 0.36, 0.06, r: 0.02, fill: paper)
        case .waterCooler:
            p.rect(x + 0.22, y + 0.3, 0.56, 0.56, r: 0.08, fill: paper, shadow: true)
            p.circle(x + 0.5, y + 0.36, 0.22, fill: Palette.turquoise.lighter(0.35))
        case .typewriter:
            p.rect(x + 0.1, y + 0.2, w - 0.2, h - 0.4, r: 0.1, fill: Palette.grassDark.darker(0.1), shadow: true)
            p.rect(x + 0.3, y + 0.12, w - 0.6, 0.2, r: 0.04, fill: paper)
        case .easel:
            p.line([(x + 0.2, y + 0.9), (x + 0.5, y + 0.1), (x + 0.8, y + 0.9)], color: wood.darker(0.2), lw: 0.06)
            p.rect(x + 0.22, y + 0.2, 0.56, 0.44, r: 0.03, fill: paper, shadow: true)
            p.circle(x + 0.5, y + 0.42, 0.1, fill: Palette.turquoise)
        case .gate, .fenceGap:
            break
        }
    }
}
