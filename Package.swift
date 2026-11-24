// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LiteStick", platforms: [.macOS(.v14)], products: [.executable(name: "LiteStick", targets: ["LiteStick"])], targets: [.executableTarget(name: "LiteStick", path: "Sources/LiteStick")])
