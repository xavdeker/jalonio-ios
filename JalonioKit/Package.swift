// swift-tools-version: 5.10
// SPDX-License-Identifier: EUPL-1.2

import PackageDescription

/// Cœur de l'application iOS : modèles de l'API, adresse de l'espace, jetons mobiles
/// (ADR-0029 du dépôt `jalonio`) et client HTTP. Sans interface : testé par `swift test`.
let package = Package(
    name: "JalonioKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "JalonioKit", targets: ["JalonioKit"]),
    ],
    targets: [
        .target(name: "JalonioKit"),
        .testTarget(
            name: "JalonioKitTests",
            dependencies: ["JalonioKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
