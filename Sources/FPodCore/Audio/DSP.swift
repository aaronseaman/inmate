import Foundation

/// Minimal DSP toolkit for procedural audio (all original synthesis; no samples).
public enum DSP {
    public static let sampleRate: Double = 44100

    /// Plucked string (Karplus–Strong) with brightness and decay controls.
    public static func pluck(freq: Double, seconds: Double, decay: Double = 0.996, brightness: Double = 0.5, seed: UInt64, gain: Double = 1) -> [Float] {
        let n = max(1, Int(sampleRate * seconds))
        let period = max(2, Int(sampleRate / freq))
        var rng = RNG(seed: seed)
        var buf = [Double](repeating: 0, count: period)
        // Excitation: noise softened by a one-pole lowpass (lower brightness = softer pick).
        var lp = 0.0
        for i in 0..<period {
            let x = rng.double(-1, 1)
            lp += (x - lp) * (0.2 + 0.8 * brightness)
            buf[i] = lp
        }
        var out = [Float](repeating: 0, count: n)
        var idx = 0
        var prev = 0.0
        for i in 0..<n {
            let cur = buf[idx]
            let next = buf[(idx + 1) % period]
            let v = decay * (0.5 * (cur + next))
            buf[idx] = v * 0.98 + prev * 0.02
            prev = v
            out[i] = Float(cur * gain)
            idx = (idx + 1) % period
        }
        // Gentle attack to avoid clicks.
        for i in 0..<min(64, n) { out[i] *= Float(i) / 64 }
        return out
    }

    public static func sine(freq: Double, seconds: Double, gain: Double = 1, attack: Double = 0.005, decay: Double = 6, vibrato: Double = 0, vibratoRate: Double = 5.5) -> [Float] {
        let n = Int(sampleRate * seconds)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let f = freq * (1 + vibrato * sin(2 * .pi * vibratoRate * t))
            phase += 2 * .pi * f / sampleRate
            let env = min(1, t / max(attack, 1e-4)) * exp(-decay * t)
            out[i] = Float(sin(phase) * env * gain)
        }
        return out
    }

    /// Inharmonic bell/metal partials.
    public static func bell(freq: Double, seconds: Double, ratios: [Double] = [1, 2.76, 5.4, 8.93], decays: [Double] = [3, 5, 8, 12], gain: Double = 1) -> [Float] {
        var out = [Float](repeating: 0, count: Int(sampleRate * seconds))
        for (k, r) in ratios.enumerated() {
            let part = sine(freq: freq * r, seconds: seconds, gain: gain / Double(k + 1), attack: 0.001, decay: decays[min(k, decays.count - 1)])
            add(&out, part, at: 0)
        }
        return out
    }

    public static func noise(seconds: Double, seed: UInt64, gain: Double = 1) -> [Float] {
        var rng = RNG(seed: seed)
        return (0..<Int(sampleRate * seconds)).map { _ in Float(rng.double(-1, 1) * gain) }
    }

    /// Biquad filter (RBJ cookbook).
    public enum FilterKind { case lowpass, highpass, bandpass }
    public static func filter(_ x: [Float], _ kind: FilterKind, freq: Double, q: Double = 0.707) -> [Float] {
        let w0 = 2 * .pi * min(freq, sampleRate * 0.45) / sampleRate
        let alpha = sin(w0) / (2 * q)
        let c = cos(w0)
        var b0 = 0.0, b1 = 0.0, b2 = 0.0
        let a0 = 1 + alpha, a1 = -2 * c, a2 = 1 - alpha
        switch kind {
        case .lowpass: b0 = (1 - c) / 2; b1 = 1 - c; b2 = (1 - c) / 2
        case .highpass: b0 = (1 + c) / 2; b1 = -(1 + c); b2 = (1 + c) / 2
        case .bandpass: b0 = alpha; b1 = 0; b2 = -alpha
        }
        var y = [Float](repeating: 0, count: x.count)
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        for i in 0..<x.count {
            let xi = Double(x[i])
            let yi = (b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            y[i] = Float(yi)
            x2 = x1; x1 = xi; y2 = y1; y1 = yi
        }
        return y
    }

    /// Multiplies by an envelope function of time (seconds).
    public static func envelope(_ x: inout [Float], _ f: (Double) -> Double) {
        for i in 0..<x.count { x[i] *= Float(f(Double(i) / sampleRate)) }
    }

    public static func expDecay(_ x: inout [Float], attack: Double, decay: Double) {
        envelope(&x) { t in min(1, t / max(attack, 1e-4)) * exp(-decay * t) }
    }

    public static func add(_ dst: inout [Float], _ src: [Float], at offset: Int, gain: Float = 1) {
        guard offset < dst.count else { return }
        let n = min(src.count, dst.count - max(0, offset))
        if n <= 0 { return }
        for i in 0..<n where offset + i >= 0 { dst[offset + i] += src[i] * gain }
    }

    public static func normalize(_ x: inout [Float], peak: Float = 0.85) {
        let m = x.reduce(0) { max($0, abs($1)) }
        guard m > 1e-6 else { return }
        let k = peak / m
        for i in 0..<x.count { x[i] *= k }
    }

    /// Soft saturation keeps mixes below full scale without harsh clipping.
    public static func softClip(_ x: inout [Float]) {
        for i in 0..<x.count { x[i] = Float(tanh(Double(x[i]))) }
    }

    /// Small room: a few feedback delays (cheap, mono-to-stereo).
    public static func room(_ x: [Float], mix: Float = 0.14) -> ([Float], [Float]) {
        let delaysL = [1557, 1617, 1491, 1422].map { Int(Double($0) * sampleRate / 44100) }
        let delaysR = [1277, 1356, 1188, 1116].map { Int(Double($0) * sampleRate / 44100) }
        func comb(_ d: [Int]) -> [Float] {
            var out = [Float](repeating: 0, count: x.count)
            for delay in d {
                var buf = [Float](repeating: 0, count: delay)
                var idx = 0
                for i in 0..<x.count {
                    let y = buf[idx]
                    buf[idx] = x[i] + y * 0.72
                    idx = (idx + 1) % delay
                    out[i] += y * 0.25
                }
            }
            return out
        }
        let l = comb(delaysL), r = comb(delaysR)
        var L = x, R = x
        for i in 0..<x.count { L[i] = x[i] * (1 - mix) + l[i] * mix; R[i] = x[i] * (1 - mix) + r[i] * mix }
        return (L, R)
    }

    public static func midi(_ n: Int) -> Double { 440 * pow(2, Double(n - 69) / 12) }

    /// 16-bit PCM WAV encoding (for the dev tool).
    public static func wav(left: [Float], right: [Float]? = nil) -> Data {
        let ch = right == nil ? 1 : 2
        let frames = left.count
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + frames * ch * 2))
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(UInt16(ch)); u32(UInt32(sampleRate))
        u32(UInt32(sampleRate) * UInt32(ch) * 2); u16(UInt16(ch * 2)); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(frames * ch * 2))
        for i in 0..<frames {
            u16(UInt16(bitPattern: Int16(clamp(left[i], -1, 1) * 32767)))
            if let r = right { u16(UInt16(bitPattern: Int16(clamp(r[i], -1, 1) * 32767))) }
        }
        return d
    }
}
