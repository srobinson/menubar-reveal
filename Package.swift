// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MenuBarReveal",
    // The one place the minimum macOS is set; the Makefile reads it for the bundle's Info.plist.
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MenuBarReveal", dependencies: ["MenuBarRevealCore"]),
        // The logic that runs without the app: the shortcut, the hot key and the menu bar override.
        .target(name: "MenuBarRevealCore"),
        .testTarget(name: "MenuBarRevealCoreTests", dependencies: ["MenuBarRevealCore"]),
    ]
)
