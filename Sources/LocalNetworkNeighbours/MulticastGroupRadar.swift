import PeerDiscovery
import Foundation
import Combine
import Logging
import Metrics
import NIO

/// ...

/// - Note: Cannot be suspended, because there's no way to suspend a server from listening...

public class MulticastGroupRadar: ChannelInboundHandler {
    
    /// ...

    public static let debugLabel = "social.planetary.peer-discovery.MulticastGroupRadar"
    
    /// ...

    public static var logger = Logger(label: debugLabel)

    /// ...
    
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>

    /// ...
    
    public var status: AnyPublisher<State, Never> { return statusUpdates.eraseToAnyPublisher() }
    
    /// ...
    
    internal var lastRecordedStatus: State = .idle
    
    /// ...
    
    internal var statusUpdates = CurrentValueSubject<State, Never>(.idle)

    /// ...
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data

        guard
            let message = buffer.readString(length: buffer.readableBytes)?.data(using: .utf8),
            let detectedPresence = PresenceDatagram(rawValue: message)
        else {
            Self.logger.warning("unable to read peer announcement")
            return
        }

        downstream.send(detectedPresence)
    }
    
    /// ...
    
    internal let downstream = PassthroughSubject<Output, Failure>()
    internal var sharedDownstream: AnyPublisher<Output, Failure>
    
    /// ...
    
    public var remote, local: SocketAddress

    /// ...

    public static var defaultLocalHost = try! SocketAddress(ipAddress: "0.0.0.0", port: 0)
    
    /// ...
    
    internal var channel: MulticastChannel?
    
    /// ...
    
    internal var subcomponents: [Cancellable] = []
    
    /// ...
    
    internal var group: EventLoopGroup
    
    /// ...
    
    public init(at remote: SocketAddress, from local: SocketAddress?, in group: EventLoopGroup) {
        self.remote = remote
        self.local = local ?? Self.defaultLocalHost
        self.group = group
        self.sharedDownstream = downstream.share().eraseToAnyPublisher()
        
        self.subcomponents.append(contentsOf: [
            statusUpdates.assign(to: \.lastRecordedStatus, on: self),
            downstreamLogging,
            statusLogging,
        ])
    }
    
    /// ...
    
    private var statusLogging: Cancellable {
        return status.sink { latestStatus in
            Self.logger.trace("status update: \(latestStatus) ")
        }
    }

    
    private var downstreamLogging: Cancellable {
        return
            downstream
            .catch { error -> Empty<Output, Never> in
                Self.logger.error("radar failed: \(error)")
                return Empty(completeImmediately: true)
            }
            .sink { detectedPresence in
                Self.logger.trace("peer presence detected: \(detectedPresence)")
            }
    }
    
}
