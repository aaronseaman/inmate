import UIKit
import SpriteKit

/// Applies FPodCore display lists to SpriteKit: one sprite per RenderItem id,
/// textures cached by ArtKey, map chunks rasterized off the main thread.
final class Renderer {
    private unowned let scene: SKScene
    var screenScale: CGFloat
    private var art: ArtLibrary
    private var sprites: [String: SKSpriteNode] = [:]
    private var spriteArt: [String: ArtKey] = [:]
    private var shapes: [String: SKShapeNode] = [:]
    private var textures: [ArtKey: (texture: SKTexture, anchor: CGPoint, size: CGSize, lastUsed: Int)] = [:]
    private var pendingChunks: Set<ArtKey> = []
    private var frameIndex = 0
    private let workQueue = DispatchQueue(label: "fpod.raster", qos: .userInitiated)

    init(scene: SKScene, screenScale: CGFloat) {
        self.scene = scene
        self.screenScale = screenScale
        art = ArtLibrary(tileSize: 30)
    }

    private func isChunk(_ k: ArtKey) -> Bool {
        if case .chunk = k { return true }
        return false
    }

    /// Returns a cached texture or creates it (chunks asynchronously).
    private func texture(for key: ArtKey) -> (texture: SKTexture, anchor: CGPoint, size: CGSize)? {
        if var entry = textures[key] {
            entry.lastUsed = frameIndex
            textures[key] = entry
            return (entry.texture, entry.anchor, entry.size)
        }
        if isChunk(key) {
            if !pendingChunks.contains(key) {
                pendingChunks.insert(key)
                let library = art
                let scale = min(screenScale, 2)
                workQueue.async { [weak self] in
                    let drawing = library.drawing(key)
                    let result = Rasterizer.render(drawing, scale: scale)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.pendingChunks.remove(key)
                        guard let r = result, library.tileSize == self.art.tileSize else { return }
                        let tex = SKTexture(cgImage: r.image)
                        tex.filteringMode = .linear
                        self.textures[key] = (tex, r.anchor, r.size, self.frameIndex)
                    }
                }
            }
            return nil
        }
        guard let r = Rasterizer.render(art.drawing(key), scale: screenScale) else { return nil }
        let tex = SKTexture(cgImage: r.image)
        tex.filteringMode = .linear
        textures[key] = (tex, r.anchor, r.size, frameIndex)
        return (tex, r.anchor, r.size)
    }

    func apply(_ f: Frame) {
        frameIndex += 1
        if abs(art.tileSize - f.tileSize) > 0.01 {
            art = ArtLibrary(tileSize: f.tileSize)
            textures.removeAll()
            spriteArt.removeAll()
            pendingChunks.removeAll()
        }
        let H = Double(scene.size.height)
        let T = f.tileSize
        let halfW = f.viewport.x / 2, halfH = f.viewport.y / 2
        var seen = Set<String>()
        seen.reserveCapacity(f.items.count)
        for it in f.items {
            seen.insert(it.id)
            let node: SKSpriteNode
            if let existing = sprites[it.id] {
                node = existing
            } else {
                node = SKSpriteNode()
                node.blendMode = .alpha
                scene.addChild(node)
                sprites[it.id] = node
            }
            if spriteArt[it.id] != it.art {
                if let t = texture(for: it.art) {
                    node.texture = t.texture
                    node.size = t.size
                    node.anchorPoint = t.anchor
                    spriteArt[it.id] = it.art
                    node.isHidden = false
                } else {
                    // Texture still rendering (map chunk): keep the old one if any.
                    if node.texture == nil { node.isHidden = true }
                }
            } else {
                _ = texture(for: it.art)
                node.isHidden = false
            }
            let sx: Double, sy: Double
            if it.layer == .world {
                sx = (it.pos.x - f.camera.x) * T + halfW
                sy = (it.pos.y - f.camera.y) * T + halfH
            } else {
                sx = it.pos.x
                sy = it.pos.y
            }
            node.position = CGPoint(x: sx, y: H - sy)
            node.zRotation = CGFloat(-it.rotation)
            node.xScale = CGFloat(it.scaleX)
            node.yScale = CGFloat(it.scaleY)
            node.alpha = CGFloat(it.alpha)
            node.zPosition = CGFloat((it.layer == .world ? 0 : 100_000) + it.z)
        }
        for (id, node) in sprites where !seen.contains(id) {
            node.removeFromParent()
            sprites[id] = nil
            spriteArt[id] = nil
        }
        // Dynamic polygons (vision cones).
        var seenShapes = Set<String>()
        for p in f.polys {
            seenShapes.insert(p.id)
            let node: SKShapeNode
            if let existing = shapes[p.id] {
                node = existing
            } else {
                node = SKShapeNode()
                node.lineWidth = 0
                node.strokeColor = .clear
                node.isAntialiased = true
                scene.addChild(node)
                shapes[p.id] = node
            }
            let path = CGMutablePath()
            let pts = p.points.map { v -> CGPoint in
                let x = p.layer == .world ? (v.x - f.camera.x) * T + halfW : v.x
                let y = p.layer == .world ? (v.y - f.camera.y) * T + halfH : v.y
                return CGPoint(x: x, y: H - y)
            }
            if pts.count > 2 {
                path.addLines(between: pts)
                path.closeSubpath()
            }
            node.path = path
            node.fillColor = Rasterizer.color(p.fill)
            node.zPosition = CGFloat((p.layer == .world ? 0 : 100_000) + p.z)
        }
        for (id, node) in shapes where !seenShapes.contains(id) {
            node.removeFromParent()
            shapes[id] = nil
        }
        evict()
    }

    /// Bounded texture memory: keep at most ~16 map chunks and drop long-unused art.
    private func evict() {
        guard frameIndex % 120 == 0 else { return }
        let chunkKeys = textures.keys.filter { isChunk($0) }
        if chunkKeys.count > 16 {
            let sorted = chunkKeys.sorted { (textures[$0]?.lastUsed ?? 0) < (textures[$1]?.lastUsed ?? 0) }
            for k in sorted.prefix(chunkKeys.count - 16) where (textures[k]?.lastUsed ?? 0) < frameIndex - 2 { textures[k] = nil }
        }
        if textures.count > 1500 {
            let stale = textures.filter { frameIndex - $0.value.lastUsed > 600 }.map { $0.key }
            for k in stale { textures[k] = nil }
        }
    }
}
