import Foundation

/// Flat cut-paper pictograms in a unit box. `c` is the ink color; cut-outs use paper.
public enum IconArt {
    public static func draw(_ icon: Icon, size: Double, color c: RGBA) -> Drawing {
        var p = Pen(scale: size)
        // Cut-outs read as paper on dark ink, and as soft navy on light ink (badges).
        let w = c.luminance > 0.55 ? Palette.navy.alpha(0.55) : Palette.paper
        let a = c.alpha(c.a * 0.38)
        let coral = Palette.coral, ochre = Palette.ochre, turq = Palette.turquoise
        switch icon {
        // MARK: Interface
        case .walk:
            p.circle(0.55, 0.16, 0.1, fill: c)
            p.line([(0.52, 0.3), (0.46, 0.56), (0.32, 0.86)], color: c, lw: 0.11)
            p.line([(0.46, 0.56), (0.62, 0.86)], color: c, lw: 0.11)
            p.line([(0.3, 0.46), (0.5, 0.36), (0.68, 0.5)], color: c, lw: 0.09)
        case .run:
            p.circle(0.62, 0.15, 0.1, fill: c)
            p.line([(0.58, 0.3), (0.48, 0.54), (0.26, 0.66)], color: c, lw: 0.11)
            p.line([(0.48, 0.54), (0.66, 0.68), (0.6, 0.9)], color: c, lw: 0.11)
            p.line([(0.3, 0.38), (0.56, 0.32), (0.76, 0.46)], color: c, lw: 0.09)
            p.line([(0.08, 0.5), (0.22, 0.5)], color: a, lw: 0.07); p.line([(0.04, 0.64), (0.16, 0.64)], color: a, lw: 0.07)
        case .sneak:
            p.circle(0.36, 0.3, 0.1, fill: c)
            p.line([(0.42, 0.42), (0.6, 0.56), (0.8, 0.86)], color: c, lw: 0.11)
            p.line([(0.6, 0.56), (0.4, 0.72), (0.34, 0.9)], color: c, lw: 0.11)
            p.line([(0.44, 0.48), (0.24, 0.6)], color: c, lw: 0.09)
            p.arc(0.6, 0.34, 0.2, -2.6, -1.2, color: a, lw: 0.06)
        case .hand:
            p.rect(0.3, 0.42, 0.44, 0.44, r: 0.14, fill: c)
            for (k, x) in [0.32, 0.43, 0.54, 0.65].enumerated() { p.rect(x, 0.14 + (k == 0 || k == 3 ? 0.08 : 0), 0.09, 0.4, r: 0.045, fill: c) }
            p.rect(0.14, 0.46, 0.22, 0.1, r: 0.05, fill: c)
        case .bag:
            p.rect(0.18, 0.34, 0.64, 0.54, r: 0.12, fill: c)
            p.arc(0.5, 0.36, 0.17, .pi, 2 * .pi, color: c, lw: 0.08)
            p.rect(0.38, 0.5, 0.24, 0.08, r: 0.04, fill: w)
        case .map:
            p.poly([(0.1, 0.22), (0.36, 0.14), (0.64, 0.24), (0.9, 0.16), (0.9, 0.78), (0.64, 0.86), (0.36, 0.76), (0.1, 0.84)], fill: c)
            p.line([(0.36, 0.16), (0.36, 0.76)], color: w, lw: 0.04); p.line([(0.64, 0.24), (0.64, 0.84)], color: w, lw: 0.04)
            p.circle(0.5, 0.46, 0.07, fill: coral)
        case .journal:
            p.rect(0.2, 0.12, 0.6, 0.76, r: 0.08, fill: c)
            p.rect(0.26, 0.12, 0.06, 0.76, fill: a)
            p.line([(0.42, 0.34), (0.7, 0.34)], color: w, lw: 0.06); p.line([(0.42, 0.5), (0.7, 0.5)], color: w, lw: 0.06)
        case .gear:
            for k in 0..<8 { let ang = Double(k) * .pi / 4; p.rect(0.5 + cos(ang) * 0.3 - 0.07, 0.5 + sin(ang) * 0.3 - 0.07, 0.14, 0.14, r: 0.03, fill: c) }
            p.circle(0.5, 0.5, 0.28, fill: c); p.circle(0.5, 0.5, 0.11, fill: w)
        case .close, .cross:
            p.line([(0.24, 0.24), (0.76, 0.76)], color: c, lw: 0.13); p.line([(0.76, 0.24), (0.24, 0.76)], color: c, lw: 0.13)
        case .back, .arrowLeft:
            p.poly([(0.16, 0.5), (0.5, 0.18), (0.5, 0.38), (0.84, 0.38), (0.84, 0.62), (0.5, 0.62), (0.5, 0.82)], fill: c)
        case .arrowRight:
            p.poly([(0.84, 0.5), (0.5, 0.18), (0.5, 0.38), (0.16, 0.38), (0.16, 0.62), (0.5, 0.62), (0.5, 0.82)], fill: c)
        case .arrowUp:
            p.poly([(0.5, 0.14), (0.84, 0.48), (0.62, 0.48), (0.62, 0.86), (0.38, 0.86), (0.38, 0.48), (0.16, 0.48)], fill: c)
        case .arrowDown:
            p.poly([(0.5, 0.86), (0.84, 0.52), (0.62, 0.52), (0.62, 0.14), (0.38, 0.14), (0.38, 0.52), (0.16, 0.52)], fill: c)
        case .check:
            p.line([(0.18, 0.52), (0.42, 0.76), (0.84, 0.26)], color: c, lw: 0.14)
        case .plus:
            p.rect(0.42, 0.16, 0.16, 0.68, r: 0.06, fill: c); p.rect(0.16, 0.42, 0.68, 0.16, r: 0.06, fill: c)
        case .minus:
            p.rect(0.16, 0.42, 0.68, 0.16, r: 0.06, fill: c)
        case .clock:
            p.circle(0.5, 0.5, 0.38, fill: c); p.circle(0.5, 0.5, 0.29, fill: w)
            p.line([(0.5, 0.5), (0.5, 0.3)], color: c, lw: 0.07); p.line([(0.5, 0.5), (0.65, 0.58)], color: c, lw: 0.07)
        case .bell:
            p.path([.move(Vec2(0.24, 0.72)), .quad(Vec2(0.26, 0.2), Vec2(0.5, 0.18)), .quad(Vec2(0.74, 0.2), Vec2(0.76, 0.72)), .close], fill: c)
            p.rect(0.18, 0.7, 0.64, 0.08, r: 0.04, fill: c); p.circle(0.5, 0.84, 0.07, fill: c)
        case .eye:
            p.path([.move(Vec2(0.08, 0.5)), .quad(Vec2(0.5, 0.12), Vec2(0.92, 0.5)), .quad(Vec2(0.5, 0.88), Vec2(0.08, 0.5)), .close], fill: c)
            p.circle(0.5, 0.5, 0.17, fill: w); p.circle(0.5, 0.5, 0.08, fill: c)
        case .question:
            p.arc(0.5, 0.36, 0.18, -.pi, 0.4, color: c, lw: 0.13)
            p.line([(0.64, 0.46), (0.5, 0.56), (0.5, 0.64)], color: c, lw: 0.13)
            p.circle(0.5, 0.84, 0.08, fill: c)
        case .exclaim:
            p.rect(0.41, 0.12, 0.18, 0.52, r: 0.09, fill: c); p.circle(0.5, 0.83, 0.09, fill: c)
        case .lock:
            p.arc(0.5, 0.4, 0.17, .pi, 2 * .pi, color: c, lw: 0.1)
            p.line([(0.33, 0.4), (0.33, 0.48)], color: c, lw: 0.1); p.line([(0.67, 0.4), (0.67, 0.48)], color: c, lw: 0.1)
            p.rect(0.22, 0.46, 0.56, 0.42, r: 0.08, fill: c); p.circle(0.5, 0.64, 0.06, fill: w)
        case .key:
            p.circle(0.32, 0.4, 0.17, fill: c); p.circle(0.32, 0.4, 0.07, fill: w)
            p.rect(0.44, 0.36, 0.44, 0.09, r: 0.04, fill: c)
            p.rect(0.7, 0.44, 0.07, 0.14, fill: c); p.rect(0.8, 0.44, 0.07, 0.1, fill: c)
        case .badge:
            p.poly([(0.5, 0.1), (0.84, 0.24), (0.8, 0.6), (0.5, 0.9), (0.2, 0.6), (0.16, 0.24)], fill: c)
            p.star(0.5, 0.46, 0.17, fill: w)
        case .star:
            p.star(0.5, 0.52, 0.42, fill: c)
        case .heart:
            p.path([.move(Vec2(0.5, 0.86)), .cubic(Vec2(0.0, 0.5), Vec2(0.18, 0.06), Vec2(0.5, 0.32)), .cubic(Vec2(0.82, 0.06), Vec2(1.0, 0.5), Vec2(0.5, 0.86)), .close], fill: c)
        case .coin:
            p.circle(0.5, 0.5, 0.38, fill: c); p.circle(0.5, 0.5, 0.28, fill: a)
            p.text("c", 0.5, 0.25, size: 0.45, weight: .bold, color: w)
        case .favor:
            p.path([.move(Vec2(0.08, 0.5)), .line(Vec2(0.36, 0.34)), .line(Vec2(0.62, 0.42)), .line(Vec2(0.92, 0.36)), .line(Vec2(0.92, 0.58)), .line(Vec2(0.6, 0.76)), .line(Vec2(0.3, 0.7)), .line(Vec2(0.08, 0.66)), .close], fill: c)
            p.line([(0.4, 0.5), (0.6, 0.62)], color: w, lw: 0.05)
        case .trust:
            p.poly([(0.5, 0.1), (0.86, 0.22), (0.82, 0.56), (0.5, 0.9), (0.18, 0.56), (0.14, 0.22)], fill: c)
            p.line([(0.32, 0.5), (0.46, 0.64), (0.7, 0.36)], color: w, lw: 0.08)
        case .energy:
            p.poly([(0.58, 0.08), (0.24, 0.56), (0.48, 0.56), (0.4, 0.92), (0.78, 0.42), (0.54, 0.42)], fill: c)
        case .info:
            p.circle(0.5, 0.5, 0.4, fill: c); p.rect(0.44, 0.44, 0.12, 0.32, r: 0.04, fill: w); p.circle(0.5, 0.3, 0.07, fill: w)
        case .play:
            p.poly([(0.28, 0.16), (0.82, 0.5), (0.28, 0.84)], fill: c)
        case .pause:
            p.rect(0.26, 0.18, 0.16, 0.64, r: 0.04, fill: c); p.rect(0.58, 0.18, 0.16, 0.64, r: 0.04, fill: c)
        case .save:
            p.rect(0.16, 0.16, 0.68, 0.68, r: 0.08, fill: c); p.rect(0.3, 0.16, 0.4, 0.22, fill: w); p.rect(0.28, 0.56, 0.44, 0.28, r: 0.03, fill: w)
        case .sound:
            p.poly([(0.12, 0.38), (0.3, 0.38), (0.52, 0.18), (0.52, 0.82), (0.3, 0.62), (0.12, 0.62)], fill: c)
            p.arc(0.56, 0.5, 0.16, -0.9, 0.9, color: c, lw: 0.07); p.arc(0.56, 0.5, 0.3, -0.9, 0.9, color: c, lw: 0.07)
        case .music:
            p.oval(0.16, 0.62, 0.24, 0.18, fill: c); p.oval(0.56, 0.54, 0.24, 0.18, fill: c)
            p.rect(0.34, 0.2, 0.07, 0.52, fill: c); p.rect(0.74, 0.12, 0.07, 0.52, fill: c)
            p.poly([(0.34, 0.2), (0.81, 0.12), (0.81, 0.24), (0.34, 0.32)], fill: c)
        case .voice:
            p.path([.move(Vec2(0.12, 0.2)), .line(Vec2(0.88, 0.2)), .line(Vec2(0.88, 0.66)), .line(Vec2(0.46, 0.66)), .line(Vec2(0.26, 0.86)), .line(Vec2(0.28, 0.66)), .line(Vec2(0.12, 0.66)), .close], fill: c)
            for x in [0.32, 0.5, 0.68] { p.circle(x, 0.43, 0.05, fill: w) }
        case .captions:
            p.rect(0.1, 0.22, 0.8, 0.56, r: 0.1, fill: c)
            p.line([(0.22, 0.42), (0.5, 0.42)], color: w, lw: 0.07); p.line([(0.58, 0.42), (0.78, 0.42)], color: w, lw: 0.07)
            p.line([(0.22, 0.6), (0.4, 0.6)], color: w, lw: 0.07); p.line([(0.48, 0.6), (0.78, 0.6)], color: w, lw: 0.07)
        case .leftHand:
            p.rect(0.26, 0.42, 0.44, 0.44, r: 0.14, fill: c)
            for (k, x) in [0.27, 0.38, 0.49, 0.6].enumerated() { p.rect(x, 0.14 + (k == 0 || k == 3 ? 0.08 : 0), 0.09, 0.4, r: 0.045, fill: c) }
            p.rect(0.64, 0.46, 0.22, 0.1, r: 0.05, fill: c)
            p.text("L", 0.48, 0.5, size: 0.3, weight: .bold, color: w)
        case .cone:
            p.wedge(0.16, 0.5, 0.74, -0.55, 0.55, fill: a); p.circle(0.16, 0.5, 0.1, fill: c)
        case .motion:
            p.circle(0.3, 0.5, 0.16, fill: c)
            p.line([(0.52, 0.34), (0.86, 0.34)], color: a, lw: 0.08); p.line([(0.52, 0.5), (0.9, 0.5)], color: c, lw: 0.08); p.line([(0.52, 0.66), (0.86, 0.66)], color: a, lw: 0.08)
        case .moon:
            p.circle(0.48, 0.5, 0.34, fill: c); p.circle(0.64, 0.4, 0.28, fill: w.alpha(1))
        case .sun:
            for k in 0..<8 { let ang = Double(k) * .pi / 4; p.line([(0.5 + cos(ang) * 0.3, 0.5 + sin(ang) * 0.3), (0.5 + cos(ang) * 0.42, 0.5 + sin(ang) * 0.42)], color: c, lw: 0.07) }
            p.circle(0.5, 0.5, 0.22, fill: c)
        case .swap:
            p.poly([(0.12, 0.34), (0.36, 0.14), (0.36, 0.26), (0.84, 0.26), (0.84, 0.42), (0.36, 0.42), (0.36, 0.54)], fill: c)
            p.poly([(0.88, 0.66), (0.64, 0.46), (0.64, 0.58), (0.16, 0.58), (0.16, 0.74), (0.64, 0.74), (0.64, 0.86)], fill: a)
        case .thumbsUp:
            p.rect(0.14, 0.44, 0.16, 0.42, r: 0.04, fill: c)
            p.path([.move(Vec2(0.36, 0.44)), .line(Vec2(0.5, 0.14)), .quad(Vec2(0.62, 0.14), Vec2(0.6, 0.3)), .line(Vec2(0.56, 0.4)), .line(Vec2(0.82, 0.4)), .quad(Vec2(0.92, 0.46), Vec2(0.84, 0.56)), .line(Vec2(0.76, 0.84)), .line(Vec2(0.36, 0.84)), .close], fill: c)
        case .thumbsDown:
            p.rect(0.14, 0.14, 0.16, 0.42, r: 0.04, fill: c)
            p.path([.move(Vec2(0.36, 0.56)), .line(Vec2(0.5, 0.86)), .quad(Vec2(0.62, 0.86), Vec2(0.6, 0.7)), .line(Vec2(0.56, 0.6)), .line(Vec2(0.82, 0.6)), .quad(Vec2(0.92, 0.54), Vec2(0.84, 0.44)), .line(Vec2(0.76, 0.16)), .line(Vec2(0.36, 0.16)), .close], fill: c)
        case .zzz:
            for (x, y, sz) in [(0.2, 0.56, 0.3), (0.48, 0.34, 0.24), (0.7, 0.16, 0.18)] {
                p.line([(x, y), (x + sz, y), (x, y + sz), (x + sz, y + sz)], color: c, lw: 0.07)
            }
        case .angry:
            p.circle(0.5, 0.5, 0.38, fill: c)
            p.line([(0.3, 0.36), (0.44, 0.44)], color: w, lw: 0.07); p.line([(0.7, 0.36), (0.56, 0.44)], color: w, lw: 0.07)
            p.arc(0.5, 0.78, 0.16, -2.4, -0.7, color: w, lw: 0.07)
        case .sad:
            p.circle(0.5, 0.5, 0.38, fill: c)
            p.circle(0.37, 0.43, 0.05, fill: w); p.circle(0.63, 0.43, 0.05, fill: w)
            p.arc(0.5, 0.78, 0.16, -2.4, -0.7, color: w, lw: 0.07)
        case .happy:
            p.circle(0.5, 0.5, 0.38, fill: c)
            p.circle(0.37, 0.42, 0.05, fill: w); p.circle(0.63, 0.42, 0.05, fill: w)
            p.arc(0.5, 0.52, 0.17, 0.5, 2.6, color: w, lw: 0.07)
        case .quiet:
            p.circle(0.42, 0.5, 0.32, fill: c)
            p.rect(0.62, 0.2, 0.1, 0.5, r: 0.05, fill: c)
            p.line([(0.3, 0.6), (0.5, 0.6)], color: w, lw: 0.06)
        case .beckon:
            p.rect(0.2, 0.46, 0.4, 0.36, r: 0.12, fill: c)
            p.path([.move(Vec2(0.5, 0.48)), .quad(Vec2(0.86, 0.36), Vec2(0.7, 0.16)), .line(Vec2(0.6, 0.2)), .quad(Vec2(0.7, 0.36), Vec2(0.44, 0.48)), .close], fill: c)
        case .stop:
            p.poly([(0.32, 0.1), (0.68, 0.1), (0.9, 0.32), (0.9, 0.68), (0.68, 0.9), (0.32, 0.9), (0.1, 0.68), (0.1, 0.32)], fill: coral)
            p.rect(0.28, 0.44, 0.44, 0.12, r: 0.04, fill: w)
        case .gavel:
            p.rect(0.18, 0.2, 0.42, 0.2, r: 0.05, fill: c)
            p.line([(0.4, 0.34), (0.82, 0.76)], color: c, lw: 0.1)
            p.rect(0.12, 0.78, 0.44, 0.1, r: 0.04, fill: a)
        case .briefcase:
            p.rect(0.12, 0.32, 0.76, 0.52, r: 0.08, fill: c); p.rect(0.36, 0.2, 0.28, 0.14, r: 0.04, fill: nil, stroke: c, lw: 0.07)
            p.rect(0.12, 0.52, 0.76, 0.06, fill: a)
        case .stethoscope:
            p.arc(0.4, 0.34, 0.2, 0, .pi, color: c, lw: 0.08)
            p.line([(0.4, 0.54), (0.4, 0.66)], color: c, lw: 0.08)
            p.arc(0.56, 0.66, 0.16, .pi, 0, color: c, lw: 0.08)
            p.circle(0.74, 0.5, 0.1, fill: c)
        case .house:
            p.poly([(0.5, 0.12), (0.88, 0.46), (0.78, 0.46), (0.78, 0.86), (0.22, 0.86), (0.22, 0.46), (0.12, 0.46)], fill: c)
            p.rect(0.42, 0.6, 0.16, 0.26, fill: w)
        case .dog:
            p.oval(0.22, 0.42, 0.56, 0.32, fill: c); p.circle(0.76, 0.36, 0.14, fill: c)
            p.poly([(0.74, 0.22), (0.84, 0.1), (0.86, 0.3)], fill: c)
            for x in [0.28, 0.4, 0.6, 0.7] { p.rect(x, 0.66, 0.07, 0.2, r: 0.03, fill: c) }
            p.line([(0.22, 0.48), (0.08, 0.34)], color: c, lw: 0.06)
        case .door:
            p.rect(0.24, 0.1, 0.52, 0.8, r: 0.05, fill: c); p.circle(0.66, 0.52, 0.05, fill: w)
        case .search:
            p.circle(0.42, 0.42, 0.26, fill: nil, stroke: c, lw: 0.1); p.circle(0.42, 0.42, 0.18, fill: a)
            p.line([(0.6, 0.6), (0.86, 0.86)], color: c, lw: 0.13)
        case .hide:
            p.path([.move(Vec2(0.08, 0.5)), .quad(Vec2(0.5, 0.12), Vec2(0.92, 0.5)), .quad(Vec2(0.5, 0.88), Vec2(0.08, 0.5)), .close], fill: a)
            p.line([(0.16, 0.84), (0.84, 0.16)], color: c, lw: 0.1)
        case .stash:
            p.rect(0.14, 0.4, 0.72, 0.46, r: 0.06, fill: c); p.rect(0.1, 0.28, 0.8, 0.16, r: 0.04, fill: a)
            p.rect(0.42, 0.5, 0.16, 0.1, r: 0.03, fill: w)
        case .change, .shirt:
            p.poly([(0.32, 0.14), (0.42, 0.2), (0.58, 0.2), (0.68, 0.14), (0.9, 0.3), (0.8, 0.46), (0.72, 0.4), (0.72, 0.86), (0.28, 0.86), (0.28, 0.4), (0.2, 0.46), (0.1, 0.3)], fill: c)
            if icon == .change { p.arc(0.5, 0.56, 0.14, -0.5, 4.0, color: w, lw: 0.05) }
        case .chair:
            p.rect(0.24, 0.12, 0.52, 0.34, r: 0.08, fill: c); p.rect(0.2, 0.46, 0.6, 0.16, r: 0.05, fill: c)
            p.rect(0.24, 0.62, 0.08, 0.26, fill: c); p.rect(0.68, 0.62, 0.08, 0.26, fill: c)
        case .flag:
            p.rect(0.2, 0.1, 0.07, 0.8, fill: c); p.poly([(0.27, 0.12), (0.82, 0.26), (0.27, 0.46)], fill: coral)
        case .target:
            p.circle(0.5, 0.5, 0.38, fill: nil, stroke: c, lw: 0.08); p.circle(0.5, 0.5, 0.2, fill: nil, stroke: c, lw: 0.08); p.circle(0.5, 0.5, 0.06, fill: c)
        case .list:
            for y in [0.24, 0.5, 0.76] { p.circle(0.2, y, 0.06, fill: c); p.rect(0.34, y - 0.05, 0.52, 0.1, r: 0.05, fill: c) }
        case .person:
            p.circle(0.5, 0.28, 0.16, fill: c)
            p.path([.move(Vec2(0.18, 0.88)), .quad(Vec2(0.2, 0.5), Vec2(0.5, 0.5)), .quad(Vec2(0.8, 0.5), Vec2(0.82, 0.88)), .close], fill: c)
        case .people, .group:
            p.circle(0.3, 0.32, 0.12, fill: a); p.circle(0.7, 0.32, 0.12, fill: a)
            p.path([.move(Vec2(0.06, 0.8)), .quad(Vec2(0.08, 0.5), Vec2(0.3, 0.5)), .quad(Vec2(0.5, 0.5), Vec2(0.52, 0.8)), .close], fill: a)
            p.path([.move(Vec2(0.48, 0.8)), .quad(Vec2(0.5, 0.5), Vec2(0.7, 0.5)), .quad(Vec2(0.92, 0.5), Vec2(0.94, 0.8)), .close], fill: a)
            p.circle(0.5, 0.4, 0.14, fill: c)
            p.path([.move(Vec2(0.24, 0.9)), .quad(Vec2(0.26, 0.58), Vec2(0.5, 0.58)), .quad(Vec2(0.74, 0.58), Vec2(0.76, 0.9)), .close], fill: c)
        case .cellDoor:
            p.rect(0.18, 0.12, 0.64, 0.76, r: 0.04, fill: nil, stroke: c, lw: 0.08)
            for x in [0.34, 0.5, 0.66] { p.line([(x, 0.14), (x, 0.86)], color: c, lw: 0.06) }
            p.rect(0.18, 0.44, 0.64, 0.08, fill: c)
        case .camera:
            p.rect(0.14, 0.34, 0.5, 0.3, r: 0.06, fill: c); p.poly([(0.64, 0.4), (0.86, 0.3), (0.86, 0.68), (0.64, 0.58)], fill: c)
            p.line([(0.3, 0.64), (0.24, 0.86)], color: c, lw: 0.07); p.circle(0.28, 0.48, 0.05, fill: coral)
        case .tv:
            p.rect(0.1, 0.2, 0.8, 0.52, r: 0.06, fill: c); p.rect(0.16, 0.26, 0.68, 0.4, r: 0.03, fill: turq.lighter(0.3))
            p.line([(0.4, 0.84), (0.5, 0.72), (0.6, 0.84)], color: c, lw: 0.06)
        // MARK: Activities
        case .count:
            p.rect(0.22, 0.14, 0.56, 0.74, r: 0.06, fill: c); p.rect(0.36, 0.08, 0.28, 0.12, r: 0.04, fill: a)
            p.line([(0.32, 0.4), (0.42, 0.5), (0.6, 0.32)], color: w, lw: 0.06)
            p.line([(0.32, 0.66), (0.68, 0.66)], color: w, lw: 0.06)
        case .pills:
            p.rect(0.12, 0.32, 0.52, 0.24, r: 0.12, fill: c); p.rect(0.38, 0.32, 0.26, 0.24, r: 0.12, fill: a)
            p.circle(0.72, 0.68, 0.16, fill: c); p.line([(0.6, 0.68), (0.84, 0.68)], color: w, lw: 0.04)
        case .meal, .tray:
            p.rect(0.08, 0.26, 0.84, 0.52, r: 0.1, fill: c)
            p.circle(0.34, 0.52, 0.14, fill: w); p.rect(0.56, 0.38, 0.26, 0.12, r: 0.03, fill: w); p.rect(0.56, 0.56, 0.26, 0.1, r: 0.03, fill: w)
        case .work, .tools:
            p.line([(0.22, 0.78), (0.6, 0.4)], color: c, lw: 0.12)
            p.path([.move(Vec2(0.56, 0.2)), .quad(Vec2(0.8, 0.12), Vec2(0.84, 0.36)), .line(Vec2(0.72, 0.4)), .line(Vec2(0.62, 0.34)), .line(Vec2(0.66, 0.22)), .close], fill: c)
            if icon == .tools { p.line([(0.7, 0.8), (0.3, 0.3)], color: a, lw: 0.08) }
        case .ball:
            p.circle(0.5, 0.5, 0.38, fill: coral.mix(ochre, 0.4))
            p.line([(0.12, 0.5), (0.88, 0.5)], color: c, lw: 0.04); p.line([(0.5, 0.12), (0.5, 0.88)], color: c, lw: 0.04)
            p.arc(0.18, 0.5, 0.28, -1.0, 1.0, color: c, lw: 0.04); p.arc(0.82, 0.5, 0.28, 2.14, 4.14, color: c, lw: 0.04)
        case .visit:
            p.circle(0.28, 0.3, 0.12, fill: c); p.circle(0.72, 0.3, 0.12, fill: a)
            p.rect(0.14, 0.46, 0.28, 0.4, r: 0.12, fill: c); p.rect(0.58, 0.46, 0.28, 0.4, r: 0.12, fill: a)
            p.rect(0.38, 0.6, 0.24, 0.08, fill: c)
        case .phone:
            p.rect(0.3, 0.1, 0.4, 0.8, r: 0.08, fill: c); p.rect(0.35, 0.18, 0.3, 0.5, r: 0.03, fill: w); p.circle(0.5, 0.78, 0.05, fill: w)
        case .book, .hymnal, .workbook:
            p.rect(0.18, 0.14, 0.64, 0.72, r: 0.06, fill: c); p.rect(0.18, 0.14, 0.12, 0.72, fill: a)
            if icon == .hymnal { p.rect(0.48, 0.3, 0.06, 0.32, fill: w); p.rect(0.4, 0.38, 0.22, 0.06, fill: w) }
            if icon == .workbook { p.line([(0.4, 0.4), (0.7, 0.4)], color: w, lw: 0.05); p.line([(0.4, 0.56), (0.66, 0.56)], color: w, lw: 0.05) }
        case .candle:
            p.rect(0.38, 0.38, 0.24, 0.5, r: 0.04, fill: c)
            p.path([.move(Vec2(0.5, 0.08)), .quad(Vec2(0.66, 0.24), Vec2(0.5, 0.34)), .quad(Vec2(0.34, 0.24), Vec2(0.5, 0.08)), .close], fill: ochre)
        case .shower:
            p.line([(0.2, 0.9), (0.2, 0.2), (0.5, 0.2)], color: c, lw: 0.07)
            p.poly([(0.38, 0.28), (0.66, 0.28), (0.58, 0.2), (0.46, 0.2)], fill: c)
            for (x, y) in [(0.44, 0.44), (0.56, 0.5), (0.48, 0.62), (0.6, 0.7), (0.52, 0.8)] { p.circle(x, y, 0.03, fill: turq) }
        case .laundry:
            p.rect(0.16, 0.12, 0.68, 0.76, r: 0.08, fill: c); p.circle(0.5, 0.56, 0.22, fill: w); p.circle(0.5, 0.56, 0.14, fill: turq.lighter(0.3))
            p.circle(0.3, 0.24, 0.04, fill: w)
        case .mop:
            p.line([(0.7, 0.1), (0.44, 0.66)], color: c, lw: 0.07)
            p.poly([(0.24, 0.62), (0.62, 0.68), (0.58, 0.9), (0.18, 0.86)], fill: c)
            p.line([(0.26, 0.86), (0.28, 0.66)], color: w, lw: 0.03); p.line([(0.4, 0.88), (0.42, 0.66)], color: w, lw: 0.03)
        case .bed:
            p.rect(0.08, 0.42, 0.84, 0.3, r: 0.06, fill: c); p.rect(0.12, 0.3, 0.26, 0.14, r: 0.06, fill: a)
            p.rect(0.08, 0.7, 0.08, 0.16, fill: c); p.rect(0.84, 0.7, 0.08, 0.16, fill: c)
        // MARK: Items
        case .snack:
            p.poly([(0.16, 0.3), (0.84, 0.3), (0.78, 0.76), (0.22, 0.76)], fill: c)
            p.line([(0.16, 0.3), (0.12, 0.2), (0.88, 0.2), (0.84, 0.3)], color: c, lw: 0.05)
            p.circle(0.5, 0.52, 0.12, fill: ochre)
        case .jar:
            p.rect(0.26, 0.28, 0.48, 0.6, r: 0.12, fill: c); p.rect(0.3, 0.14, 0.4, 0.16, r: 0.04, fill: a)
            p.rect(0.32, 0.46, 0.36, 0.2, r: 0.04, fill: w)
        case .cup:
            p.poly([(0.2, 0.28), (0.72, 0.28), (0.66, 0.86), (0.26, 0.86)], fill: c)
            p.arc(0.74, 0.5, 0.12, -1.6, 1.6, color: c, lw: 0.07)
            p.line([(0.36, 0.18), (0.4, 0.06)], color: a, lw: 0.05); p.line([(0.54, 0.18), (0.58, 0.06)], color: a, lw: 0.05)
        case .cigarette:
            p.rect(0.08, 0.44, 0.7, 0.14, r: 0.03, fill: w, stroke: c, lw: 0.04); p.rect(0.08, 0.44, 0.2, 0.14, fill: ochre)
            p.rect(0.78, 0.44, 0.08, 0.14, fill: coral)
        case .token:
            p.circle(0.5, 0.5, 0.34, fill: c); p.circle(0.5, 0.5, 0.2, fill: nil, stroke: w, lw: 0.05)
        case .bottle:
            p.rect(0.3, 0.34, 0.4, 0.54, r: 0.1, fill: c); p.rect(0.42, 0.12, 0.16, 0.24, r: 0.03, fill: c)
            p.rect(0.36, 0.52, 0.28, 0.14, fill: w)
        case .charger:
            p.rect(0.28, 0.12, 0.44, 0.36, r: 0.06, fill: c); p.rect(0.36, 0.48, 0.06, 0.12, fill: c); p.rect(0.58, 0.48, 0.06, 0.12, fill: c)
            p.line([(0.5, 0.12), (0.5, 0.02)], color: c, lw: 0.04)
            p.arc(0.5, 0.74, 0.18, -.pi, 0, color: c, lw: 0.05)
        case .radio:
            p.rect(0.1, 0.32, 0.8, 0.52, r: 0.08, fill: c); p.circle(0.34, 0.58, 0.14, fill: w); p.circle(0.34, 0.58, 0.07, fill: c)
            p.rect(0.56, 0.44, 0.24, 0.08, r: 0.03, fill: w); p.line([(0.7, 0.32), (0.86, 0.08)], color: c, lw: 0.04)
        case .headphones:
            p.arc(0.5, 0.52, 0.32, .pi, 2 * .pi, color: c, lw: 0.08)
            p.rect(0.12, 0.48, 0.16, 0.3, r: 0.06, fill: c); p.rect(0.72, 0.48, 0.16, 0.3, r: 0.06, fill: c)
        case .letter, .envelope:
            p.rect(0.1, 0.24, 0.8, 0.54, r: 0.05, fill: c)
            p.line([(0.12, 0.28), (0.5, 0.56), (0.88, 0.28)], color: w, lw: 0.05)
        case .note:
            p.poly([(0.2, 0.16), (0.7, 0.16), (0.82, 0.3), (0.82, 0.86), (0.2, 0.86)], fill: c)
            p.line([(0.32, 0.42), (0.7, 0.42)], color: w, lw: 0.05); p.line([(0.32, 0.58), (0.62, 0.58)], color: w, lw: 0.05)
        case .wire:
            p.arc(0.4, 0.5, 0.26, 0.4, 5.6, color: ochre.darker(0.1), lw: 0.07); p.arc(0.4, 0.5, 0.16, 0.4, 5.6, color: ochre.darker(0.1), lw: 0.07)
            p.line([(0.64, 0.4), (0.9, 0.2)], color: ochre.darker(0.1), lw: 0.07)
        case .shard:
            p.poly([(0.5, 0.08), (0.66, 0.5), (0.56, 0.9), (0.4, 0.88), (0.36, 0.44)], fill: coral)
        case .needle:
            p.rect(0.22, 0.3, 0.42, 0.22, r: 0.06, fill: c); p.line([(0.64, 0.41), (0.9, 0.41)], color: c, lw: 0.04)
            p.circle(0.34, 0.66, 0.08, fill: a)
        case .dice:
            p.rect(0.16, 0.16, 0.68, 0.68, r: 0.12, fill: c)
            for (x, y) in [(0.34, 0.34), (0.66, 0.66), (0.5, 0.5), (0.66, 0.34), (0.34, 0.66)] { p.circle(x, y, 0.06, fill: w) }
        case .chess:
            p.circle(0.5, 0.22, 0.1, fill: c)
            p.poly([(0.38, 0.34), (0.62, 0.34), (0.58, 0.66), (0.42, 0.66)], fill: c)
            p.rect(0.28, 0.66, 0.44, 0.1, r: 0.03, fill: c); p.rect(0.22, 0.76, 0.56, 0.1, r: 0.03, fill: c)
        case .cards, .card:
            if icon == .cards { p.rect(0.14, 0.2, 0.46, 0.62, r: 0.06, fill: a) }
            p.rect(icon == .cards ? 0.36 : 0.2, 0.16, 0.5, 0.66, r: 0.06, fill: c)
            p.circle(icon == .cards ? 0.61 : 0.45, 0.48, 0.1, fill: w)
        case .pencil:
            p.poly([(0.16, 0.84), (0.22, 0.66), (0.7, 0.18), (0.82, 0.3), (0.34, 0.78)], fill: ochre)
            p.poly([(0.16, 0.84), (0.22, 0.66), (0.34, 0.78)], fill: c)
            p.poly([(0.7, 0.18), (0.82, 0.3), (0.86, 0.26), (0.74, 0.14)], fill: coral)
        case .drawing:
            p.rect(0.14, 0.16, 0.72, 0.68, r: 0.04, fill: c)
            p.rect(0.2, 0.22, 0.6, 0.56, fill: w)
            p.poly([(0.2, 0.78), (0.4, 0.5), (0.52, 0.62), (0.62, 0.48), (0.8, 0.78)], fill: turq)
            p.circle(0.66, 0.34, 0.06, fill: ochre)
        case .glasses:
            p.circle(0.3, 0.52, 0.16, fill: nil, stroke: c, lw: 0.07); p.circle(0.7, 0.52, 0.16, fill: nil, stroke: c, lw: 0.07)
            p.line([(0.46, 0.5), (0.54, 0.5)], color: c, lw: 0.06)
        case .photo:
            p.rect(0.12, 0.2, 0.76, 0.6, r: 0.04, fill: c); p.rect(0.18, 0.26, 0.64, 0.42, fill: w)
            p.circle(0.5, 0.44, 0.08, fill: a); p.rect(0.4, 0.52, 0.2, 0.14, r: 0.05, fill: a)
        case .clipboard:
            p.rect(0.2, 0.14, 0.6, 0.76, r: 0.06, fill: c); p.rect(0.36, 0.08, 0.28, 0.12, r: 0.04, fill: a)
            p.rect(0.28, 0.26, 0.44, 0.56, r: 0.02, fill: w)
            p.line([(0.34, 0.4), (0.66, 0.4)], color: c, lw: 0.04); p.line([(0.34, 0.54), (0.6, 0.54)], color: c, lw: 0.04)
        case .sack:
            p.path([.move(Vec2(0.3, 0.3)), .quad(Vec2(0.1, 0.86), Vec2(0.5, 0.88)), .quad(Vec2(0.9, 0.86), Vec2(0.7, 0.3)), .close], fill: c)
            p.rect(0.32, 0.18, 0.36, 0.14, r: 0.05, fill: a)
        case .box:
            p.rect(0.14, 0.34, 0.72, 0.52, r: 0.04, fill: c)
            p.poly([(0.14, 0.34), (0.3, 0.18), (0.7, 0.18), (0.86, 0.34)], fill: a)
            p.rect(0.44, 0.34, 0.12, 0.2, fill: w.alpha(0.5))
        case .mapScrap:
            p.poly([(0.16, 0.2), (0.62, 0.12), (0.84, 0.3), (0.76, 0.84), (0.3, 0.88), (0.12, 0.6)], fill: c)
            p.line([(0.28, 0.6), (0.44, 0.44), (0.62, 0.52)], color: w, lw: 0.04)
            p.line([(0.56, 0.34), (0.66, 0.44)], color: coral, lw: 0.05); p.line([(0.66, 0.34), (0.56, 0.44)], color: coral, lw: 0.05)
        case .form:
            p.rect(0.2, 0.12, 0.6, 0.76, r: 0.04, fill: c)
            for y in [0.3, 0.44, 0.58] { p.line([(0.3, y), (0.7, y)], color: w, lw: 0.05) }
            p.rect(0.3, 0.68, 0.18, 0.1, fill: w)
        case .stamp:
            p.rect(0.36, 0.14, 0.28, 0.34, r: 0.1, fill: c); p.rect(0.2, 0.48, 0.6, 0.16, r: 0.04, fill: c)
            p.rect(0.16, 0.72, 0.68, 0.1, r: 0.03, fill: coral)
        case .tomato:
            p.circle(0.5, 0.56, 0.32, fill: coral)
            p.poly([(0.5, 0.26), (0.36, 0.2), (0.44, 0.3), (0.32, 0.36), (0.5, 0.32), (0.68, 0.36), (0.56, 0.3), (0.64, 0.2)], fill: Palette.grassDark)
        case .sugar:
            p.rect(0.24, 0.2, 0.52, 0.64, r: 0.06, fill: c); p.rect(0.3, 0.38, 0.4, 0.26, fill: w); p.text("S", 0.5, 0.36, size: 0.24, weight: .bold, color: c)
        case .soap:
            p.rect(0.14, 0.36, 0.72, 0.4, r: 0.14, fill: c)
            p.circle(0.3, 0.24, 0.07, fill: a); p.circle(0.44, 0.16, 0.05, fill: a); p.circle(0.6, 0.24, 0.06, fill: a)
        case .battery:
            p.rect(0.16, 0.3, 0.62, 0.4, r: 0.06, fill: c); p.rect(0.78, 0.42, 0.08, 0.16, fill: c)
            p.rect(0.22, 0.36, 0.3, 0.28, fill: Palette.statusGreen)
        case .earplug:
            p.rect(0.2, 0.36, 0.32, 0.3, r: 0.14, fill: ochre); p.rect(0.48, 0.36, 0.32, 0.3, r: 0.14, fill: ochre.lighter(0.2))
        case .coat:
            p.poly([(0.32, 0.12), (0.5, 0.26), (0.68, 0.12), (0.88, 0.3), (0.8, 0.88), (0.2, 0.88), (0.12, 0.3)], fill: c)
            p.line([(0.5, 0.26), (0.5, 0.88)], color: a, lw: 0.04); p.rect(0.58, 0.5, 0.14, 0.12, fill: a)
        case .gown:
            p.poly([(0.34, 0.12), (0.66, 0.12), (0.86, 0.88), (0.14, 0.88)], fill: c)
            p.rect(0.3, 0.18, 0.4, 0.14, r: 0.07, fill: w)
        case .cap:
            p.path([.move(Vec2(0.16, 0.6)), .quad(Vec2(0.18, 0.24), Vec2(0.5, 0.24)), .quad(Vec2(0.82, 0.24), Vec2(0.84, 0.6)), .close], fill: c)
            p.rect(0.1, 0.56, 0.86, 0.12, r: 0.06, fill: c)
        case .cutter:
            p.line([(0.2, 0.86), (0.5, 0.5), (0.7, 0.14)], color: c, lw: 0.09); p.line([(0.8, 0.86), (0.5, 0.5), (0.3, 0.14)], color: c, lw: 0.09)
            p.circle(0.5, 0.5, 0.07, fill: coral)
        // MARK: Leisure & minigames
        case .domino:
            p.rect(0.3, 0.1, 0.4, 0.8, r: 0.08, fill: c); p.line([(0.34, 0.5), (0.66, 0.5)], color: w, lw: 0.04)
            for (x, y) in [(0.42, 0.24), (0.58, 0.36), (0.5, 0.66), (0.42, 0.76), (0.58, 0.76)] { p.circle(x, y, 0.045, fill: w) }
        case .horseshoe:
            p.arc(0.5, 0.42, 0.28, 2.6, 6.8, color: c, lw: 0.13)
        case .dumbbell:
            p.rect(0.26, 0.45, 0.48, 0.1, fill: c)
            p.rect(0.1, 0.28, 0.12, 0.44, r: 0.04, fill: c); p.rect(0.78, 0.28, 0.12, 0.44, r: 0.04, fill: c)
            p.rect(0.2, 0.34, 0.08, 0.32, r: 0.03, fill: c); p.rect(0.72, 0.34, 0.08, 0.32, r: 0.03, fill: c)
        case .palette:
            p.path([.move(Vec2(0.5, 0.12)), .quad(Vec2(0.92, 0.14), Vec2(0.88, 0.52)), .quad(Vec2(0.84, 0.72), Vec2(0.62, 0.66)), .quad(Vec2(0.5, 0.64), Vec2(0.52, 0.8)), .quad(Vec2(0.5, 0.92), Vec2(0.34, 0.86)), .quad(Vec2(0.06, 0.74), Vec2(0.12, 0.44)), .quad(Vec2(0.2, 0.14), Vec2(0.5, 0.12)), .close], fill: c)
            p.circle(0.34, 0.36, 0.07, fill: coral); p.circle(0.54, 0.28, 0.07, fill: ochre); p.circle(0.72, 0.4, 0.07, fill: turq); p.circle(0.28, 0.6, 0.06, fill: w)
        case .seed:
            p.path([.move(Vec2(0.5, 0.86)), .line(Vec2(0.5, 0.46))], fill: nil, stroke: Palette.grassDark, lw: 0.07)
            p.path([.move(Vec2(0.5, 0.5)), .quad(Vec2(0.2, 0.46), Vec2(0.2, 0.2)), .quad(Vec2(0.46, 0.22), Vec2(0.5, 0.5)), .close], fill: Palette.grassDark)
            p.path([.move(Vec2(0.5, 0.56)), .quad(Vec2(0.82, 0.54), Vec2(0.82, 0.3)), .quad(Vec2(0.54, 0.3), Vec2(0.5, 0.56)), .close], fill: Palette.statusGreen)
            p.oval(0.3, 0.8, 0.4, 0.1, fill: c)
        case .water:
            p.path([.move(Vec2(0.5, 0.1)), .quad(Vec2(0.86, 0.56), Vec2(0.5, 0.88)), .quad(Vec2(0.14, 0.56), Vec2(0.5, 0.1)), .close], fill: turq)
            p.arc(0.5, 0.6, 0.16, 0.3, 1.4, color: w, lw: 0.05)
        case .weed:
            for x in [0.3, 0.5, 0.7] { p.poly([(x - 0.08, 0.86), (x, 0.2 + (x == 0.5 ? 0 : 0.14)), (x + 0.08, 0.86)], fill: Palette.grassDark) }
        case .stake:
            p.rect(0.44, 0.12, 0.12, 0.76, fill: Palette.wood); p.line([(0.3, 0.4), (0.7, 0.4)], color: c, lw: 0.04)
        case .sheet:
            p.rect(0.12, 0.2, 0.76, 0.6, r: 0.04, fill: c); p.line([(0.12, 0.5), (0.88, 0.5)], color: w, lw: 0.04)
        case .plate:
            p.circle(0.5, 0.5, 0.38, fill: c); p.circle(0.5, 0.5, 0.26, fill: w)
        case .pan:
            p.circle(0.4, 0.52, 0.28, fill: c); p.rect(0.62, 0.46, 0.32, 0.1, r: 0.05, fill: c); p.circle(0.4, 0.52, 0.18, fill: a)
        case .cart:
            p.rect(0.12, 0.26, 0.7, 0.42, r: 0.06, fill: c); p.line([(0.82, 0.3), (0.92, 0.18)], color: c, lw: 0.06)
            p.circle(0.26, 0.78, 0.09, fill: c); p.circle(0.68, 0.78, 0.09, fill: c)
        case .wheelchair:
            p.circle(0.44, 0.64, 0.24, fill: nil, stroke: c, lw: 0.07); p.circle(0.44, 0.64, 0.04, fill: c)
            p.line([(0.3, 0.16), (0.36, 0.44), (0.66, 0.44), (0.78, 0.7)], color: c, lw: 0.07)
            p.circle(0.84, 0.82, 0.06, fill: c)
        case .buffer:
            p.oval(0.12, 0.56, 0.76, 0.3, fill: c); p.line([(0.5, 0.58), (0.62, 0.14)], color: c, lw: 0.07)
            p.rect(0.5, 0.1, 0.3, 0.08, r: 0.04, fill: c)
        case .gurney:
            p.rect(0.08, 0.36, 0.84, 0.18, r: 0.06, fill: c); p.line([(0.2, 0.54), (0.2, 0.76)], color: c, lw: 0.05); p.line([(0.8, 0.54), (0.8, 0.76)], color: c, lw: 0.05)
            p.circle(0.2, 0.82, 0.06, fill: c); p.circle(0.8, 0.82, 0.06, fill: c)
        case .van:
            p.rect(0.06, 0.3, 0.88, 0.4, r: 0.08, fill: c); p.rect(0.66, 0.36, 0.2, 0.16, r: 0.03, fill: w)
            p.circle(0.26, 0.74, 0.1, fill: Palette.ink); p.circle(0.74, 0.74, 0.1, fill: Palette.ink)
        }
        return Drawing(size: Vec2(size, size), anchor: Vec2(0, 0), shapes: p.shapes)
    }
}
