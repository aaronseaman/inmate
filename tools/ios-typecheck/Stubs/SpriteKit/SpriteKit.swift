// Type-check stub of the SpriteKit API subset used by iOS/FPod. Never shipped.
import UIKit

public enum SKSceneScaleMode: Int { case fill, aspectFill, aspectFit, resizeFill }
public enum SKBlendMode: Int { case alpha, add, subtract, multiply, multiplyX2, screen, replace, multiplyAlpha }
public enum SKTextureFilteringMode: Int { case nearest, linear }

open class SKTexture {
    public init(cgImage image: CGImage) {}
    open var filteringMode: SKTextureFilteringMode = .linear
}

open class SKNode: UIResponder {
    public override init() { super.init() }
    open var position: CGPoint = .zero
    open var zRotation: CGFloat = 0
    open var xScale: CGFloat = 1
    open var yScale: CGFloat = 1
    open var alpha: CGFloat = 1
    open var zPosition: CGFloat = 0
    open var isHidden: Bool = false
    open var isPaused: Bool = false
    open func addChild(_ node: SKNode) {}
    open func removeFromParent() {}
}

open class SKSpriteNode: SKNode {
    public override init() { super.init() }
    open var texture: SKTexture?
    open var size: CGSize = .zero
    open var anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    open var blendMode: SKBlendMode = .alpha
}

open class SKShapeNode: SKNode {
    public override init() { super.init() }
    open var path: CGPath?
    open var fillColor: UIColor = .clear
    open var strokeColor: UIColor = .clear
    open var lineWidth: CGFloat = 1
    open var isAntialiased: Bool = true
}

open class SKView: UIView {
    open var ignoresSiblingOrder: Bool = false
    open var preferredFramesPerSecond: Int = 60
    open func presentScene(_ scene: SKScene?) {}
}

open class SKScene: SKNode {
    public init(size: CGSize) { super.init() }
    public required init?(coder aDecoder: NSCoder) { super.init() }
    open var size: CGSize = .zero
    open var scaleMode: SKSceneScaleMode = .fill
    open var backgroundColor: UIColor = .clear
    open var anchorPoint: CGPoint = .zero
    open var view: SKView? { nil }
    open func update(_ currentTime: TimeInterval) {}
    open func didMove(to view: SKView) {}
}
