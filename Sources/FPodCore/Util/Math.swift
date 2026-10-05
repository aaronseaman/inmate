import Foundation

/// 2D vector in world tile units (x right, y down) or screen points (x right, y down).
public struct Vec2: Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    public init(x: Double, y: Double) { self.x = x; self.y = y }

    public static let zero = Vec2(0, 0)

    @inline(__always) public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    @inline(__always) public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    @inline(__always) public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    @inline(__always) public static func * (s: Double, a: Vec2) -> Vec2 { Vec2(a.x * s, a.y * s) }
    @inline(__always) public static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }
    @inline(__always) public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }

    public var length: Double { (x * x + y * y).squareRoot() }
    public var lengthSquared: Double { x * x + y * y }
    public var normalized: Vec2 {
        let l = length
        return l > 1e-9 ? Vec2(x / l, y / l) : .zero
    }
    public func dot(_ o: Vec2) -> Double { x * o.x + y * o.y }
    public func distance(to o: Vec2) -> Double { (self - o).length }
    /// Angle in radians, 0 = +x (east), pi/2 = +y (south, screen down).
    public var angle: Double { atan2(y, x) }
    public static func fromAngle(_ a: Double, _ len: Double = 1) -> Vec2 { Vec2(cos(a) * len, sin(a) * len) }
    public func rotated(_ a: Double) -> Vec2 {
        let c = cos(a), s = sin(a)
        return Vec2(x * c - y * s, x * s + y * c)
    }
    public func lerp(to o: Vec2, _ t: Double) -> Vec2 { Vec2(x + (o.x - x) * t, y + (o.y - y) * t) }
    public var tile: TilePos { TilePos(Int(floor(x)), Int(floor(y))) }
}

/// Integer tile coordinate.
public struct TilePos: Hashable, Codable, Comparable {
    public var x: Int
    public var y: Int
    public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    public var center: Vec2 { Vec2(Double(x) + 0.5, Double(y) + 0.5) }
    public static func + (a: TilePos, b: TilePos) -> TilePos { TilePos(a.x + b.x, a.y + b.y) }
    public static func - (a: TilePos, b: TilePos) -> TilePos { TilePos(a.x - b.x, a.y - b.y) }
    public static func < (a: TilePos, b: TilePos) -> Bool { a.y != b.y ? a.y < b.y : a.x < b.x }
    public static let dirs4 = [TilePos(1, 0), TilePos(-1, 0), TilePos(0, 1), TilePos(0, -1)]
    public static let dirs8 = [TilePos(1, 0), TilePos(-1, 0), TilePos(0, 1), TilePos(0, -1),
                               TilePos(1, 1), TilePos(1, -1), TilePos(-1, 1), TilePos(-1, -1)]
    public func manhattan(_ o: TilePos) -> Int { abs(x - o.x) + abs(y - o.y) }
    public func chebyshev(_ o: TilePos) -> Int { max(abs(x - o.x), abs(y - o.y)) }
}

/// Axis-aligned rectangle (origin top-left, y down).
public struct Rect: Hashable, Codable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
    public init(x: Double, y: Double, w: Double, h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
    public init(center: Vec2, size: Vec2) { self.init(center.x - size.x / 2, center.y - size.y / 2, size.x, size.y) }
    public static let zero = Rect(0, 0, 0, 0)
    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + w }
    public var maxY: Double { y + h }
    public var midX: Double { x + w / 2 }
    public var midY: Double { y + h / 2 }
    public var center: Vec2 { Vec2(midX, midY) }
    public var size: Vec2 { Vec2(w, h) }
    public var origin: Vec2 { Vec2(x, y) }
    public func contains(_ p: Vec2) -> Bool { p.x >= x && p.x < x + w && p.y >= y && p.y < y + h }
    public func insetBy(_ d: Double) -> Rect { Rect(x + d, y + d, max(0, w - 2 * d), max(0, h - 2 * d)) }
    public func insetBy(dx: Double, dy: Double) -> Rect { Rect(x + dx, y + dy, max(0, w - 2 * dx), max(0, h - 2 * dy)) }
    public func offsetBy(_ v: Vec2) -> Rect { Rect(x + v.x, y + v.y, w, h) }
    public func intersects(_ o: Rect) -> Bool { x < o.maxX && o.x < maxX && y < o.maxY && o.y < maxY }
    public func union(_ o: Rect) -> Rect {
        let nx = min(x, o.x), ny = min(y, o.y)
        return Rect(nx, ny, max(maxX, o.maxX) - nx, max(maxY, o.maxY) - ny)
    }
    /// Distance from a point to the rectangle (0 inside).
    public func distance(to p: Vec2) -> Double {
        let dx = max(x - p.x, 0, p.x - maxX)
        let dy = max(y - p.y, 0, p.y - maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Integer tile rectangle, inclusive of x..<x+w, y..<y+h.
public struct TileRect: Hashable, Codable {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int
    public init(_ x: Int, _ y: Int, _ w: Int, _ h: Int) { self.x = x; self.y = y; self.w = w; self.h = h }
    public var maxX: Int { x + w - 1 }
    public var maxY: Int { y + h - 1 }
    public func contains(_ p: TilePos) -> Bool { p.x >= x && p.x < x + w && p.y >= y && p.y < y + h }
    public var rect: Rect { Rect(Double(x), Double(y), Double(w), Double(h)) }
    public var center: Vec2 { Vec2(Double(x) + Double(w) / 2, Double(y) + Double(h) / 2) }
    public func forEach(_ body: (TilePos) -> Void) {
        for yy in y..<(y + h) { for xx in x..<(x + w) { body(TilePos(xx, yy)) } }
    }
    public func expanded(_ d: Int) -> TileRect { TileRect(x - d, y - d, w + 2 * d, h + 2 * d) }
}

@inline(__always) public func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }
@inline(__always) public func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
public func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
    let t = clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
}
/// Normalizes an angle difference to -pi...pi.
public func angleDiff(_ a: Double, _ b: Double) -> Double {
    var d = (a - b).truncatingRemainder(dividingBy: 2 * .pi)
    if d > .pi { d -= 2 * .pi }
    if d < -.pi { d += 2 * .pi }
    return d
}
/// Moves angle `a` toward `target` by at most `maxStep` radians.
public func approachAngle(_ a: Double, _ target: Double, _ maxStep: Double) -> Double {
    let d = angleDiff(target, a)
    if abs(d) <= maxStep { return target }
    return a + (d > 0 ? maxStep : -maxStep)
}
public func approach(_ v: Double, _ target: Double, _ step: Double) -> Double {
    if v < target { return min(v + step, target) }
    return max(v - step, target)
}

/// Facing used by upright paper-doll figures.
public enum Facing: Int, Codable, CaseIterable {
    case down, up, left, right
    public init(angle: Double) {
        let a = angle
        let c = cos(a), s = sin(a)
        if abs(c) > abs(s) * 1.05 { self = c > 0 ? .right : .left } else { self = s > 0 ? .down : .up }
    }
    public var angle: Double {
        switch self {
        case .right: return 0
        case .down: return .pi / 2
        case .left: return .pi
        case .up: return -.pi / 2
        }
    }
    public var vector: Vec2 { Vec2.fromAngle(angle) }
}
