import UIKit
import SpriteKit

/// Hosts the SpriteKit view, the accessibility overlay, and keyboard input.
final class GameViewController: UIViewController {
    private var skView: SKView?
    private var scene: GameScene?
    private var axOverlay: AccessibilityOverlay?
    private let store = SaveStore()

    override func loadView() {
        view = SKView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        self.skView = skView
        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = false
        skView.preferredFramesPerSecond = 60

        let settings = store.loadSettings()
        let game: Game
        if let state = store.loadGame() {
            game = Game(state: state, settings: settings)
        } else {
            game = Game(seed: UInt64.random(in: 1...UInt64.max), settings: settings)
        }
        #if DEBUG
        game.isDevBuild = true
        #endif

        let size = view.bounds.size.width > 0 ? view.bounds.size : CGSize(width: 844, height: 390)
        let scene = GameScene(size: size, game: game, store: store)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        self.scene = scene

        let overlay = AccessibilityOverlay(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onActivate = { [weak self] point in self?.scene?.handleTap(at: point) }
        view.addSubview(overlay)
        axOverlay = overlay
        scene.axOverlay = overlay
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scale = view.window?.screen.scale ?? 2
        scene?.updateViewport(size: view.bounds.size, insets: view.safeAreaInsets, scale: scale)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    func pauseAndSave() {
        scene?.saveNow()
        scene?.isPaused = true
    }

    func resume() {
        scene?.isPaused = false
        scene?.resumeAudio()
    }

    // MARK: Keyboard (simulator / hardware keyboard, development convenience)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = press.key, let scene = scene, scene.keyDown(key.keyCode) { handled = true }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = press.key, let scene = scene, scene.keyUp(key.keyCode) { handled = true }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key { _ = scene?.keyUp(key.keyCode) }
        }
        super.pressesCancelled(presses, with: event)
    }
}
