// swift-tools-version:5.1

import PackageDescription

let package = Package(
    // TODO: What are the supported platforms?
    name: "swift-peer-discovery",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "PeerDiscovery",
            targets: ["PeerDiscovery"]),
        .library(
            name: "LocalNetworkNeighbours",
            targets: ["LocalNetworkNeighbours"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/apple/swift-log", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-metrics", .upToNextMajor(from: "2.0.0")),
    ],
    targets: [
        .target(
            name: "PeerDiscovery",
            dependencies: []),
        .target(
            name: "LocalNetworkNeighbours",
            dependencies: [
                "PeerDiscovery",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
            ]),
        .testTarget(
            name: "PeerDiscoveryTests",
            dependencies: ["PeerDiscovery"]),
        .testTarget(
            name: "LocalNetworkNeighboursTests",
            dependencies: [
                "PeerDiscovery",
                "LocalNetworkNeighbours",
            ]),
    ]
)
