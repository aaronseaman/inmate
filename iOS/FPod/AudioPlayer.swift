import Foundation
import AVFoundation

/// Plays FPodCore's procedurally synthesized audio through AVAudioEngine.
/// Music crossfades between moods and ducks during distressing scenes.
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let musicNodes = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var musicLevels: [Float] = [0, 0]
    private var musicTargets: [Float] = [0, 0]
    private var activeMusic = 0
    private var currentMood: MusicMood?
    private var wantedMood: MusicMood = .day
    private var sfxNodes: [AVAudioPlayerNode] = []
    private var nextSfx = 0
    private let mono: AVAudioFormat
    private let stereo: AVAudioFormat
    private var sfxBuffers: [SFX: AVAudioPCMBuffer] = [:]
    private var mumbleBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var musicBuffers: [MusicMood: AVAudioPCMBuffer] = [:]
    private var rendering: Set<MusicMood> = []
    private var duck: Float = 1
    private var duckTarget: Float = 1
    private var running = false
    private var interruptionToken: NSObjectProtocol?
    private let queue = DispatchQueue(label: "fpod.audio", qos: .userInitiated)

    init() {
        mono = AVAudioFormat(standardFormatWithSampleRate: DSP.sampleRate, channels: 1)!
        stereo = AVAudioFormat(standardFormatWithSampleRate: DSP.sampleRate, channels: 2)!
    }

    func start(settings: Settings) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        for node in musicNodes {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: stereo)
            node.volume = 0
        }
        for _ in 0..<10 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: mono)
            sfxNodes.append(node)
        }
        startEngine()
        interruptionToken = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            self?.restartIfNeeded()
        }
        // Effects first (fast), then the day loop, then the rest on demand.
        queue.async { [weak self] in
            guard let self = self else { return }
            var built: [SFX: AVAudioPCMBuffer] = [:]
            for s in SFX.allCases {
                if let b = self.buffer(SFXBank.render(s), format: self.mono) { built[s] = b }
            }
            let ready = built
            DispatchQueue.main.async { self.sfxBuffers = ready }
            self.renderMusic(.day)
        }
    }

    private func startEngine() {
        do {
            try engine.start()
            running = true
        } catch {
            running = false
        }
    }

    func resume(settings: Settings) {
        restartIfNeeded()
    }

    private func restartIfNeeded() {
        if !engine.isRunning {
            startEngine()
            if running, let mood = currentMood, let buf = musicBuffers[mood] {
                let node = musicNodes[activeMusic]
                node.stop()
                node.scheduleBuffer(buf, at: nil, options: [.loops], completionHandler: nil)
                node.play()
            }
        }
    }

    private func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let data = b.floatChannelData else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        for i in 0..<Int(format.channelCount) {
            samples.withUnsafeBufferPointer { src in
                data[i].update(from: src.baseAddress!, count: samples.count)
            }
        }
        return b
    }

    private func stereoBuffer(_ loop: MusicLoop) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: AVAudioFrameCount(loop.left.count)),
              let data = b.floatChannelData else { return nil }
        b.frameLength = AVAudioFrameCount(loop.left.count)
        loop.left.withUnsafeBufferPointer { data[0].update(from: $0.baseAddress!, count: loop.left.count) }
        loop.right.withUnsafeBufferPointer { data[1].update(from: $0.baseAddress!, count: loop.right.count) }
        return b
    }

    private func renderMusic(_ mood: MusicMood) {
        let loop = MusicComposer.render(mood)
        let buf = stereoBuffer(loop)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rendering.remove(mood)
            if let b = buf { self.musicBuffers[mood] = b }
            // Keep memory bounded: day plus the two most recent moods.
            if self.musicBuffers.count > 3 {
                for k in self.musicBuffers.keys where k != .day && k != self.wantedMood && k != self.currentMood { self.musicBuffers[k] = nil }
            }
            if mood == self.wantedMood { self.switchMusic(to: mood) }
        }
    }

    private func switchMusic(to mood: MusicMood) {
        guard running, mood != currentMood else { return }
        guard let buf = musicBuffers[mood] else {
            if !rendering.contains(mood) {
                rendering.insert(mood)
                queue.async { [weak self] in self?.renderMusic(mood) }
            }
            return
        }
        let next = 1 - activeMusic
        let node = musicNodes[next]
        node.stop()
        node.scheduleBuffer(buf, at: nil, options: [.loops], completionHandler: nil)
        musicLevels[next] = 0
        node.volume = 0
        node.play()
        musicTargets[next] = 1
        musicTargets[activeMusic] = 0
        activeMusic = next
        currentMood = mood
    }

    func handle(_ c: AudioCommand, settings: Settings) {
        switch c {
        case .sfx(let s, let volume, let pan, _):
            guard let buf = sfxBuffers[s] else { return }
            play(buf, volume: Float(volume * settings.sfxVolume), pan: Float(pan))
        case .mumble(let pitch, let volume, let pan, let seed):
            let key = Int(pitch * 100) * 16 + (seed % 8)
            let buf: AVAudioPCMBuffer
            if let b = mumbleBuffers[key] { buf = b } else {
                guard let b = buffer(SFXBank.mumble(pitch: pitch, seed: seed % 8), format: mono) else { return }
                if mumbleBuffers.count > 120 { mumbleBuffers.removeAll() }
                mumbleBuffers[key] = b
                buf = b
            }
            play(buf, volume: Float(volume * settings.voiceVolume), pan: Float(pan))
        case .music(let mood):
            wantedMood = mood
            switchMusic(to: mood)
        case .duck(let level):
            duckTarget = Float(level)
        }
    }

    private func play(_ buf: AVAudioPCMBuffer, volume: Float, pan: Float) {
        guard running, volume > 0.01, !sfxNodes.isEmpty else { return }
        let node = sfxNodes[nextSfx]
        nextSfx = (nextSfx + 1) % sfxNodes.count
        node.stop()
        node.volume = min(1, volume)
        node.pan = max(-1, min(1, pan))
        node.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        node.play()
    }

    /// Fades music levels and ducking each frame.
    func update(dt: Double, settings: Settings) {
        let step = Float(dt / 1.2)
        duck += (duckTarget - duck) * min(1, Float(dt * 3))
        for i in 0..<2 {
            if musicLevels[i] < musicTargets[i] { musicLevels[i] = min(musicTargets[i], musicLevels[i] + step) } else { musicLevels[i] = max(musicTargets[i], musicLevels[i] - step) }
            musicNodes[i].volume = musicLevels[i] * Float(settings.musicVolume) * duck * 0.8
            if musicLevels[i] <= 0 && musicTargets[i] <= 0 && musicNodes[i].isPlaying && i != activeMusic { musicNodes[i].stop() }
        }
        if currentMood == nil, running, musicBuffers[wantedMood] != nil { switchMusic(to: wantedMood) }
    }
}
