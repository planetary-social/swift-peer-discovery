import PeerDiscovery
import Foundation
import Combine
import NIO
import XCTest

@testable import LocalNetworkNeighbours

@available(OSX 10.16, *)
final class DiscoverableMulticastGroupTests: XCTestCase {

    override func setUp() {
        MulticastGroupRadar.logger.logLevel = .trace
        MulticastPresenceBroadcast.logger.logLevel = .trace
    }
    
    func testExample() {
        let port = 8008
        let localHost = try! SocketAddress(ipAddress: "0.0.0.0", port: port)
        let multicastGroupHost = try! SocketAddress(ipAddress: "224.0.0.1", port: port)
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

        let expectedDiscoveryFinish = expectation(description: "expected to discover peers")

        let radar = MulticastGroupRadar(at: multicastGroupHost, from: localHost, in: eventLoopGroup)
        let discovery =
            radar
            .autoconnect()
            .assertNoFailure()
            .timeout(10, scheduler: DispatchQueue.global(qos: .background))
            .collect()
            .sink { detectedAnnouncements in
                XCTAssertEqual(detectedAnnouncements.count, 7)
                expectedDiscoveryFinish.fulfill()
            }

        let rawAnnouncement = "net:127.0.0.1:8008~shs:a0jDvmGAU5ZggpHWICUpBWxcM2LnM380krrqdShmGbs="
        let presence = PeerPresence(rawValue: rawAnnouncement.data(using: .utf8)!)!
        let announcements = MulticastPresenceBroadcast(announcing: presence, via: multicastGroupHost)
        
        let expectedCorrectStatusesCollection = expectation(description: "expected statuses to be in correct order")
        let statusesCheck = announcements.status.collect().sink { statuses in
            XCTAssertEqual(statuses, [.idle, .started, .ready, .suspended, .cancelled])
            expectedCorrectStatusesCollection.fulfill()
        }

        let expectedNoMalfunctions = expectation(description: "expected no malfunctions")
        let noMalfunctionsCheck = announcements.malfunctions.count().sink { totalErrors in
            XCTAssertEqual(totalErrors, 0)
            expectedNoMalfunctions.fulfill()
        }
        
        try! announcements.start(on: eventLoopGroup)

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            radar.cancel()
            discovery.cancel()
            announcements.cancel()
            statusesCheck.cancel()
            noMalfunctionsCheck.cancel()
            try! eventLoopGroup.syncShutdownGracefully()
        }

        waitForExpectations(timeout: 20, handler: nil)
    }
    
}
