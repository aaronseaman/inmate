import Foundation

public enum PanelStyle: Int, Hashable, Codable { case card, chip, dark, toast, danger, inset, sheet, bar, scrim, highlight, paperLine }
public enum ButtonStyle: Int, Hashable, Codable { case round, roundLarge, pill, primary, danger, toggleOn, toggleOff, tab, tabActive, ghost, tile, tileSelected, disabled }

public enum FigurePart: Int, Hashable, Codable { case legL, legR, body, armL, armR, head, hair, prop, shadow }

public struct ShapeSpec: Hashable {
    public enum Kind: Int, Hashable { case rect, circle, ring, diamond, triangle, cone, capsule }
    public var kind: Kind
    public var w: Double
    public var h: Double
    public var radius: Double
    public var fill: RGBA?
    public var stroke: RGBA?
    public var lineWidth: Double
    public var shadow: Bool
    public init(_ kind: Kind, w: Double, h: Double, radius: Double = 0, fill: RGBA? = nil, stroke: RGBA? = nil, lineWidth: Double = 1, shadow: Bool = false) {
        self.kind = kind; self.w = w; self.h = h; self.radius = radius; self.fill = fill; self.stroke = stroke
        self.lineWidth = lineWidth; self.shadow = shadow
    }
    public static func == (a: ShapeSpec, b: ShapeSpec) -> Bool {
        a.kind == b.kind && Int(a.w * 2) == Int(b.w * 2) && Int(a.h * 2) == Int(b.h * 2) && Int(a.radius * 2) == Int(b.radius * 2)
            && a.fill == b.fill && a.stroke == b.stroke && Int(a.lineWidth * 4) == Int(b.lineWidth * 4) && a.shadow == b.shadow
    }
    public func hash(into h: inout Hasher) {
        h.combine(kind); h.combine(Int(w * 2)); h.combine(Int(self.h * 2)); h.combine(Int(radius * 2))
        h.combine(fill); h.combine(stroke); h.combine(Int(lineWidth * 4)); h.combine(shadow)
    }
}

public struct TextSpec: Hashable {
    public var lines: [String]
    public var size: Double
    public var weight: FontWeight
    public var color: RGBA
    public var align: TextAlign
    public var width: Double
    public static func == (a: TextSpec, b: TextSpec) -> Bool {
        a.lines == b.lines && Int(a.size * 2) == Int(b.size * 2) && a.weight == b.weight && a.color == b.color && a.align == b.align && Int(a.width) == Int(b.width)
    }
    public func hash(into h: inout Hasher) {
        h.combine(lines); h.combine(Int(size * 2)); h.combine(weight); h.combine(color); h.combine(align); h.combine(Int(width))
    }
}

public indirect enum ArtKey: Hashable {
    case chunk(Int, Int)
    case door(DoorKind, Bool, Int)
    case figure(FigurePart, Appearance, Facing)
    case prop(ObjKind, Int, Int, Int)
    case icon(Icon, Int, RGBA)
    case badge(Icon, Int, RGBA, RGBA)
    case bubble([Icon], Bool)
    case panel(Int, Int, PanelStyle)
    case shape(ShapeSpec)
    case text(TextSpec)
    case button(Int, Int, ButtonStyle)
    case marker(Int)
    case highlight(Int, Int)
    case mapOverview
    case named(String, Int, Int)
}

/// Every tappable thing on screen maps to one of these.
public enum UIAction: Hashable {
    case none
    case closeModal
    case openInventory, openMap, openJournal, openSettings, openMenu, openHelp
    case journalTab(Int)
    case toggleSneak, toggleRun, toggleStatus, park
    case contextInteract
    case fanOption(String)
    case invSelect(Slot, Int)
    case invMove(Slot)
    case invUse
    case invDropToStash
    case stashPut(Slot, Int)
    case stashTake(Int)
    case tradeConfirm
    case tradeOpen(String)
    case buy(ItemID)
    case choice(ChoiceID, Int)
    case outfit(Outfit)
    case phone(Int)
    case setting(String)
    case settingStep(String, Int)
    case minigameStart, minigameQuit, minigameContinue, minigameAssist
    case minigameButton(Int)
    case sceneContinue
    case scroll(String, Int)
    case dev(String)
    case comply
    case unhide
    case mapPan(Int, Int)
    case newGame, continueGame, saveGame, loadPreFinale, armNewGame
    case docOpen(DocID)
}

public struct HitRegion {
    public var rect: Rect
    public var action: UIAction
    public var z: Double
}

/// Immediate-mode UI emitter for screen-space items, hit regions and accessibility.
public struct UIBuilder {
    public var items: [RenderItem] = []
    public var polys: [PolyItem] = []
    public var hits: [HitRegion] = []
    public var ax: [AXElement] = []
    public var z: Double
    public let labels: Bool
    public var prefix: String

    public init(z: Double = 100, labels: Bool = true, prefix: String = "ui") {
        self.z = z; self.labels = labels; self.prefix = prefix
    }

    mutating func nz() -> Double { z += 0.01; return z }

    public mutating func panel(_ id: String, _ r: Rect, _ style: PanelStyle, alpha: Double = 1) {
        items.append(RenderItem(id: "\(prefix).\(id)", art: .panel(Int(r.w.rounded()), Int(r.h.rounded()), style),
                                pos: r.origin, z: nz(), layer: .screen, alpha: alpha))
    }

    @discardableResult
    public mutating func text(_ id: String, _ s: String, _ p: Vec2, size: Double, weight: FontWeight = .medium,
                              color: RGBA = Palette.ink, align: TextAlign = .left, width: Double? = nil, maxLines: Int = 1, alpha: Double = 1) -> Double {
        let w = width ?? TextMetrics.width(s, size: size, weight: weight) + 4
        var lines = maxLines > 1 ? TextMetrics.wrap(s, size: size, weight: weight, width: w) : [TextMetrics.truncate(s, size: size, weight: weight, width: w)]
        if lines.count > maxLines {
            lines = Array(lines.prefix(maxLines))
            lines[maxLines - 1] = TextMetrics.truncate(lines[maxLines - 1] + "…", size: size, weight: weight, width: w)
        }
        let spec = TextSpec(lines: lines, size: size, weight: weight, color: color, align: align, width: w)
        var origin = p
        if align == .center { origin.x -= w / 2 } else if align == .right { origin.x -= w }
        items.append(RenderItem(id: "\(prefix).\(id)", art: .text(spec), pos: origin, z: nz(), layer: .screen, alpha: alpha))
        return Double(lines.count) * TextMetrics.lineHeight(size)
    }

    public mutating func icon(_ id: String, _ icon: Icon, center: Vec2, size: Double, color: RGBA = Palette.ink, alpha: Double = 1) {
        items.append(RenderItem(id: "\(prefix).\(id)", art: .icon(icon, Int(size.rounded()), color),
                                pos: center - Vec2(size / 2, size / 2), z: nz(), layer: .screen, alpha: alpha))
    }

    public mutating func badge(_ id: String, _ icon: Icon, center: Vec2, size: Double, bg: RGBA, fg: RGBA, alpha: Double = 1) {
        items.append(RenderItem(id: "\(prefix).\(id)", art: .badge(icon, Int(size.rounded()), bg, fg),
                                pos: center - Vec2(size / 2, size / 2), z: nz(), layer: .screen, alpha: alpha))
    }

    public mutating func shape(_ id: String, _ spec: ShapeSpec, at topLeft: Vec2, alpha: Double = 1, rotation: Double = 0) {
        items.append(RenderItem(id: "\(prefix).\(id)", art: .shape(spec), pos: topLeft, z: nz(), layer: .screen, rotation: rotation, alpha: alpha))
    }

    public mutating func art(_ id: String, _ key: ArtKey, at topLeft: Vec2, alpha: Double = 1, scale: Double = 1, rotation: Double = 0) {
        items.append(RenderItem(id: "\(prefix).\(id)", art: key, pos: topLeft, z: nz(), layer: .screen, rotation: rotation, scaleX: scale, scaleY: scale, alpha: alpha))
    }

    public mutating func hit(_ r: Rect, _ action: UIAction, label: String? = nil, hint: String? = nil, id: String = "") {
        hits.append(HitRegion(rect: r, action: action, z: z))
        if let l = label { ax.append(AXElement(id: "\(prefix).\(id.isEmpty ? l : id)", rect: r, label: l, hint: hint, isButton: true)) }
    }

    /// Button: background + icon and/or label. Touch target expanded to at least 44pt.
    public mutating func button(_ id: String, _ r: Rect, icon: Icon? = nil, label: String? = nil, style: ButtonStyle = .round,
                                action: UIAction, ax: String, hint: String? = nil, enabled: Bool = true, iconColor: RGBA? = nil,
                                labelSize: Double = 13, badgeText: String? = nil) {
        let st = enabled ? style : .disabled
        items.append(RenderItem(id: "\(prefix).\(id).bg", art: .button(Int(r.w.rounded()), Int(r.h.rounded()), st), pos: r.origin, z: nz(), layer: .screen))
        let fg: RGBA = iconColor ?? UIBuilder.foreground(st)
        let hasLabel = label != nil && !(label!.isEmpty)
        if let ic = icon {
            let isz = min(r.h * (hasLabel && r.w < r.h * 1.6 ? 0.42 : 0.56), 30)
            var c = r.center
            if hasLabel {
                if r.w >= r.h * 1.6 { c = Vec2(r.x + r.h * 0.5 + 2, r.midY) } else { c = Vec2(r.midX, r.y + r.h * 0.38) }
            }
            self.icon(id + ".ic", ic, center: c, size: isz, color: fg)
        }
        if hasLabel, let l = label {
            if icon != nil && r.w < r.h * 1.6 {
                text(id + ".lb", l, Vec2(r.midX, r.y + r.h * 0.66), size: min(labelSize, 10.5), weight: .semibold, color: fg, align: .center, width: r.w - 4)
            } else if icon != nil {
                let left = r.x + r.h * 0.95
                text(id + ".lb", l, Vec2(left, r.midY - TextMetrics.lineHeight(labelSize) / 2), size: labelSize, weight: .semibold, color: fg, width: r.maxX - left - 8)
            } else {
                text(id + ".lb", l, Vec2(r.midX, r.midY - TextMetrics.lineHeight(labelSize) / 2), size: labelSize, weight: .semibold, color: fg, align: .center, width: r.w - 10)
            }
        }
        if let b = badgeText {
            let bw = max(18, TextMetrics.width(b, size: 10, weight: .bold) + 8)
            let br = Rect(r.maxX - bw * 0.7, r.y - 5, bw, 18)
            panel(id + ".bdg", br, .danger)
            text(id + ".bdgt", b, Vec2(br.midX, br.y + 2), size: 10, weight: .bold, color: Palette.paper, align: .center, width: bw)
        }
        let target = UIBuilder.touchTarget(r)
        if enabled { hit(target, action, label: ax, hint: hint, id: id) } else {
            hit(target, .none)
            self.ax.append(AXElement(id: "\(prefix).\(id)", rect: target, label: ax + " (unavailable)", hint: hint, isButton: true))
        }
    }

    public static func touchTarget(_ r: Rect) -> Rect {
        let w = max(44, r.w), h = max(44, r.h)
        return Rect(r.midX - w / 2, r.midY - h / 2, w, h)
    }

    public static func foreground(_ s: ButtonStyle) -> RGBA {
        switch s {
        case .primary, .danger, .toggleOn, .tabActive, .tileSelected: return Palette.paper
        case .disabled: return Palette.inkSoft.alpha(0.55)
        default: return Palette.ink
        }
    }
}
