// swift-tools-version:5.9
import PackageDescription

// Linux-only type-check harness: compiles the real iOS app sources (iOS/FPod) plus the
// core against hand-written stubs of the exact UIKit/SpriteKit/AVFoundation API subset
// they use. It catches typos and type errors without Xcode; it does NOT replace an
// iOS build (stub signatures mirror Apple's but are not the SDK).
let package = Package(
    name: "IOSTypecheck",
    targets: [
        .target(name: "UIKit", path: "Stubs/UIKit"),
        .target(name: "SpriteKit", dependencies: ["UIKit"], path: "Stubs/SpriteKit"),
        .target(name: "AVFoundation", path: "Stubs/AVFoundation"),
        .executableTarget(name: "FPodApp", dependencies: ["UIKit", "SpriteKit", "AVFoundation"], path: "App",
                          exclude: ["iOS/Info.plist", "iOS/Assets.xcassets"]),
    ]
)
