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

    internal static let debugLabel = "social.planetary.peer-discovery.MulticastGroupRadar"
    
    /// ...

    public var logger: Logger

    /// ...
    
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>

    /// ...
    
    internal var status = CurrentValueSubject<State, Never>(.idle)

    /// ...

    internal var lastRecordedStatus: State = .idle

    /// ...
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data

        guard
            let message = buffer.readString(length: buffer.readableBytes)?.data(using: .utf8),
            let detectedPresence = PresenceDatagram(rawValue: message)
        else {
            logger.warning("unable to read peer announcement")
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
    
    public init(at remote: SocketAddress, from local: SocketAddress?,
                in group: EventLoopGroup,
                loggingWith logger: Logger? = nil) {
        self.remote = remote
        self.local = local ?? Self.defaultLocalHost
        self.group = group
        self.sharedDownstream = downstream.share().eraseToAnyPublisher()
        self.logger = logger ?? Logger(label: Self.debugLabel)
        
        self.subcomponents.append(contentsOf: [
            status.assign(to: \.lastRecordedStatus, on: self),
            downstreamLogging,
            statusLogging,
        ])
    }
    
    /// ...
    
    private var statusLogging: Cancellable {
        return statusUpdates.sink { latestStatus in
            self.logger.trace("status update: \(latestStatus) ")
        }
    }

    
    private var downstreamLogging: Cancellable {
        return
            downstream
            .catch { error -> Empty<Output, Never> in
                self.logger.error("radar failed: \(error)")
                return Empty(completeImmediately: true)
            }
            .sink { detectedPresence in
                self.logger.trace("peer presence detected: \(detectedPresence)")
            }
    }
    
}
