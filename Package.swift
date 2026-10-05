// swift-tools-version:5.9
import PackageDescription

// FPodCore is the platform-independent game: simulation, content, UI layout,
// display lists and procedural audio. The iOS app (iOS/FPod.xcodeproj) compiles
// these same sources directly alongside the SpriteKit/UIKit layer in iOS/FPod.
let package = Package(
    name: "FPod",
    products: [
        .library(name: "FPodCore", targets: ["FPodCore"]),
        .executable(name: "fpod-tool", targets: ["FPodTool"]),
    ],
    targets: [
        .target(name: "FPodCore", path: "Sources/FPodCore"),
        .executableTarget(name: "FPodTool", dependencies: ["FPodCore"], path: "Sources/FPodTool"),
        .testTarget(name: "FPodCoreTests", dependencies: ["FPodCore"], path: "Tests/FPodCoreTests"),
    ]
)
