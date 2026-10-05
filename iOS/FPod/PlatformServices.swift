import UIKit

/// Haptic feedback mapped from core requests (respects the in-game setting upstream).
final class HapticsPlayer {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let notify = UINotificationFeedbackGenerator()

    func play(_ h: Haptic) {
        switch h {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .success: notify.notificationOccurred(.success)
        case .warning: notify.notificationOccurred(.warning)
        case .error: notify.notificationOccurred(.error)
        }
    }
}

/// Exposes the core's accessibility elements (labels, hints, frames) to VoiceOver.
final class AccessibilityOverlay: UIView {
    var onActivate: ((CGPoint) -> Void)?
    private var cache: [String: TapElement] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(_ items: [AXElement]) {
        guard UIAccessibility.isVoiceOverRunning else {
            if !cache.isEmpty { cache.removeAll(); accessibilityElements = [] }
            return
        }
        var list: [TapElement] = []
        var next: [String: TapElement] = [:]
        for item in items {
            let el = cache[item.id] ?? TapElement(accessibilityContainer: self)
            let r = CGRect(x: item.rect.x, y: item.rect.y, width: item.rect.w, height: item.rect.h)
            el.accessibilityFrameInContainerSpace = r
            el.accessibilityLabel = item.label
            el.accessibilityHint = item.hint
            el.accessibilityTraits = item.isButton ? .button : .staticText
            let center = CGPoint(x: r.midX, y: r.midY)
            el.onActivate = { [weak self] in self?.onActivate?(center) }
            next[item.id] = el
            list.append(el)
        }
        let changed = Set(next.keys) != Set(cache.keys)
        cache = next
        accessibilityElements = list
        if changed { UIAccessibility.post(notification: .layoutChanged, argument: nil) }
    }
}

final class TapElement: UIAccessibilityElement {
    var onActivate: (() -> Void)?
    override func accessibilityActivate() -> Bool {
        onActivate?()
        return true
    }
}

/// Saves: versioned JSON (FPodCore.SaveSystem) in Application Support, written off the
/// main thread with a backup; settings in UserDefaults.
final class SaveStore {
    private let queue = DispatchQueue(label: "fpod.save", qos: .utility)
    private let directory: URL
    private let settingsKey = "fpod.settings.v1"

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = base.appendingPathComponent("FPod", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var mainURL: URL { directory.appendingPathComponent("save.json") }
    var preFinaleURL: URL { directory.appendingPathComponent("prefinale.json") }

    func loadGame() -> GameState? {
        SaveSystem.load(from: mainURL)
    }

    func loadPreFinale() -> GameState? {
        SaveSystem.load(from: preFinaleURL)
    }

    func saveGame(_ state: GameState) {
        guard let data = try? SaveSystem.encode(state, label: "autosave") else { return }
        let url = mainURL
        queue.async { try? SaveSystem.writeData(data, to: url) }
    }

    func savePreFinale(_ state: GameState) {
        guard let data = try? SaveSystem.encode(state, label: "pre-finale") else { return }
        let url = preFinaleURL
        queue.async { try? SaveSystem.writeData(data, to: url) }
    }

    func loadSettings() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    func saveSettings(_ s: Settings) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: settingsKey) }
    }
}
