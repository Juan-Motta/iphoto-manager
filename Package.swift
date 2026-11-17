// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PhotoManager",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "PhotoManager", targets: ["PhotoManagerApp"])
    ],
    targets: [
        // Pure domain: models, selection rules, transfer use cases and ports. No Apple device frameworks.
        .target(name: "PhotoManagerCore"),
        // Driven adapters: ImageCaptureCore (iPhone) and the file system (Mac).
        .target(
            name: "PhotoManagerAdapters",
            dependencies: ["PhotoManagerCore"],
            linkerSettings: [.linkedFramework("ImageCaptureCore")]
        ),
        // SwiftUI app (Liquid Glass). Composition root lives here.
        .executableTarget(
            name: "PhotoManagerApp",
            dependencies: ["PhotoManagerCore", "PhotoManagerAdapters"]
        ),
        .testTarget(name: "PhotoManagerCoreTests", dependencies: ["PhotoManagerCore"]),
        .testTarget(name: "PhotoManagerAdaptersTests", dependencies: ["PhotoManagerAdapters"]),
    ]
)
