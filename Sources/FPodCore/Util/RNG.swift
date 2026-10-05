import Foundation

/// Deterministic, Codable random generator (SplitMix64). All gameplay randomness
/// flows through seeded instances so scenarios and saves are reproducible.
public struct RNG: Codable, Hashable {
    public var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [0, 1).
    public mutating func double() -> Double { Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0) }
    public mutating func double(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * double() }
    /// Uniform int in range (inclusive bounds).
    public mutating func int(_ lo: Int, _ hi: Int) -> Int {
        if hi <= lo { return lo }
        let span = UInt64(hi - lo + 1)
        return lo + Int(next() % span)
    }
    public mutating func chance(_ p: Double) -> Bool { double() < p }
    public mutating func pick<T>(_ a: [T]) -> T? { a.isEmpty ? nil : a[int(0, a.count - 1)] }
    public mutating func shuffle<T>(_ a: inout [T]) {
        guard a.count > 1 else { return }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = int(0, i)
            a.swapAt(i, j)
        }
    }
}

/// Stable string hash (FNV-1a 64) — Swift's Hasher is randomized per process,
/// so this is used for anything that must be stable across launches.
public func stableHash(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in s.utf8 {
        h ^= UInt64(b)
        h = h &* 0x100_0000_01b3
    }
    return h
}

public func stableHash(_ values: [UInt64]) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for v in values {
        var x = v
        for _ in 0..<8 {
            h ^= x & 0xff
            h = h &* 0x100_0000_01b3
            x >>= 8
        }
    }
    return h
}
