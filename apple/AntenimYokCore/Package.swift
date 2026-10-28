// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AntenimYokCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AntenimYokCore", targets: ["AntenimYokCore"]),
    ],
    targets: [
        .target(name: "AntenimYokCore"),
        .testTarget(name: "AntenimYokCoreTests", dependencies: ["AntenimYokCore"]),
    ],
    swiftLanguageModes: [.v6]
)
