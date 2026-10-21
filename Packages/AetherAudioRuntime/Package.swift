// swift-tools-version: 6.1
import PackageDescription

// Selecting traits in a manifest also works when Xcode's package UI cannot
// express an empty trait set. Radio needs neither object-audio decoder.
let package = Package(
    name: "AetherAudioRuntime",
    platforms: [.iOS(.v18)],
    products: [.library(name: "AetherAudioRuntime", targets: ["AetherAudioRuntime"])],
    dependencies: [
        .package(url: "https://github.com/superuser404notfound/AetherEngine", exact: "7.38.1", traits: [])
    ],
    targets: [
        .target(name: "AetherAudioRuntime", dependencies: [.product(name: "AetherEngine", package: "AetherEngine")])
    ]
)
