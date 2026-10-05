import Foundation

/// Cut-paper chess silhouettes, authored in a unit box.
enum ChessArt {
    static func piece(_ code: Int, size: Double) -> Drawing {
        let white = code > 0
        let fill = white ? Palette.paper : Palette.ink
        let edge = white ? Palette.ink : Palette.ink.darker(0.3)
        let lw = 0.05
        var p = Pen(scale: size)
        // Shared base.
        p.rect(0.2, 0.8, 0.6, 0.11, r: 0.04, fill: fill, stroke: edge, lw: lw, shadow: true)
        switch abs(code) {
        case 1:
            p.poly([(0.37, 0.5), (0.63, 0.5), (0.7, 0.81), (0.3, 0.81)], fill: fill, stroke: edge, lw: lw, shadow: true)
            p.rect(0.33, 0.44, 0.34, 0.08, r: 0.03, fill: fill, stroke: edge, lw: lw)
            p.circle(0.5, 0.31, 0.14, fill: fill, stroke: edge, lw: lw)
        case 2:
            p.poly([(0.3, 0.81), (0.35, 0.58), (0.25, 0.53), (0.2, 0.45), (0.36, 0.28), (0.42, 0.13), (0.5, 0.2), (0.64, 0.23),
                    (0.76, 0.4), (0.74, 0.81)], fill: fill, stroke: edge, lw: lw, shadow: true)
            p.circle(0.45, 0.33, 0.035, fill: white ? Palette.ink : Palette.paper)
        case 3:
            p.poly([(0.38, 0.6), (0.62, 0.6), (0.68, 0.81), (0.32, 0.81)], fill: fill, stroke: edge, lw: lw, shadow: true)
            p.path([.move(Vec2(0.5, 0.12)), .quad(Vec2(0.74, 0.34), Vec2(0.62, 0.6)), .line(Vec2(0.38, 0.6)), .quad(Vec2(0.26, 0.34), Vec2(0.5, 0.12)), .close],
                   fill: fill, stroke: edge, lw: lw)
            p.line([(0.56, 0.28), (0.47, 0.42)], color: white ? Palette.ink : Palette.paper, lw: 0.05)
            p.circle(0.5, 0.1, 0.05, fill: fill, stroke: edge, lw: lw)
        case 4:
            p.rect(0.31, 0.36, 0.38, 0.45, fill: fill, stroke: edge, lw: lw, shadow: true)
            p.poly([(0.24, 0.16), (0.34, 0.16), (0.34, 0.23), (0.45, 0.23), (0.45, 0.16), (0.55, 0.16), (0.55, 0.23), (0.66, 0.23),
                    (0.66, 0.16), (0.76, 0.16), (0.76, 0.38), (0.24, 0.38)], fill: fill, stroke: edge, lw: lw)
        case 5:
            p.poly([(0.34, 0.45), (0.66, 0.45), (0.72, 0.81), (0.28, 0.81)], fill: fill, stroke: edge, lw: lw, shadow: true)
            p.poly([(0.22, 0.2), (0.36, 0.34), (0.42, 0.14), (0.5, 0.32), (0.58, 0.14), (0.64, 0.34), (0.78, 0.2), (0.7, 0.48), (0.3, 0.48)],
                   fill: fill, stroke: edge, lw: lw)
            for (x, y) in [(0.22, 0.2), (0.42, 0.14), (0.58, 0.14), (0.78, 0.2)] { p.circle(x, y, 0.045, fill: fill, stroke: edge, lw: 0.035) }
        default:
            p.poly([(0.32, 0.4), (0.68, 0.4), (0.72, 0.81), (0.28, 0.81)], fill: fill, stroke: edge, lw: lw, shadow: true)
            p.rect(0.28, 0.34, 0.44, 0.1, r: 0.04, fill: fill, stroke: edge, lw: lw)
            p.rect(0.46, 0.06, 0.08, 0.3, r: 0.02, fill: fill, stroke: edge, lw: lw)
            p.rect(0.37, 0.13, 0.26, 0.08, r: 0.02, fill: fill, stroke: edge, lw: lw)
        }
        return Drawing(size: Vec2(size, size), anchor: Vec2(0, 0), shapes: p.shapes)
    }

    /// Card suits: 0 spades, 1 hearts, 2 diamonds, 3 clubs.
    static func suit(_ s: Int, size: Double) -> Drawing {
        var p = Pen(scale: size)
        let red = Palette.coral.darker(0.1), black = Palette.ink
        switch s {
        case 1:
            p.circle(0.31, 0.36, 0.21, fill: red); p.circle(0.69, 0.36, 0.21, fill: red)
            p.poly([(0.11, 0.44), (0.89, 0.44), (0.5, 0.9)], fill: red)
        case 2:
            p.poly([(0.5, 0.06), (0.86, 0.5), (0.5, 0.94), (0.14, 0.5)], fill: red)
        case 3:
            p.circle(0.5, 0.3, 0.19, fill: black); p.circle(0.29, 0.58, 0.19, fill: black); p.circle(0.71, 0.58, 0.19, fill: black)
            p.poly([(0.45, 0.55), (0.55, 0.55), (0.66, 0.94), (0.34, 0.94)], fill: black)
        default:
            p.poly([(0.5, 0.06), (0.9, 0.56), (0.1, 0.56)], fill: black)
            p.circle(0.3, 0.6, 0.2, fill: black); p.circle(0.7, 0.6, 0.2, fill: black)
            p.poly([(0.45, 0.6), (0.55, 0.6), (0.66, 0.94), (0.34, 0.94)], fill: black)
        }
        return Drawing(size: Vec2(size, size), anchor: Vec2(0, 0), shapes: p.shapes)
    }
}
