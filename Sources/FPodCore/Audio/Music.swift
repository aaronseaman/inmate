import Foundation

public struct MusicLoop {
    public var left: [Float]
    public var right: [Float]
    public var bpm: Double
    public var seconds: Double { Double(left.count) / DSP.sampleRate }
}

/// Oddly upbeat acoustic guitar and whistling, plus night/search/tense/quiet/finale
/// variants. Composed and synthesized in code (plucked-string synthesis), loop-seamless.
public enum MusicComposer {
    typealias Chord = [Int]
    static let chords: [String: Chord] = [
        "G": [43, 47, 50, 55, 59, 67], "Em": [40, 47, 52, 55, 59, 64], "C": [48, 52, 55, 60, 64],
        "D": [50, 57, 62, 66], "Am": [45, 52, 57, 60, 64], "A": [45, 52, 57, 61, 64], "E": [40, 47, 52, 56, 59, 64],
        "Bm": [47, 54, 59, 62, 66], "F#m": [42, 49, 54, 57, 61, 66], "F": [41, 48, 53, 57, 60, 65],
    ]

    struct Note { var beat: Double; var dur: Double; var midi: Int }

    public static func render(_ mood: MusicMood) -> MusicLoop {
        switch mood {
        case .day: return upbeat(transpose: 0, bpm: 112, whistle: true, seed: 1)
        case .finale: return upbeat(transpose: 2, bpm: 118, whistle: true, seed: 6, fuller: true)
        case .night: return night()
        case .search: return search()
        case .tense: return tense()
        case .quiet: return quiet()
        }
    }

    // MARK: Building blocks

    /// Renders guitar strums; each string keeps ringing until it is plucked again.
    static func strums(_ events: [(time: Double, chord: Chord, down: Bool, vel: Double)], total: Int, seed: UInt64, brightness: Double = 0.55, decay: Double = 0.996) -> [Float] {
        var out = [Float](repeating: 0, count: total)
        // Expand to per-string plucks.
        var plucks: [(t: Double, string: Int, midi: Int, vel: Double)] = []
        for e in events {
            let notes = e.down ? e.chord : Array(e.chord.suffix(4).reversed())
            for (k, m) in notes.enumerated() {
                let stringIdx = e.down ? k + (6 - e.chord.count) : 5 - k
                let spacing = e.down ? 0.009 : 0.007
                plucks.append((e.time + Double(k) * spacing, stringIdx, m, e.vel * (e.down ? 1 : 0.8) * (1 - Double(k) * 0.04)))
            }
        }
        plucks.sort { $0.t < $1.t }
        var seedN = seed
        for (i, p) in plucks.enumerated() {
            // Duration until the same string is plucked next.
            var end = p.t + 1.6
            for q in plucks[(i + 1)...] where q.string == p.string { end = q.t + 0.02; break }
            let dur = min(1.6, max(0.06, end - p.t))
            seedN = seedN &+ 7919
            var tone = DSP.pluck(freq: DSP.midi(p.midi), seconds: dur, decay: decay, brightness: brightness * (0.7 + 0.3 * p.vel), seed: seedN, gain: p.vel * 0.22)
            let fadeN = min(220, tone.count)
            for j in 0..<fadeN { tone[tone.count - 1 - j] *= Float(j) / Float(fadeN) }
            DSP.add(&out, tone, at: Int(p.t * DSP.sampleRate))
        }
        return out
    }

    static func bass(_ notes: [(time: Double, midi: Int, dur: Double)], total: Int, seed: UInt64) -> [Float] {
        var out = [Float](repeating: 0, count: total)
        for (k, n) in notes.enumerated() {
            let tone = DSP.pluck(freq: DSP.midi(n.midi), seconds: n.dur, decay: 0.998, brightness: 0.22, seed: seed &+ UInt64(k) &* 31, gain: 0.32)
            DSP.add(&out, tone, at: Int(n.time * DSP.sampleRate))
        }
        return out
    }

    /// Whistle: sine with portamento, vibrato and a breath of noise.
    static func whistle(_ notes: [Note], beat: Double, total: Int, gain: Double = 0.22, seed: UInt64) -> [Float] {
        var out = [Float](repeating: 0, count: total)
        var rng = RNG(seed: seed)
        var phase = 0.0
        var lastF = notes.first.map { DSP.midi($0.midi) } ?? 880
        for (k, n) in notes.enumerated() {
            let start = Int(n.beat * beat * DSP.sampleRate)
            let len = Int(n.dur * beat * DSP.sampleRate * 0.92)
            let target = DSP.midi(n.midi)
            let legato = k > 0 && abs(notes[k - 1].beat + notes[k - 1].dur - n.beat) < 0.01
            let startF = legato ? lastF : target
            for i in 0..<len where start + i < total {
                let t = Double(i) / DSP.sampleRate
                let glideT = min(1, t / 0.035)
                var f = startF + (target - startF) * glideT
                f *= 1 + 0.011 * sin(2 * .pi * 5.6 * t) * min(1, t / 0.12)
                phase += 2 * .pi * f / DSP.sampleRate
                let att = min(1, t / 0.03), rel = min(1, Double(len - i) / (0.06 * DSP.sampleRate))
                let breath = rng.double(-1, 1) * 0.04
                out[start + i] += Float((sin(phase) + breath) * gain * att * rel)
            }
            lastF = target
        }
        return out
    }

    static func box(_ times: [Double], total: Int, kick: Bool, seed: UInt64) -> [Float] {
        var out = [Float](repeating: 0, count: total)
        for (k, t) in times.enumerated() {
            if kick {
                DSP.add(&out, DSP.sine(freq: 68, seconds: 0.18, gain: 0.22, attack: 0.002, decay: 18), at: Int(t * DSP.sampleRate))
            } else {
                var n = DSP.filter(DSP.noise(seconds: 0.07, seed: seed &+ UInt64(k), gain: 0.12), .bandpass, freq: 1400, q: 0.9)
                DSP.expDecay(&n, attack: 0.001, decay: 45)
                DSP.add(&out, n, at: Int(t * DSP.sampleRate))
            }
        }
        return out
    }

    /// Mixes stems to stereo with pans, adds room, wraps the tail into the start for seamless looping.
    static func finish(_ stems: [([Float], Double, Float)], loopSamples: Int, bpm: Double, room: Float = 0.12) -> MusicLoop {
        let total = stems.map { $0.0.count }.max() ?? loopSamples
        var mono = [Float](repeating: 0, count: total)
        var panSum = [Float](repeating: 0, count: total)
        for (s, pan, g) in stems {
            for i in 0..<s.count { mono[i] += s[i] * g; panSum[i] += s[i] * g * Float(pan) }
        }
        var (L, R) = DSP.room(mono, mix: room)
        for i in 0..<total { L[i] -= panSum[i] * 0.5; R[i] += panSum[i] * 0.5 }
        // Wrap the tail (ringing notes, reverb) into the loop start.
        if total > loopSamples {
            for i in loopSamples..<total {
                let j = i - loopSamples
                if j < loopSamples { L[j] += L[i]; R[j] += R[i] }
            }
        }
        L = Array(L.prefix(loopSamples)); R = Array(R.prefix(loopSamples))
        DSP.softClip(&L); DSP.softClip(&R)
        let peak = max(L.reduce(0) { max($0, abs($1)) }, R.reduce(0) { max($0, abs($1)) })
        if peak > 0 { let k = 0.8 / peak; for i in 0..<L.count { L[i] *= k; R[i] *= k } }
        return MusicLoop(left: L, right: R, bpm: bpm)
    }

    // MARK: Moods

    static func upbeat(transpose: Int, bpm: Double, whistle doWhistle: Bool, seed: UInt64, fuller: Bool = false) -> MusicLoop {
        let beat = 60 / bpm
        let progA = transpose == 0 ? ["G", "Em", "C", "D", "G", "Em", "Am", "D"] : ["A", "F#m", "D", "E", "A", "F#m", "Bm", "E"]
        let progB = transpose == 0 ? ["C", "G", "Am", "Em", "C", "G", "D", "D"] : ["D", "A", "Bm", "F#m", "D", "A", "E", "E"]
        let prog = progA + progB
        let bars = prog.count
        let loopSamples = Int(Double(bars * 4) * beat * DSP.sampleRate)
        let total = loopSamples + Int(2.0 * DSP.sampleRate)
        // D - D U - U D U
        let pattern: [(Double, Bool, Double)] = [(0, true, 1.0), (1, true, 0.72), (1.5, false, 0.5), (2.5, false, 0.55), (3, true, 0.78), (3.5, false, 0.5)]
        var events: [(time: Double, chord: Chord, down: Bool, vel: Double)] = []
        var bassNotes: [(time: Double, midi: Int, dur: Double)] = []
        for (b, name) in prog.enumerated() {
            let chord = chords[name]!
            let barStart = Double(b * 4) * beat
            let last = b == bars - 1
            for (k, p) in pattern.enumerated() {
                if last && k > 2 { break }
                events.append((barStart + p.0 * beat, chord, p.1, p.2))
            }
            let root = chord[0] < 45 ? chord[0] : chord[0] - 12
            bassNotes.append((barStart, root, beat * 1.8))
            bassNotes.append((barStart + 2 * beat, root + 7, beat * 1.8))
        }
        let guitar = strums(events, total: total, seed: seed)
        let bassLine = bass(bassNotes, total: total, seed: seed &+ 99)
        var stems: [([Float], Double, Float)] = [(guitar, -0.35, 1.0), (bassLine, 0, 1.0)]
        var kicks: [Double] = [], snares: [Double] = []
        for b in 0..<bars { let s = Double(b * 4) * beat; kicks += [s, s + 2 * beat]; snares += [s + beat, s + 3 * beat] }
        stems.append((box(kicks, total: total, kick: true, seed: seed), 0, 0.8))
        stems.append((box(snares, total: total, kick: false, seed: seed &+ 5), 0.2, 0.9))
        if doWhistle {
            var melody: [Note] = []
            let a: [[(Double, Double, Int)]] = [
                [(0, 0.5, 79), (0.5, 0.5, 81), (1, 1, 83), (2.5, 0.5, 86), (3, 1, 83)],
                [(0.5, 0.5, 81), (1, 0.5, 79), (1.5, 1.5, 76), (3.5, 0.5, 79)],
                [(0, 1, 81), (1, 0.5, 83), (1.5, 0.5, 81), (2, 1.5, 79), (3.5, 0.5, 76)],
                [(0, 2, 78), (2.5, 0.5, 81), (3, 1, 74)],
                [(0, 0.5, 79), (0.5, 0.5, 81), (1, 1, 83), (2.5, 0.5, 86), (3, 0.5, 88), (3.5, 0.5, 86)],
                [(0, 1.5, 83), (1.5, 0.5, 81), (2, 2, 79)],
                [(0, 0.5, 81), (0.5, 0.5, 83), (1, 1, 84), (2, 0.5, 83), (2.5, 0.5, 81), (3, 1, 79)],
                [(0, 1, 78), (1, 1, 81), (2, 2, 79)],
                [(0, 1, 76), (1, 1, 79), (2, 2, 84)],
                [(0, 3, 83)],
                [(0, 1, 81), (1, 1, 79), (2, 2, 76)],
                [(0, 4, 79)],
                [(0, 1, 76), (1, 1, 79), (2, 1, 84), (3, 1, 86)],
                [(0, 2, 83), (2, 2, 86)],
                [(0, 1, 81), (1, 1, 78), (2, 2, 74)],
                [],
            ]
            for (b, bar) in a.enumerated() {
                for n in bar { melody.append(Note(beat: Double(b * 4) + n.0, dur: n.1, midi: n.2 + transpose)) }
            }
            stems.append((whistle(melody, beat: beat, total: total, seed: seed &+ 3), 0.35, 1.0))
            if fuller {
                let low = melody.map { Note(beat: $0.beat, dur: $0.dur, midi: $0.midi - 12) }
                stems.append((whistle(low, beat: beat, total: total, gain: 0.12, seed: seed &+ 4), -0.1, 1.0))
            }
        }
        return finish(stems, loopSamples: loopSamples, bpm: bpm)
    }

    static func night() -> MusicLoop {
        let bpm = 80.0, beat = 60 / bpm
        let prog = ["Em", "C", "G", "D", "Em", "C", "Am", "D"]
        let loopSamples = Int(Double(prog.count * 4) * beat * DSP.sampleRate)
        let total = loopSamples + Int(2.5 * DSP.sampleRate)
        var events: [(time: Double, chord: Chord, down: Bool, vel: Double)] = []
        let order = [0, 3, 4, 5, 4, 3, 4, 5]
        for (b, name) in prog.enumerated() {
            let ch = chords[name]!
            for (k, s) in order.enumerated() {
                let idx = min(ch.count - 1, max(0, s - (6 - ch.count)))
                events.append((Double(b * 4) * beat + Double(k) * beat * 0.5, [ch[idx]], true, k == 0 ? 0.6 : 0.38))
            }
        }
        let guitar = strums(events, total: total, seed: 21, brightness: 0.35, decay: 0.997)
        var hum: [Note] = []
        for (b, m) in [(1, 71), (3, 74), (5, 71), (7, 69)] { hum.append(Note(beat: Double(b * 4) + 1, dur: 3, midi: m)) }
        let soft = whistle(hum, beat: beat, total: total, gain: 0.07, seed: 22)
        return finish([(guitar, -0.2, 1.0), (soft, 0.3, 1.0)], loopSamples: loopSamples, bpm: bpm, room: 0.22)
    }

    static func search() -> MusicLoop {
        let bpm = 126.0, beat = 60 / bpm
        let bars = 8
        let loopSamples = Int(Double(bars * 4) * beat * DSP.sampleRate)
        let total = loopSamples + Int(1.0 * DSP.sampleRate)
        var out = [Float](repeating: 0, count: total)
        let riff = [40, 40, 47, 40, 40, 48, 40, 47]
        for b in 0..<bars {
            for k in 0..<8 {
                let t = Double(b * 4) * beat + Double(k) * beat * 0.5
                var m = riff[k]
                if b % 4 == 3 && k >= 6 { m = 46 }
                let tone = DSP.pluck(freq: DSP.midi(m), seconds: 0.16, decay: 0.97, brightness: 0.45, seed: UInt64(b * 8 + k + 300), gain: k % 4 == 0 ? 0.42 : 0.3)
                DSP.add(&out, tone, at: Int(t * DSP.sampleRate))
            }
        }
        var hats: [Double] = []
        for b in 0..<bars { for k in 0..<16 { hats.append(Double(b * 4) * beat + Double(k) * beat * 0.25) } }
        var hat = [Float](repeating: 0, count: total)
        for (k, t) in hats.enumerated() {
            var n = DSP.filter(DSP.noise(seconds: 0.03, seed: UInt64(k + 900), gain: k % 4 == 0 ? 0.1 : 0.05), .highpass, freq: 6000)
            DSP.expDecay(&n, attack: 0.0005, decay: 120)
            DSP.add(&hat, n, at: Int(t * DSP.sampleRate))
        }
        let kicks = (0..<bars * 2).map { Double($0 * 2) * beat }
        return finish([(out, -0.15, 1.0), (hat, 0.3, 1.0), (box(kicks, total: total, kick: true, seed: 33), 0, 1.0)], loopSamples: loopSamples, bpm: bpm, room: 0.08)
    }

    static func tense() -> MusicLoop {
        let bpm = 70.0, beat = 60 / bpm
        let bars = 8
        let loopSamples = Int(Double(bars * 4) * beat * DSP.sampleRate)
        let total = loopSamples + Int(2.0 * DSP.sampleRate)
        var drone = [Float](repeating: 0, count: total)
        for i in 0..<total {
            let t = Double(i) / DSP.sampleRate
            let trem = 0.6 + 0.4 * sin(2 * .pi * 0.25 * t)
            drone[i] = Float((sin(2 * .pi * 82.4 * t) * 0.5 + sin(2 * .pi * 123.5 * t) * 0.3) * trem * 0.12)
        }
        var plucks = [Float](repeating: 0, count: total)
        for (k, (bt, m)) in [(1.0, 53), (6.5, 52), (9.0, 53), (14.0, 47), (17.5, 53), (22.0, 52), (26.0, 50), (30.0, 47)].enumerated() {
            DSP.add(&plucks, DSP.pluck(freq: DSP.midi(m), seconds: 1.4, decay: 0.997, brightness: 0.3, seed: UInt64(400 + k), gain: 0.3), at: Int(bt * beat * DSP.sampleRate))
        }
        return finish([(drone, 0, 1.0), (plucks, -0.2, 1.0)], loopSamples: loopSamples, bpm: bpm, room: 0.25)
    }

    static func quiet() -> MusicLoop {
        let bpm = 66.0, beat = 60 / bpm
        let prog = ["Am", "F", "C", "G", "Am", "F", "C", "E"]
        let loopSamples = Int(Double(prog.count * 4) * beat * DSP.sampleRate)
        let total = loopSamples + Int(3.0 * DSP.sampleRate)
        var events: [(time: Double, chord: Chord, down: Bool, vel: Double)] = []
        for (b, name) in prog.enumerated() {
            let ch = chords[name]!
            for (k, idx) in [0, 2, 3, 4].enumerated() {
                events.append((Double(b * 4) * beat + Double(k) * beat, [ch[min(idx, ch.count - 1)]], true, 0.32))
            }
        }
        let g = strums(events, total: total, seed: 51, brightness: 0.28, decay: 0.998)
        return finish([(g, 0, 1.0)], loopSamples: loopSamples, bpm: bpm, room: 0.3)
    }
}
