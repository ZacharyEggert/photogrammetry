// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Photogrammetry",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Photogrammetry", path: "Sources/Photogrammetry")]
)
