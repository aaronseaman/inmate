import UIKit
import SpriteKit

/// Drives the core game each frame and forwards input; all game logic lives in FPodCore.
final class GameScene: SKScene {
    private(set) var game: Game
    private let store: SaveStore
    private var renderer: Renderer?
    private let audio = AudioPlayer()
    private let haptics = HapticsPlayer()
    weak var axOverlay: AccessibilityOverlay?
    private var lastTime: TimeInterval = 0
    private var heldKeys: Set<UIKeyboardHIDUsage> = []
    private var touchStart: (point: CGPoint, time: TimeInterval)?
    private var autosaveCooldown: Double = 0
    private var axTimer: Double = 0
    private var lastAXCount = -1

    init(size: CGSize, game: Game, store: SaveStore) {
        self.game = game
        self.store = store
        super.init(size: size)
        backgroundColor = UIColor(red: 0.345, green: 0.478, blue: 0.369, alpha: 1)
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        renderer = Renderer(scene: self, screenScale: view.contentScaleFactor)
        audio.start(settings: game.settings)
    }

    func updateViewport(size: CGSize, insets: UIEdgeInsets, scale: CGFloat) {
        guard size.width > 0, size.height > 0 else { return }
        self.size = size
        game.viewport = Viewport(size: Vec2(Double(size.width), Double(size.height)),
                                 safeTop: Double(insets.top), safeLeft: Double(insets.left),
                                 safeBottom: Double(insets.bottom), safeRight: Double(insets.right),
                                 scale: Double(scale))
        renderer?.screenScale = scale
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60.0 : min(0.1, currentTime - lastTime)
        lastTime = currentTime
        game.ui.devMove = keyVector()
        game.update(dt: dt)
        let frame = game.buildFrame()
        renderer?.apply(frame)
        for command in game.drainAudio() { audio.handle(command, settings: game.settings) }
        for h in game.drainHaptics() { haptics.play(h) }
        audio.update(dt: dt, settings: game.settings)
        if game.settingsChanged {
            game.settingsChanged = false
            store.saveSettings(game.settings)
        }
        autosaveCooldown -= dt
        if game.saveRequested && autosaveCooldown <= 0 && game.transition == nil && game.minigame == nil {
            game.saveRequested = false
            autosaveCooldown = 4
            store.saveGame(game.s)
        }
        if game.ui.preFinaleSaveRequested {
            game.ui.preFinaleSaveRequested = false
            store.savePreFinale(game.s)
        }
        if let request = game.ui.platformRequest {
            game.ui.platformRequest = nil
            replaceGame(for: request)
        }
        axTimer -= dt
        if axTimer <= 0 || frame.accessibility.count != lastAXCount {
            axTimer = 0.5
            lastAXCount = frame.accessibility.count
            axOverlay?.update(frame.accessibility)
        }
    }

    /// Ending screen: go back to the pre-finale save, or start over. Settings carry across.
    private func replaceGame(for request: PlatformRequest) {
        let next: Game
        switch request {
        case .loadPreFinale:
            guard let state = store.loadPreFinale() else { return }
            next = Game(state: state, settings: game.settings)
        case .newGame:
            next = Game(seed: UInt64.random(in: 1...UInt64.max), settings: game.settings)
        }
        next.viewport = game.viewport
        next.isDevBuild = game.isDevBuild
        game = next
        lastTime = 0
        store.saveGame(game.s)
    }

    func saveNow() {
        store.saveGame(game.s)
        store.saveSettings(game.settings)
    }

    func resumeAudio() {
        audio.resume(settings: game.settings)
    }

    // MARK: Touch → tap

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let view = view else { return }
        touchStart = (t.location(in: view), t.timestamp)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let view = view, let start = touchStart else { return }
        touchStart = nil
        let p = t.location(in: view)
        let moved = hypot(p.x - start.point.x, p.y - start.point.y)
        // Tap-only game: drags and long presses are ignored rather than misread.
        if moved < 18 && t.timestamp - start.time < 0.6 {
            handleTap(at: p)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    func handleTap(at p: CGPoint) {
        game.tap(Vec2(Double(p.x), Double(p.y)))
    }

    // MARK: Keyboard

    func keyDown(_ key: UIKeyboardHIDUsage) -> Bool {
        switch key {
        case .keyboardW, .keyboardA, .keyboardS, .keyboardD, .keyboardUpArrow, .keyboardDownArrow, .keyboardLeftArrow, .keyboardRightArrow:
            heldKeys.insert(key)
        case .keyboardSpacebar, .keyboardE, .keyboardReturnOrEnter:
            if game.transition != nil { game.perform(.sceneContinue) } else { game.perform(.contextInteract) }
        case .keyboardR: game.perform(.toggleRun)
        case .keyboardC: game.perform(.toggleSneak)
        case .keyboardI: game.perform(.openInventory)
        case .keyboardM: game.perform(.openMap)
        case .keyboardJ: game.perform(.openJournal)
        case .keyboardEscape: game.perform(game.ui.modal == nil ? .openMenu : .closeModal)
        case .keyboardF1: if game.isDevBuild { game.perform(.dev("open")) }
        default: return false
        }
        return true
    }

    func keyUp(_ key: UIKeyboardHIDUsage) -> Bool {
        if heldKeys.contains(key) {
            heldKeys.remove(key)
            return true
        }
        return false
    }

    private func keyVector() -> Vec2 {
        var v = Vec2.zero
        if heldKeys.contains(.keyboardW) || heldKeys.contains(.keyboardUpArrow) { v.y -= 1 }
        if heldKeys.contains(.keyboardS) || heldKeys.contains(.keyboardDownArrow) { v.y += 1 }
        if heldKeys.contains(.keyboardA) || heldKeys.contains(.keyboardLeftArrow) { v.x -= 1 }
        if heldKeys.contains(.keyboardD) || heldKeys.contains(.keyboardRightArrow) { v.x += 1 }
        return v
    }
}
