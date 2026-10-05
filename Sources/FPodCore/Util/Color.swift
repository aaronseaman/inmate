import Foundation

/// RGBA color, components 0...1. Quantized hashing keeps texture caches stable.
public struct RGBA: Hashable, Codable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Creates from 0xRRGGBB.
    public init(hex: UInt32, alpha: Double = 1) {
        r = Double((hex >> 16) & 0xff) / 255
        g = Double((hex >> 8) & 0xff) / 255
        b = Double(hex & 0xff) / 255
        a = alpha
    }

    public func alpha(_ v: Double) -> RGBA { RGBA(r, g, b, v) }
    public func mix(_ o: RGBA, _ t: Double) -> RGBA {
        RGBA(lerp(r, o.r, t), lerp(g, o.g, t), lerp(b, o.b, t), lerp(a, o.a, t))
    }
    public func darker(_ t: Double) -> RGBA { mix(RGBA(0.13, 0.16, 0.2, a), t) }
    public func lighter(_ t: Double) -> RGBA { mix(RGBA(1, 1, 1, a), t) }

    public var hexString: String {
        let ri = Int((clamp(r, 0, 1) * 255).rounded()), gi = Int((clamp(g, 0, 1) * 255).rounded()), bi = Int((clamp(b, 0, 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    /// Relative luminance (sRGB) for contrast checks.
    public var luminance: Double {
        func ch(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
    }
    public static func contrast(_ a: RGBA, _ b: RGBA) -> Double {
        let l1 = max(a.luminance, b.luminance), l2 = min(a.luminance, b.luminance)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    public static func == (l: RGBA, r: RGBA) -> Bool {
        l.q(l.r) == r.q(r.r) && l.q(l.g) == r.q(r.g) && l.q(l.b) == r.q(r.b) && l.q(l.a) == r.q(r.a)
    }
    public func hash(into h: inout Hasher) {
        h.combine(q(r)); h.combine(q(g)); h.combine(q(b)); h.combine(q(a))
    }
    @inline(__always) private func q(_ v: Double) -> Int { Int((v * 255).rounded()) }
}

/// The F-Pod palette. Every color in the game derives from these anchors.
public enum Palette {
    public static let ivory = RGBA(hex: 0xFFF1D6)
    public static let blueGray = RGBA(hex: 0xAECFDF)
    public static let slate = RGBA(hex: 0x526B83)
    public static let navy = RGBA(hex: 0x20364F)
    public static let tan = RGBA(hex: 0xE7BC75)
    public static let turquoise = RGBA(hex: 0x43AEB0)
    public static let ochre = RGBA(hex: 0xF8AF35)
    public static let coral = RGBA(hex: 0xD97966)

    // Status cues (small indicators only, always paired with icon + label).
    public static let statusGreen = RGBA(hex: 0x52AC66)
    public static let statusYellow = RGBA(hex: 0xE8BC46)
    public static let statusRed = RGBA(hex: 0xC85D54)

    // Reference image: warm cream architecture, blue tile and saturated green grounds.
    // Keep the primary ink dark enough for labels on every paper surface.
    public static let paper = RGBA(hex: 0xFFFCF2)
    public static let ink = RGBA(hex: 0x20334D)
    public static let inkSoft = RGBA(hex: 0x536B81)
    public static let shadow = RGBA(hex: 0x1E2C35, alpha: 0.20)
    public static let shadowStrong = RGBA(hex: 0x1E2C35, alpha: 0.32)
    public static let wallTop = RGBA(hex: 0xF8E4BB)
    public static let wallEdge = RGBA(hex: 0xCBA384)
    public static let floor = RGBA(hex: 0xAECFE2)
    public static let floorAlt = RGBA(hex: 0xA6C8DB)
    public static let grass = RGBA(hex: 0x54BC45)
    public static let grassDark = RGBA(hex: 0x36A449)
    public static let concrete = RGBA(hex: 0xD8D3C5)
    public static let track = RGBA(hex: 0xCC9E7B)
    public static let woods = RGBA(hex: 0x299747)
    public static let woodsDark = RGBA(hex: 0x1F793F)
    public static let tunnel = RGBA(hex: 0x9AA6A8)
    public static let wood = RGBA(hex: 0xC39C73)
    public static let metal = RGBA(hex: 0x95B6CC)
    public static let white = RGBA(hex: 0xFFFFFF)

    // World accents kept distinct from status indicators.
    public static let blanket = RGBA(hex: 0xFFAD32)
    public static let ceramic = RGBA(hex: 0xDAF5FA)
    public static let ceramicInset = RGBA(hex: 0xAFE0E9)
    public static let stone = RGBA(hex: 0x98A3B4)
    public static let lampGlow = RGBA(hex: 0xFFE9A0)

    // Skin tones (varied).
    public static let skins: [RGBA] = [
        RGBA(hex: 0xFFD0AF), RGBA(hex: 0xEDB88D), RGBA(hex: 0xD39971), RGBA(hex: 0xA8724E),
        RGBA(hex: 0x8A5A3C), RGBA(hex: 0x6B4430), RGBA(hex: 0xD9A982), RGBA(hex: 0xEBC6A3),
    ]
    public static let hairs: [RGBA] = [
        RGBA(hex: 0x2E2A28), RGBA(hex: 0x4A3A2E), RGBA(hex: 0x7A5638), RGBA(hex: 0xB08A5A),
        RGBA(hex: 0xC9C3B8), RGBA(hex: 0x8E8A85), RGBA(hex: 0x5C4033), RGBA(hex: 0xA55A3C),
    ]
}
