import Foundation

extension Game {
    /// Visible world size in tiles.
    public var viewTiles: Vec2 { viewport.size / settings.zoom }

    /// Smooth follow, clamped to the current district (with margin so exits stay readable).
    func updateCamera(_ dt: Double) {
        if ui.districtFade > 0 { ui.districtFade = max(0, ui.districtFade - dt * 3.5) }
        let target = cameraTarget()
        if ui.cameraSnap || settings.reducedMotion && (ui.camera - target).length > 6 {
            ui.camera = target
            ui.cameraSnap = false
            return
        }
        let k = 1 - exp(-dt * 6)
        ui.camera = ui.camera.lerp(to: target, k)
    }

    func cameraTarget() -> Vec2 {
        var p = s.player.pos
        // Look slightly ahead in the walking direction.
        if s.player.moving { p = p + Vec2.fromAngle(s.player.heading) * 0.8 }
        let half = viewTiles / 2
        let district = playerDistrict
        guard var b = map.districtBounds[district]?.rect else { return p }
        let margin = 3.0
        b = Rect(b.x - margin, b.y - margin, b.w + 2 * margin, b.h + 2 * margin)
        var c = p
        if b.w <= half.x * 2 { c.x = b.midX } else { c.x = clamp(c.x, b.minX + half.x, b.maxX - half.x) }
        if b.h <= half.y * 2 { c.y = b.midY } else { c.y = clamp(c.y, b.minY + half.y, b.maxY - half.y) }
        return c
    }

    public func screenToWorld(_ p: Vec2) -> Vec2 {
        ui.camera + (p - viewport.size / 2) / settings.zoom
    }

    public func worldToScreen(_ w: Vec2) -> Vec2 {
        (w - ui.camera) * settings.zoom + viewport.size / 2
    }
}
