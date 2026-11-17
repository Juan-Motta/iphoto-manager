// swift-tools-version: 6.2
import PackageDescription

// SwiftUI app (Liquid Glass). Composition root lives here. Requires Xcode 26+.
let package = Package(
    name: "PhotoManagerApp",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "PhotoManager", targets: ["PhotoManagerApp"])
    ],
    dependencies: [
        .package(name: "PhotoManager", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "PhotoManagerApp",
            dependencies: [
                .product(name: "PhotoManagerCore", package: "PhotoManager"),
                .product(name: "PhotoManagerAdapters", package: "PhotoManager"),
            ]
        )
    ]
)
