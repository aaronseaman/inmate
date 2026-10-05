import Foundation

/// Procedurally synthesized effects. Every sound is generated from code at launch.
public enum SFXBank {
    public static func render(_ s: SFX) -> [Float] {
        let sr = DSP.sampleRate
        var out: [Float]
        switch s {
        case .tap:
            out = DSP.sine(freq: 1450, seconds: 0.05, gain: 0.5, attack: 0.001, decay: 90)
            DSP.add(&out, DSP.filter(DSP.noise(seconds: 0.012, seed: 1, gain: 0.4), .highpass, freq: 3000), at: 0)
        case .confirm:
            out = [Float](repeating: 0, count: Int(sr * 0.32))
            DSP.add(&out, DSP.bell(freq: 660, seconds: 0.3, gain: 0.5), at: 0)
            DSP.add(&out, DSP.bell(freq: 990, seconds: 0.25, gain: 0.5), at: Int(sr * 0.08))
        case .cancel:
            out = [Float](repeating: 0, count: Int(sr * 0.3))
            DSP.add(&out, DSP.sine(freq: 520, seconds: 0.15, gain: 0.5, decay: 18), at: 0)
            DSP.add(&out, DSP.sine(freq: 390, seconds: 0.18, gain: 0.5, decay: 14), at: Int(sr * 0.09))
        case .buzzer:
            // Count buzzer: a dull, buzzy institutional tone.
            let n = Int(sr * 0.95)
            out = [Float](repeating: 0, count: n)
            for i in 0..<n {
                let t = Double(i) / sr
                let a = sin(2 * .pi * 118 * t) > 0 ? 1.0 : -1.0
                let b = sin(2 * .pi * 236.7 * t) > 0 ? 1.0 : -1.0
                let env = min(1, t / 0.02) * (t > 0.85 ? max(0, (0.95 - t) / 0.1) : 1)
                out[i] = Float((a * 0.5 + b * 0.25) * env * 0.35)
            }
            out = DSP.filter(out, .lowpass, freq: 1800)
        case .chime:
            // Intercom ding-dong.
            out = [Float](repeating: 0, count: Int(sr * 1.3))
            DSP.add(&out, DSP.bell(freq: 659.3, seconds: 1.0, ratios: [1, 2, 3.01], decays: [2.5, 4, 7], gain: 0.55), at: 0)
            DSP.add(&out, DSP.bell(freq: 523.3, seconds: 1.0, ratios: [1, 2, 3.01], decays: [2.5, 4, 7], gain: 0.55), at: Int(sr * 0.32))
        case .keys:
            out = [Float](repeating: 0, count: Int(sr * 0.5))
            var rng = RNG(seed: 9)
            for _ in 0..<9 {
                let f = rng.double(2600, 5200)
                let ting = DSP.bell(freq: f, seconds: 0.14, ratios: [1, 1.53, 2.31], decays: [30, 40, 55], gain: 0.25)
                DSP.add(&out, ting, at: Int(rng.double(0, 0.34) * sr))
            }
        case .door:
            out = DSP.sine(freq: 78, seconds: 0.25, gain: 0.7, attack: 0.002, decay: 18)
            DSP.add(&out, DSP.filter(DSP.noise(seconds: 0.04, seed: 3, gain: 0.5), .bandpass, freq: 1800, q: 2), at: Int(sr * 0.12))
        case .doorLock:
            out = [Float](repeating: 0, count: Int(sr * 0.6))
            DSP.add(&out, DSP.sine(freq: 62, seconds: 0.3, gain: 0.8, attack: 0.002, decay: 14), at: 0)
            DSP.add(&out, DSP.bell(freq: 221, seconds: 0.5, ratios: [1, 1.72, 2.51, 3.9], decays: [9, 12, 16, 22], gain: 0.4), at: Int(sr * 0.01))
            DSP.add(&out, DSP.filter(DSP.noise(seconds: 0.03, seed: 4, gain: 0.6), .highpass, freq: 2500), at: Int(sr * 0.2))
        case .cartWheels:
            out = [Float](repeating: 0, count: Int(sr * 0.9))
            for k in 0..<7 { DSP.add(&out, DSP.filter(DSP.noise(seconds: 0.02, seed: UInt64(10 + k), gain: 0.5), .bandpass, freq: 900, q: 3), at: Int(Double(k) * 0.12 * sr)) }
            var sq = DSP.sine(freq: 1900, seconds: 0.5, gain: 0.08, attack: 0.05, decay: 3, vibrato: 0.04, vibratoRate: 7)
            DSP.expDecay(&sq, attack: 0.05, decay: 3)
            DSP.add(&out, sq, at: Int(sr * 0.2))
        case .tvMumble:
            out = DSP.filter(DSP.noise(seconds: 1.2, seed: 5, gain: 0.5), .bandpass, freq: 900, q: 1.2)
            DSP.envelope(&out) { t in (0.55 + 0.45 * sin(2 * .pi * 4.3 * t) * sin(2 * .pi * 1.1 * t)) * min(1, t / 0.05) * min(1, (1.2 - t) / 0.1) }
            DSP.add(&out, SFXBank.mumble(pitch: 1.1, seed: 4, syllables: 6), at: Int(sr * 0.1), gain: 0.3)
        case .laundry:
            out = DSP.filter(DSP.noise(seconds: 1.6, seed: 6, gain: 0.8), .lowpass, freq: 180)
            DSP.envelope(&out) { t in (0.6 + 0.4 * max(0, sin(2 * .pi * 1.8 * t))) * min(1, t / 0.2) * min(1, (1.6 - t) / 0.3) }
        case .step:
            out = DSP.filter(DSP.noise(seconds: 0.06, seed: 7, gain: 0.7), .lowpass, freq: 500)
            DSP.expDecay(&out, attack: 0.002, decay: 60)
        case .stepSoft:
            out = DSP.filter(DSP.noise(seconds: 0.05, seed: 8, gain: 0.4), .lowpass, freq: 350)
            DSP.expDecay(&out, attack: 0.004, decay: 70)
        case .stepRun:
            out = DSP.filter(DSP.noise(seconds: 0.06, seed: 9, gain: 0.9), .lowpass, freq: 900)
            DSP.expDecay(&out, attack: 0.001, decay: 55)
            DSP.add(&out, DSP.sine(freq: 2400, seconds: 0.04, gain: 0.05, decay: 60), at: Int(sr * 0.01))
        case .pickup:
            out = DSP.sine(freq: 700, seconds: 0.16, gain: 0.4, decay: 14)
            DSP.add(&out, DSP.sine(freq: 1050, seconds: 0.14, gain: 0.35, decay: 16), at: Int(sr * 0.05))
            DSP.add(&out, DSP.filter(DSP.noise(seconds: 0.05, seed: 11, gain: 0.25), .highpass, freq: 2000), at: 0)
        case .drop:
            out = DSP.sine(freq: 140, seconds: 0.2, gain: 0.6, attack: 0.002, decay: 22)
            DSP.add(&out, DSP.filter(DSP.noise(seconds: 0.05, seed: 12, gain: 0.3), .lowpass, freq: 1200), at: 0)
        case .coin:
            out = [Float](repeating: 0, count: Int(sr * 0.4))
            DSP.add(&out, DSP.bell(freq: 1568, seconds: 0.3, ratios: [1, 2.4, 3.9], decays: [10, 16, 24], gain: 0.4), at: 0)
            DSP.add(&out, DSP.bell(freq: 2093, seconds: 0.3, ratios: [1, 2.4, 3.9], decays: [10, 16, 24], gain: 0.35), at: Int(sr * 0.07))
        case .alert:
            out = [Float](repeating: 0, count: Int(sr * 0.5))
            for (k, f) in [440.0, 554.4].enumerated() {
                var tone = DSP.sine(freq: f, seconds: 0.18, gain: 0.45, attack: 0.004, decay: 8)
                tone = DSP.filter(tone, .lowpass, freq: 2000)
                DSP.add(&out, tone, at: Int(Double(k) * 0.16 * sr))
                DSP.add(&out, DSP.sine(freq: f * 2.01, seconds: 0.15, gain: 0.12, decay: 14), at: Int(Double(k) * 0.16 * sr))
            }
        case .question:
            let n = Int(sr * 0.22)
            out = [Float](repeating: 0, count: n)
            var ph = 0.0
            for i in 0..<n {
                let t = Double(i) / sr
                ph += 2 * .pi * (480 + 420 * t / 0.22) / sr
                out[i] = Float(sin(ph) * 0.4 * min(1, t / 0.01) * exp(-6 * t))
            }
        case .caught:
            out = [Float](repeating: 0, count: Int(sr * 1.0))
            for (k, f) in [329.6, 293.7, 246.9].enumerated() {
                DSP.add(&out, DSP.pluck(freq: f, seconds: 0.5, decay: 0.993, brightness: 0.35, seed: UInt64(20 + k), gain: 0.6), at: Int(Double(k) * 0.2 * sr))
            }
            DSP.add(&out, DSP.sine(freq: 60, seconds: 0.4, gain: 0.5, decay: 9), at: Int(0.6 * sr))
        case .paper:
            out = DSP.filter(DSP.noise(seconds: 0.18, seed: 13, gain: 0.5), .highpass, freq: 2500)
            DSP.envelope(&out) { t in (0.5 + 0.5 * sin(2 * .pi * 38 * t)) * exp(-14 * t) }
        case .whistle:
            out = [Float](repeating: 0, count: Int(sr * 0.8))
            for (k, m) in [79, 83, 86].enumerated() {
                DSP.add(&out, DSP.sine(freq: DSP.midi(m), seconds: 0.3, gain: 0.3, attack: 0.03, decay: 3, vibrato: 0.012, vibratoRate: 6), at: Int(Double(k) * 0.2 * sr))
            }
        case .mumble:
            out = mumble(pitch: 1, seed: 1)
        case .hatch:
            out = DSP.filter(DSP.noise(seconds: 0.35, seed: 14, gain: 0.5), .bandpass, freq: 700, q: 1.5)
            DSP.expDecay(&out, attack: 0.05, decay: 6)
            DSP.add(&out, DSP.bell(freq: 180, seconds: 0.4, ratios: [1, 1.9, 2.7], decays: [10, 14, 20], gain: 0.5), at: Int(sr * 0.25))
        case .error:
            out = [Float](repeating: 0, count: Int(sr * 0.35))
            for k in 0..<2 { DSP.add(&out, DSP.filter(DSP.sine(freq: 180, seconds: 0.12, gain: 0.6, decay: 10), .lowpass, freq: 900), at: Int(Double(k) * 0.15 * sr)) }
        case .success:
            out = [Float](repeating: 0, count: Int(sr * 0.9))
            for (k, m) in [67, 71, 74, 79].enumerated() {
                DSP.add(&out, DSP.pluck(freq: DSP.midi(m), seconds: 0.6, decay: 0.996, brightness: 0.55, seed: UInt64(30 + k), gain: 0.55), at: Int(Double(k) * 0.07 * sr))
            }
        case .fail:
            out = [Float](repeating: 0, count: Int(sr * 0.7))
            for (k, m) in [64, 60].enumerated() {
                DSP.add(&out, DSP.pluck(freq: DSP.midi(m), seconds: 0.5, decay: 0.994, brightness: 0.4, seed: UInt64(40 + k), gain: 0.6), at: Int(Double(k) * 0.16 * sr))
            }
        case .minigameTick:
            out = DSP.sine(freq: 2200, seconds: 0.03, gain: 0.3, attack: 0.0005, decay: 120)
        case .thud:
            out = DSP.sine(freq: 70, seconds: 0.3, gain: 0.8, attack: 0.002, decay: 14)
        case .splash:
            out = DSP.filter(DSP.noise(seconds: 0.4, seed: 15, gain: 0.6), .lowpass, freq: 2500)
            DSP.expDecay(&out, attack: 0.005, decay: 9)
            var rng = RNG(seed: 16)
            for _ in 0..<5 { DSP.add(&out, DSP.sine(freq: rng.double(500, 1100), seconds: 0.06, gain: 0.12, decay: 40), at: Int(rng.double(0.02, 0.25) * sr)) }
        case .swish:
            let n = Int(sr * 0.25)
            let src = DSP.noise(seconds: 0.25, seed: 17, gain: 0.6)
            out = [Float](repeating: 0, count: n)
            // Sweep by blending two bandpasses.
            let lo = DSP.filter(src, .bandpass, freq: 600, q: 1.2), hi = DSP.filter(src, .bandpass, freq: 2800, q: 1.2)
            for i in 0..<n {
                let t = Double(i) / Double(n)
                out[i] = Float((Double(lo[i]) * (1 - t) + Double(hi[i]) * t) * sin(.pi * t))
            }
        case .clank:
            out = DSP.bell(freq: 310, seconds: 0.5, ratios: [1, 1.6, 2.33, 3.7], decays: [8, 11, 15, 20], gain: 0.5)
        case .sleep:
            out = [Float](repeating: 0, count: Int(sr * 1.6))
            for (k, m) in [72, 67, 64, 60].enumerated() {
                DSP.add(&out, DSP.pluck(freq: DSP.midi(m), seconds: 1.0, decay: 0.997, brightness: 0.3, seed: UInt64(50 + k), gain: 0.45), at: Int(Double(k) * 0.3 * sr))
            }
        }
        DSP.normalize(&out, peak: gain(s))
        return out
    }

    /// Relative loudness per sound.
    static func gain(_ s: SFX) -> Float {
        switch s {
        case .step, .stepSoft: return 0.35
        case .stepRun: return 0.45
        case .tap, .minigameTick: return 0.4
        case .buzzer: return 0.7
        case .tvMumble, .laundry: return 0.4
        case .paper: return 0.35
        default: return 0.7
        }
    }

    /// Character mumbles: formant-filtered pulse trains, a few syllables, pitch per person.
    public static func mumble(pitch: Double, seed: Int, syllables: Int? = nil) -> [Float] {
        let sr = DSP.sampleRate
        var rng = RNG(seed: UInt64(seed) &* 2654435761 &+ UInt64(pitch * 1000))
        let count = syllables ?? rng.int(2, 4)
        let vowels: [(Double, Double)] = [(730, 1090), (530, 1840), (570, 840), (300, 870), (400, 2000)]
        var out = [Float](repeating: 0, count: Int(sr * (0.14 * Double(count) + 0.2)))
        var t0 = 0.0
        let f0 = 150 * pitch
        for k in 0..<count {
            let dur = rng.double(0.085, 0.13)
            let n = Int(sr * dur)
            var src = [Float](repeating: 0, count: n)
            var ph = 0.0
            let glide = rng.double(-0.12, 0.18) * (k == count - 1 ? 1 : 0.4)
            for i in 0..<n {
                let t = Double(i) / Double(n)
                let f = f0 * (1 + glide * t) * (1 + 0.02 * sin(2 * .pi * 6 * t))
                ph += f / sr
                let saw = 2 * (ph - floor(ph)) - 1
                src[i] = Float(saw)
            }
            let v = vowels[rng.int(0, vowels.count - 1)]
            let a = DSP.filter(src, .bandpass, freq: v.0 * (0.9 + 0.2 * pitch / 1.2), q: 4)
            let b = DSP.filter(src, .bandpass, freq: v.1 * (0.9 + 0.2 * pitch / 1.2), q: 5)
            var syl = [Float](repeating: 0, count: n)
            for i in 0..<n {
                let t = Double(i) / Double(n)
                let env = sin(.pi * t) * (0.75 + 0.25 * sin(.pi * t))
                syl[i] = (a[i] + b[i] * 0.6) * Float(env)
            }
            DSP.add(&out, syl, at: Int(t0 * sr))
            t0 += dur + rng.double(0.02, 0.05)
        }
        DSP.normalize(&out, peak: 0.6)
        return out
    }
}
