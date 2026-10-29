// swift-tools-version:5.7
// Focus Tube — client YouTube minimaliste orienté apprentissage.
// Ce package s'ouvre directement dans Xcode (File > Open > Package.swift).

import PackageDescription

let package = Package(
    name: "FocusTube",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FocusTube", targets: ["FocusTube"])
    ],
    targets: [
        .executableTarget(
            name: "FocusTube",
            path: "Sources/FocusTube"
        )
    ]
)
