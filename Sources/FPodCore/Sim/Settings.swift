import Foundation

public enum Difficulty: String, Codable, CaseIterable {
    case gentle, standard, sharp
    public var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .standard: return "Standard"
        case .sharp: return "Sharp"
        }
    }
    /// Multiplier on suspicion gain.
    public var suspicion: Double {
        switch self {
        case .gentle: return 0.6
        case .standard: return 1.0
        case .sharp: return 1.3
        }
    }
    /// Minigame timing windows scale (bigger = easier).
    public var window: Double {
        switch self {
        case .gentle: return 1.5
        case .standard: return 1.0
        case .sharp: return 0.75
        }
    }
    public var speed: Double {
        switch self {
        case .gentle: return 0.75
        case .standard: return 1.0
        case .sharp: return 1.2
        }
    }
}

public struct Settings: Codable, Equatable {
    public var musicVolume: Double = 0.65
    public var sfxVolume: Double = 0.8
    public var voiceVolume: Double = 0.7
    public var leftHanded = false
    public var reducedMotion = false
    public var conesAlways = false
    public var captions = true
    public var iconLabels = true
    public var difficulty: Difficulty = .standard
    public var haptics = true
    public var zoom: Double = 30
    public var bettingEnabled = true
    public var clockRate: Double = 1.0
    public var assistMinigames = false
    public var devMenuEnabled = false
    public init() {}
    public static let `default` = Settings()
}
