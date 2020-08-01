// swift-tools-version:5.1

import PackageDescription

let package = Package(
    // TODO: What are the supported platforms?
    name: "swift-peer-discovery",
    products: [
        .library(
            name: "PeerDiscovery",
            targets: ["PeerDiscovery"]),
    ],
    dependencies: [
        // TODO
    ],
    targets: [
        .target(
            name: "PeerDiscovery",
            dependencies: []),
        .testTarget(
            name: "PeerDiscoveryTests",
            dependencies: ["PeerDiscovery"]),
    ]
)
