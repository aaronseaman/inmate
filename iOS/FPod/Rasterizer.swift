import UIKit

/// Rasterizes FPodCore vector Drawings with CoreGraphics. The SVG dev renderer
/// draws the same Drawings, so what the tests see is what ships.
struct RasterResult {
    let image: CGImage
    /// Size in points (including the shadow margin).
    let size: CGSize
    /// SpriteKit anchor point (0,0 = bottom-left) corresponding to the drawing's anchor.
    let anchor: CGPoint
}

enum Rasterizer {
    static func color(_ c: RGBA) -> UIColor {
        UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    static func point(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: v.y) }

    static func rect(_ r: Rect) -> CGRect { CGRect(x: r.x, y: r.y, width: r.w, height: r.h) }

    static func roundedFont(size: CGFloat, weight: FontWeight) -> UIFont {
        let w: UIFont.Weight
        switch weight {
        case .regular: w = .regular
        case .medium: w = .medium
        case .semibold: w = .semibold
        case .bold: w = .bold
        }
        let base = UIFont.systemFont(ofSize: size, weight: w)
        if let desc = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: desc, size: size)
        }
        return base
    }

    static func path(_ g: Geom) -> CGPath? {
        switch g {
        case .rect(let r, let radius):
            let cr = rect(r)
            guard cr.width > 0, cr.height > 0 else { return nil }
            let rad = max(0, min(CGFloat(radius), min(cr.width, cr.height) / 2 - 0.01))
            if rad <= 0 { return CGPath(rect: cr, transform: nil) }
            return CGPath(roundedRect: cr, cornerWidth: rad, cornerHeight: rad, transform: nil)
        case .ellipse(let r):
            let cr = rect(r)
            guard cr.width > 0, cr.height > 0 else { return nil }
            return CGPath(ellipseIn: cr, transform: nil)
        case .poly(let pts):
            guard pts.count > 2 else { return nil }
            let p = CGMutablePath()
            p.addLines(between: pts.map(point))
            p.closeSubpath()
            return p
        case .polyline(let pts):
            guard pts.count > 1 else { return nil }
            let p = CGMutablePath()
            p.addLines(between: pts.map(point))
            return p
        case .path(let ops):
            let p = CGMutablePath()
            var started = false
            for op in ops {
                switch op {
                case .move(let v): p.move(to: point(v)); started = true
                case .line(let v): if started { p.addLine(to: point(v)) } else { p.move(to: point(v)); started = true }
                case .quad(let c, let v): if started { p.addQuadCurve(to: point(v), control: point(c)) }
                case .cubic(let a, let b, let v): if started { p.addCurve(to: point(v), control1: point(a), control2: point(b)) }
                case .close: if started { p.closeSubpath() }
                }
            }
            return started ? p : nil
        case .text:
            return nil
        }
    }

    static func render(_ d: Drawing, scale: CGFloat) -> RasterResult? {
        let pad = CGFloat(max(abs(d.shadowOffset.x), abs(d.shadowOffset.y)) + d.shadowBlur * 2 + 1)
        let w = CGFloat(max(1, d.size.x)), h = CGFloat(max(1, d.size.y))
        let full = CGSize(width: ceil(w + pad * 2), height: ceil(h + pad * 2))
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: full, format: format)
        let shadowColor = UIColor(red: 0.118, green: 0.173, blue: 0.208, alpha: 0.2).cgColor
        let image = renderer.image { rc in
            let ctx = rc.cgContext
            ctx.translateBy(x: pad, y: pad)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for shape in d.shapes {
                if case .text(let t) = shape.geom {
                    drawText(t, drawingWidth: w)
                    continue
                }
                guard let p = path(shape.geom) else { continue }
                let isLine: Bool
                if case .polyline = shape.geom { isLine = true } else { isLine = false }
                if shape.shadow && !isLine {
                    ctx.saveGState()
                    ctx.translateBy(x: CGFloat(d.shadowOffset.x), y: CGFloat(d.shadowOffset.y))
                    ctx.setShadow(offset: .zero, blur: CGFloat(d.shadowBlur), color: shadowColor)
                    ctx.addPath(p)
                    ctx.setFillColor(shadowColor)
                    ctx.fillPath()
                    ctx.restoreGState()
                }
                if let f = shape.fill, !isLine {
                    ctx.addPath(p)
                    ctx.setFillColor(color(f).cgColor)
                    ctx.fillPath()
                }
                if let s = shape.stroke, shape.lineWidth > 0 {
                    ctx.addPath(p)
                    ctx.setStrokeColor(color(s).cgColor)
                    ctx.setLineWidth(CGFloat(shape.lineWidth))
                    ctx.strokePath()
                }
            }
        }
        guard let cg = image.cgImage else { return nil }
        let ax = (pad + CGFloat(d.anchor.x) * w) / full.width
        let ay = 1 - (pad + CGFloat(d.anchor.y) * h) / full.height
        return RasterResult(image: cg, size: full, anchor: CGPoint(x: ax, y: ay))
    }

    /// Single-line text at the run's box position; shrinks to fit the available width.
    static func drawText(_ t: TextRun, drawingWidth: CGFloat) {
        var size = CGFloat(t.size)
        var font = roundedFont(size: size, weight: t.weight)
        let fg = color(t.color)
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
        var measured = (t.text as NSString).size(withAttributes: attrs)
        let x0 = CGFloat(t.pos.x)
        let available: CGFloat
        switch t.align {
        case .left: available = drawingWidth - x0
        case .center: available = min(x0, drawingWidth - x0) * 2
        case .right: available = x0
        }
        if available > 4 && measured.width > available {
            size = max(6, size * available / measured.width)
            font = roundedFont(size: size, weight: t.weight)
            attrs[.font] = font
            measured = (t.text as NSString).size(withAttributes: attrs)
        }
        var x = x0
        switch t.align {
        case .left: break
        case .center: x -= measured.width / 2
        case .right: x -= measured.width
        }
        let lineHeight = CGFloat(TextMetrics.lineHeight(t.size))
        let y = CGFloat(t.pos.y) + (lineHeight - font.lineHeight) / 2
        (t.text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
    }
}
