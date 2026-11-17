// swift-tools-version: 6.2
import PackageDescription

// Domain and adapters. The SwiftUI app lives in ./App (its own package) because it
// needs Xcode to build, while this package builds and tests with Command Line Tools only.

let package = Package(
    name: "PhotoManager",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "PhotoManagerCore", targets: ["PhotoManagerCore"]),
        .library(name: "PhotoManagerAdapters", targets: ["PhotoManagerAdapters"]),
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
        .testTarget(name: "PhotoManagerCoreTests", dependencies: ["PhotoManagerCore"]),
        .testTarget(name: "PhotoManagerAdaptersTests", dependencies: ["PhotoManagerAdapters"]),
    ]
)
