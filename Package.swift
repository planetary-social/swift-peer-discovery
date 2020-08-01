// swift-tools-version:5.1

import PackageDescription

let package = Package(
    // TODO: What are the supported platforms?
    name: "swift-peer-discovery",
    products: [
        .library(
            name: "PeerDiscovery",
            targets: ["PeerDiscovery"]),
        .library(
            name: "NetServicePeerDiscovery",
            targets: ["NetServicePeerDiscovery"]),
        .library(
            name: "MulticastGroupNetworkPeerDiscovery",
            targets: ["MulticastGroupNetworkPeerDiscovery"]),
    ],
    dependencies: [
        // TODO
    ],
    targets: [
        .target(
            name: "PeerDiscovery",
            dependencies: []),
        .target(
            name: "NetServicePeerDiscovery",
            dependencies: ["PeerDiscovery"]),
        .target(
            name: "MulticastGroupNetworkPeerDiscovery",
            dependencies: ["PeerDiscovery"]),
        .testTarget(
            name: "PeerDiscoveryTests",
            dependencies: ["PeerDiscovery",
                           "NetServicePeerDiscovery",
                           "MulticastGroupNetworkPeerDiscovery"]),
    ]
)
