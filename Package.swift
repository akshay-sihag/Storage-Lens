// swift-tools-version: 5.9
// Storage Lens — By Eridyn
import PackageDescription
let package = Package(
    name: "StorageLens",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StorageLens", targets: ["StorageLens"])],
    targets: [.executableTarget(name: "StorageLens", path: "Sources", linkerSettings: [.linkedFramework("Cocoa"), .linkedFramework("SwiftUI"), .linkedFramework("Charts")])]
)
