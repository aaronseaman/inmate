import Foundation

// MARK: - Display list (what the platform renderer draws each frame)

public enum Layer: Int, Codable { case world = 0, screen = 1 }

public struct RenderItem {
    /// Stable identity for node reuse across frames.
    public var id: String
    public var art: ArtKey
    /// World layer: tile coordinates. Screen layer: points (origin top-left).
    public var pos: Vec2
    public var z: Double
    public var rotation: Double = 0
    public var scaleX: Double = 1
    public var scaleY: Double = 1
    public var alpha: Double = 1
    public var layer: Layer

    public init(id: String, art: ArtKey, pos: Vec2, z: Double, layer: Layer, rotation: Double = 0,
                scaleX: Double = 1, scaleY: Double = 1, alpha: Double = 1) {
        self.id = id; self.art = art; self.pos = pos; self.z = z; self.layer = layer
        self.rotation = rotation; self.scaleX = scaleX; self.scaleY = scaleY; self.alpha = alpha
    }
}

/// A dynamic polygon (vision cones, noise rings) drawn directly as a shape.
public struct PolyItem {
    public var id: String
    public var points: [Vec2]
    public var fill: RGBA
    public var stroke: RGBA?
    public var lineWidth: Double
    public var z: Double
    public var layer: Layer
}

public struct AXElement: Hashable {
    public var id: String
    public var rect: Rect
    public var label: String
    public var hint: String?
    public var isButton: Bool
}

public struct Frame {
    public var items: [RenderItem] = []
    public var polys: [PolyItem] = []
    public var camera: Vec2 = .zero
    public var tileSize: Double = 30
    public var viewport: Vec2 = Vec2(844, 390)
    public var fade: Double = 0
    public var fadeColor: RGBA = Palette.ink
    public var accessibility: [AXElement] = []
    public var background: RGBA = Palette.woodsDark
    public init() {}
}

// MARK: - Vector drawings (rasterized and cached by ArtKey)

public enum FontWeight: Int, Hashable, Codable { case regular, medium, semibold, bold }
public enum TextAlign: Int, Hashable, Codable { case left, center, right }

public struct TextRun: Hashable {
    public var text: String
    /// Top-left of the line box (left align) or top-center (center) or top-right (right).
    public var pos: Vec2
    public var size: Double
    public var weight: FontWeight
    public var color: RGBA
    public var align: TextAlign
    public init(_ text: String, pos: Vec2, size: Double, weight: FontWeight = .medium, color: RGBA = Palette.ink, align: TextAlign = .left) {
        self.text = text; self.pos = pos; self.size = size; self.weight = weight; self.color = color; self.align = align
    }
}

public enum PathOp: Hashable {
    case move(Vec2)
    case line(Vec2)
    case quad(Vec2, Vec2)
    case cubic(Vec2, Vec2, Vec2)
    case close
}

public enum Geom: Hashable {
    case rect(Rect, radius: Double)
    case ellipse(Rect)
    case poly([Vec2])
    case path([PathOp])
    case polyline([Vec2])
    case text(TextRun)
}

public struct Shape: Hashable {
    public var geom: Geom
    public var fill: RGBA?
    public var stroke: RGBA?
    public var lineWidth: Double
    /// Soft paper shadow beneath this shape.
    public var shadow: Bool

    public init(_ geom: Geom, fill: RGBA? = nil, stroke: RGBA? = nil, lineWidth: Double = 1, shadow: Bool = false) {
        self.geom = geom; self.fill = fill; self.stroke = stroke; self.lineWidth = lineWidth; self.shadow = shadow
    }
}

public struct Drawing {
    /// Size in points.
    public var size: Vec2
    /// Anchor in unit coordinates (0,0 top-left .. 1,1 bottom-right) placed at RenderItem.pos.
    public var anchor: Vec2
    public var shapes: [Shape]
    /// Shadow offset in points (paper layering).
    public var shadowOffset: Vec2
    public var shadowBlur: Double
    public init(size: Vec2, anchor: Vec2 = Vec2(0.5, 0.5), shapes: [Shape] = [], shadowOffset: Vec2 = Vec2(1.2, 1.8), shadowBlur: Double = 1.6) {
        self.size = size; self.anchor = anchor; self.shapes = shapes; self.shadowOffset = shadowOffset; self.shadowBlur = shadowBlur
    }
}

// MARK: - Text metrics (approximation of SF Pro Rounded advance widths)

public enum TextMetrics {
    static func advance(_ c: Character) -> Double {
        switch c {
        case " ": return 0.27
        case "i", "l", "j", "!", "|", ".", ",", ":", ";", "'", "’", "I": return 0.26
        case "f", "t", "r": return 0.36
        case "m", "w": return 0.82
        case "M", "W": return 0.9
        case "—": return 0.9
        case "0"..."9": return 0.58
        default:
            if c.isUppercase { return 0.66 }
            if c.isLetter { return 0.54 }
            return 0.56
        }
    }
    public static func width(_ s: String, size: Double, weight: FontWeight = .medium) -> Double {
        let w = s.reduce(0.0) { $0 + advance($1) } * size
        switch weight {
        case .regular: return w * 0.98
        case .medium: return w
        case .semibold: return w * 1.03
        case .bold: return w * 1.06
        }
    }
    public static func lineHeight(_ size: Double) -> Double { (size * 1.28).rounded() }

    /// Greedy word wrap.
    public static func wrap(_ s: String, size: Double, weight: FontWeight = .medium, width: Double) -> [String] {
        var lines: [String] = []
        for para in s.components(separatedBy: "\n") {
            var cur = ""
            for word in para.split(separator: " ", omittingEmptySubsequences: false) {
                let cand = cur.isEmpty ? String(word) : cur + " " + word
                if TextMetrics.width(cand, size: size, weight: weight) <= width || cur.isEmpty {
                    cur = cand
                } else {
                    lines.append(cur)
                    cur = String(word)
                }
            }
            lines.append(cur)
        }
        return lines
    }

    public static func truncate(_ s: String, size: Double, weight: FontWeight = .medium, width: Double) -> String {
        if TextMetrics.width(s, size: size, weight: weight) <= width { return s }
        var t = s
        while !t.isEmpty && TextMetrics.width(t + "…", size: size, weight: weight) > width { t.removeLast() }
        return t + "…"
    }
}
