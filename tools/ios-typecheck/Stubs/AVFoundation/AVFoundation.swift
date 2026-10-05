// Type-check stub of the AVFoundation API subset used by iOS/FPod. Never shipped.
@_exported import Foundation

public typealias AVAudioFrameCount = UInt32
public typealias AVAudioChannelCount = UInt32

open class AVAudioTime {}

open class AVAudioFormat {
    public init?(standardFormatWithSampleRate sampleRate: Double, channels: AVAudioChannelCount) {}
    open var channelCount: AVAudioChannelCount { 1 }
}

open class AVAudioPCMBuffer {
    public init?(pcmFormat format: AVAudioFormat, frameCapacity: AVAudioFrameCount) {}
    open var frameLength: AVAudioFrameCount = 0
    open var floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>? { nil }
}

open class AVAudioNode {}
open class AVAudioMixerNode: AVAudioNode {}

public struct AVAudioPlayerNodeBufferOptions: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let loops = AVAudioPlayerNodeBufferOptions(rawValue: 1)
    public static let interrupts = AVAudioPlayerNodeBufferOptions(rawValue: 2)
}

open class AVAudioPlayerNode: AVAudioNode {
    public override init() {}
    open var volume: Float = 1
    open var pan: Float = 0
    open var isPlaying: Bool { false }
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, options: AVAudioPlayerNodeBufferOptions = [],
                             completionHandler: (() -> Void)? = nil) {}
    open func play() {}
    open func stop() {}
}

open class AVAudioEngine {
    public init() {}
    open var mainMixerNode: AVAudioMixerNode { AVAudioMixerNode() }
    open var isRunning: Bool { false }
    open func attach(_ node: AVAudioNode) {}
    open func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) {}
    open func start() throws {}
}

open class AVAudioSession {
    public struct Category: Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let ambient = Category(rawValue: "AVAudioSessionCategoryAmbient")
    }
    public struct Mode: Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let `default` = Mode(rawValue: "AVAudioSessionModeDefault")
    }
    public struct CategoryOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mixWithOthers = CategoryOptions(rawValue: 1)
    }
    public static let interruptionNotification = Notification.Name("AVAudioSessionInterruptionNotification")
    public class func sharedInstance() -> AVAudioSession { AVAudioSession() }
    open func setCategory(_ category: Category, mode: Mode, options: CategoryOptions = []) throws {}
    open func setActive(_ active: Bool) throws {}
}
