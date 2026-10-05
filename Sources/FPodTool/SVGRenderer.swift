import Foundation
import FPodCore

/// Renders a Frame to SVG using the exact same Drawings the iOS renderer rasterizes.
final class SVGRenderer {
    let art: ArtLibrary
    var defs: [String] = []
    var ids: [ArtKey: String] = [:]
    var drawings: [ArtKey: Drawing] = [:]
    var filterUsed = false

    init(tileSize: Double) { art = ArtLibrary(tileSize: tileSize) }

    func color(_ c: RGBA) -> String { c.hexString }
    func f(_ v: Double) -> String { String(format: "%.2f", v) }

    func geomSVG(_ g: Geom, fill: String, stroke: String, extra: String = "", boxWidth: Double? = nil) -> String {
        switch g {
        case .rect(let r, let rad):
            return "<rect x=\"\(f(r.x))\" y=\"\(f(r.y))\" width=\"\(f(max(0, r.w)))\" height=\"\(f(max(0, r.h)))\" rx=\"\(f(min(rad, min(r.w, r.h) / 2)))\" \(fill) \(stroke) \(extra)/>"
        case .ellipse(let r):
            return "<ellipse cx=\"\(f(r.midX))\" cy=\"\(f(r.midY))\" rx=\"\(f(r.w / 2))\" ry=\"\(f(r.h / 2))\" \(fill) \(stroke) \(extra)/>"
        case .poly(let pts):
            return "<polygon points=\"\(pts.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " "))\" \(fill) \(stroke) \(extra)/>"
        case .polyline(let pts):
            return "<polyline points=\"\(pts.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " "))\" fill=\"none\" \(stroke) stroke-linecap=\"round\" stroke-linejoin=\"round\" \(extra)/>"
        case .path(let ops):
            var d = ""
            for op in ops {
                switch op {
                case .move(let v): d += "M\(f(v.x)) \(f(v.y)) "
                case .line(let v): d += "L\(f(v.x)) \(f(v.y)) "
                case .quad(let c, let v): d += "Q\(f(c.x)) \(f(c.y)) \(f(v.x)) \(f(v.y)) "
                case .cubic(let a, let b, let v): d += "C\(f(a.x)) \(f(a.y)) \(f(b.x)) \(f(b.y)) \(f(v.x)) \(f(v.y)) "
                case .close: d += "Z "
                }
            }
            return "<path d=\"\(d)\" \(fill) \(stroke) \(extra)/>"
        case .text(let t):
            let anchor = t.align == .left ? "start" : (t.align == .center ? "middle" : "end")
            let weight = [400, 500, 600, 700][t.weight.rawValue]
            let lh = TextMetrics.lineHeight(t.size)
            let baseline = t.pos.y + (lh - t.size) / 2 + t.size * 0.82
            let esc = t.text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            // Like the iOS rasterizer, text shrinks to fit the width left in its box; tools/svg2png.js
            // measures with the real font and applies it.
            var maxW = ""
            if let bw = boxWidth {
                let avail: Double
                switch t.align {
                case .left: avail = bw - t.pos.x
                case .center: avail = min(t.pos.x, bw - t.pos.x) * 2
                case .right: avail = t.pos.x
                }
                if avail > 4 { maxW = " data-maxw=\"\(f(avail))\"" }
            }
            return "<text\(maxW) x=\"\(f(t.pos.x))\" y=\"\(f(baseline))\" font-size=\"\(f(t.size))\" font-weight=\"\(weight)\" text-anchor=\"\(anchor)\" fill=\"\(color(t.color))\" fill-opacity=\"\(f(t.color.a))\" font-family=\"Nunito, 'SF Pro Rounded', 'Arial Rounded MT Bold', 'DejaVu Sans', sans-serif\">\(esc)</text>"
        }
    }

    func drawingSVG(_ d: Drawing) -> String {
        var out = ""
        for sh in d.shapes {
            let fill = sh.fill.map { "fill=\"\(color($0))\" fill-opacity=\"\(f($0.a))\"" } ?? "fill=\"none\""
            let stroke = sh.stroke.map { "stroke=\"\(color($0))\" stroke-opacity=\"\(f($0.a))\" stroke-width=\"\(f(sh.lineWidth))\"" } ?? ""
            if sh.shadow, case .text = sh.geom {} else if sh.shadow {
                filterUsed = true
                let sfill = "fill=\"#1E2C35\" fill-opacity=\"0.2\""
                out += "<g transform=\"translate(\(f(d.shadowOffset.x)),\(f(d.shadowOffset.y)))\" filter=\"url(#soft)\">" + geomSVG(sh.geom, fill: sfill, stroke: "") + "</g>"
            }
            if case .text = sh.geom { out += geomSVG(sh.geom, fill: "", stroke: "", boxWidth: d.size.x) } else { out += geomSVG(sh.geom, fill: fill, stroke: stroke) }
        }
        return out
    }

    func defID(_ key: ArtKey) -> (String, Drawing) {
        if let id = ids[key], let d = drawings[key] { return (id, d) }
        let d = art.drawing(key)
        let id = "a\(ids.count)"
        ids[key] = id
        drawings[key] = d
        defs.append("<g id=\"\(id)\">\(drawingSVG(d))</g>")
        return (id, d)
    }

    func render(_ frame: Frame) -> String {
        let T = frame.tileSize
        let half = frame.viewport / 2
        var body = ""
        body += "<rect x=\"0\" y=\"0\" width=\"\(f(frame.viewport.x))\" height=\"\(f(frame.viewport.y))\" fill=\"\(color(frame.background))\"/>"
        // Merge items and polys by z within layers.
        enum Entry { case item(RenderItem), poly(PolyItem) }
        var entries: [(Int, Double, Entry)] = frame.items.map { ($0.layer.rawValue, $0.z, .item($0)) }
        entries += frame.polys.map { ($0.layer.rawValue, $0.z, .poly($0)) }
        entries.sort { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
        for (_, _, e) in entries {
            switch e {
            case .poly(let p):
                let pts = p.points.map { p.layer == .world ? ($0 - frame.camera) * T + half : $0 }
                body += "<polygon points=\"\(pts.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " "))\" fill=\"\(color(p.fill))\" fill-opacity=\"\(f(p.fill.a))\"/>"
            case .item(let it):
                let (id, d) = defID(it.art)
                let sp = it.layer == .world ? (it.pos - frame.camera) * T + half : it.pos
                let ax = d.anchor.x * d.size.x, ay = d.anchor.y * d.size.y
                let deg = it.rotation * 180 / .pi
                body += "<use href=\"#\(id)\" opacity=\"\(f(it.alpha))\" transform=\"translate(\(f(sp.x)),\(f(sp.y))) rotate(\(f(deg))) scale(\(f(it.scaleX)),\(f(it.scaleY))) translate(\(f(-ax)),\(f(-ay)))\"/>"
            }
        }
        let filter = "<filter id=\"soft\" x=\"-20%\" y=\"-20%\" width=\"140%\" height=\"140%\"><feGaussianBlur stdDeviation=\"0.9\"/></filter>"
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(Int(frame.viewport.x))\" height=\"\(Int(frame.viewport.y))\" viewBox=\"0 0 \(f(frame.viewport.x)) \(f(frame.viewport.y))\"><defs>\(filter)\(defs.joined())</defs>\(body)</svg>"
    }
}
