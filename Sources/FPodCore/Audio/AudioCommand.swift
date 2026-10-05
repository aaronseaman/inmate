import Foundation

/// Audio requests drained by the platform layer each frame.
public enum AudioCommand: Equatable {
    case sfx(SFX, volume: Double, pan: Double, pitch: Double)
    case mumble(pitch: Double, volume: Double, pan: Double, seed: Int)
    case music(MusicMood)
    /// Duck cheerful music during distressing scenes (0 = silent, 1 = normal).
    case duck(Double)
}

public enum Haptic: Equatable {
    case light, medium, success, warning, error
}
