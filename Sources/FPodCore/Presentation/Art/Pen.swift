import Foundation

/// Small drawing DSL for cut-paper art. Coordinates are in a local box scaled by `s`
/// and offset by `o`, so art can be authored in unit space.
public struct Pen {
    public var shapes: [Shape] = []
    public var s: Double
    public var o: Vec2
    public init(scale: Double, origin: Vec2 = .zero) { s = scale; o = origin }

    @inline(__always) func p(_ x: Double, _ y: Double) -> Vec2 { Vec2(o.x + x * s, o.y + y * s) }

    public mutating func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, r: Double = 0, fill: RGBA?, stroke: RGBA? = nil, lw: Double = 0.04, shadow: Bool = false) {
        shapes.append(Shape(.rect(Rect(o.x + x * s, o.y + y * s, w * s, h * s), radius: r * s), fill: fill, stroke: stroke, lineWidth: lw * s, shadow: shadow))
    }
    public mutating func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double, fill: RGBA?, stroke: RGBA? = nil, lw: Double = 0.04, shadow: Bool = false) {
        shapes.append(Shape(.ellipse(Rect(o.x + x * s, o.y + y * s, w * s, h * s)), fill: fill, stroke: stroke, lineWidth: lw * s, shadow: shadow))
    }
    public mutating func circle(_ cx: Double, _ cy: Double, _ r: Double, fill: RGBA?, stroke: RGBA? = nil, lw: Double = 0.04, shadow: Bool = false) {
        oval(cx - r, cy - r, 2 * r, 2 * r, fill: fill, stroke: stroke, lw: lw, shadow: shadow)
    }
    public mutating func poly(_ pts: [(Double, Double)], fill: RGBA?, stroke: RGBA? = nil, lw: Double = 0.04, shadow: Bool = false) {
        shapes.append(Shape(.poly(pts.map { p($0.0, $0.1) }), fill: fill, stroke: stroke, lineWidth: lw * s, shadow: shadow))
    }
    public mutating func line(_ pts: [(Double, Double)], color: RGBA, lw: Double = 0.06) {
        shapes.append(Shape(.polyline(pts.map { p($0.0, $0.1) }), fill: nil, stroke: color, lineWidth: lw * s, shadow: false))
    }
    /// Arc as polyline (angles in radians, 0 = east, clockwise positive because y is down).
    public mutating func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double, color: RGBA, lw: Double = 0.06, steps: Int = 14) {
        var pts: [(Double, Double)] = []
        for k in 0...steps {
            let a = a0 + (a1 - a0) * Double(k) / Double(steps)
            pts.append((cx + cos(a) * r, cy + sin(a) * r))
        }
        line(pts, color: color, lw: lw)
    }
    /// Filled wedge (pie slice).
    public mutating func wedge(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double, fill: RGBA, steps: Int = 14) {
        var pts: [(Double, Double)] = [(cx, cy)]
        for k in 0...steps {
            let a = a0 + (a1 - a0) * Double(k) / Double(steps)
            pts.append((cx + cos(a) * r, cy + sin(a) * r))
        }
        poly(pts, fill: fill)
    }
    public mutating func path(_ ops: [PathOp], fill: RGBA?, stroke: RGBA? = nil, lw: Double = 0.04, shadow: Bool = false) {
        let mapped = ops.map { op -> PathOp in
            switch op {
            case .move(let v): return .move(p(v.x, v.y))
            case .line(let v): return .line(p(v.x, v.y))
            case .quad(let c, let v): return .quad(p(c.x, c.y), p(v.x, v.y))
            case .cubic(let c1, let c2, let v): return .cubic(p(c1.x, c1.y), p(c2.x, c2.y), p(v.x, v.y))
            case .close: return .close
            }
        }
        shapes.append(Shape(.path(mapped), fill: fill, stroke: stroke, lineWidth: lw * s, shadow: shadow))
    }
    public mutating func text(_ t: String, _ x: Double, _ y: Double, size: Double, weight: FontWeight = .semibold, color: RGBA, align: TextAlign = .center) {
        shapes.append(Shape(.text(TextRun(t, pos: p(x, y), size: size * s, weight: weight, color: color, align: align))))
    }
    public mutating func star(_ cx: Double, _ cy: Double, _ r: Double, fill: RGBA, points: Int = 5) {
        var pts: [(Double, Double)] = []
        for k in 0..<(points * 2) {
            let a = -Double.pi / 2 + Double(k) * .pi / Double(points)
            let rr = k % 2 == 0 ? r : r * 0.45
            pts.append((cx + cos(a) * rr, cy + sin(a) * rr))
        }
        poly(pts, fill: fill)
    }
}
