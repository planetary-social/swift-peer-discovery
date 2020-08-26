import PeerDiscovery
import Foundation
import Combine
import Logging
import Metrics
import NIO

/// ...

/// - Note: Cannot be suspended, because there's no way to suspend a server from listening...

public class MulticastGroupRadar: ChannelInboundHandler, ConnectablePublisher, Cancellable {
    
    /// ...

    public static let debugLabel = "social.planetary.peer-discovery.MulticastGroupRadar"
    
    /// ...

    public static var logger = Logger(label: debugLabel)

    /// ...
    
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    
    /// ...
    
    public enum State: Equatable {
        
        /// ...
        
        case idle, connecting
        
        /// ...
        
        case joining(multicastGroup: SocketAddress)
        case listening(at: SocketAddress)
        
        /// ...
        
        case cancelled, failed
        
    }

    /// ...
    
    public var status: AnyPublisher<State, Never> { return statusUpdates.eraseToAnyPublisher() }
    
    /// ...
    
    private var lastRecordedStatus: State = .idle
    
    /// ...
    
    private var statusUpdates = CurrentValueSubject<State, Never>(.idle)

    /// ...
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data

        guard
            let message = buffer.readString(length: buffer.readableBytes)?.data(using: .utf8),
            let detectedPresence = PeerPresence(rawValue: message)
        else {
            Self.logger.warning("unable to read peer announcement")
            return
        }

        downstream.send(detectedPresence)
    }
    
    /// ...
    
    public typealias Output = PeerPresence
    
    /// ...
    
    public enum Failure: Error {
        
        case cannotJoinMulticastGroup(cause: Error)
        case cannotCancelChannel(cause: Error)
        case connectionError(cause: Error)
        
    }

    /// ...
    
    private let downstream = PassthroughSubject<Output, Failure>()
    private var sharedDownstream: AnyPublisher<Output, Failure>
    
    /// ...
    
    public var remote, local: SocketAddress

    /// ...

    public static var defaultLocalHost = try! SocketAddress(ipAddress: "0.0.0.0", port: 0)
    
    /// ...
    
    internal var channel: MulticastChannel?
    
    /// ...
    
    private var subcomponents: [Cancellable] = []
    
    /// ...
    
    private var group: EventLoopGroup
    
    /// ...
    
    public init(at remote: SocketAddress, from local: SocketAddress?, using group: EventLoopGroup) {
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
            .catch { error -> Empty<PeerPresence, Never> in
                Self.logger.error("radar failed: \(error)")
                return Empty(completeImmediately: true)
            }
            .sink { detectedPresence in
                Self.logger.trace("peer presence detected: \(detectedPresence)")
            }
    }
    
    /// ...
    
    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        Self.logger.trace("got a subscription request")
        self.sharedDownstream.receive(subscriber: subscriber)
    }
    
    /// ...
    
    public func connect() -> Cancellable {
        
        switch lastRecordedStatus {
        case .connecting, .joining(_), .listening(_):
            Self.logger.trace("already requested connection")
            return self
        case .cancelled, .failed:
            Self.logger.error("cannot connect in terminal state")
            return self
        default:
            break // See below...
        }
        
        statusUpdates.send(.connecting)
        
        let bootstrap =
            DatagramBootstrap(group: group)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in return channel.pipeline.addHandlers(self) }
        
        do {
            self.channel =
                try
                bootstrap
                .bind(to: self.local)
                .flatMap { channel -> EventLoopFuture<Channel> in
                    let channel = channel as! MulticastChannel
                    self.statusUpdates.send(.joining(multicastGroup: self.remote))
                    return channel.joinGroup(self.remote).map { channel }
                }
                .flatMap { channel -> EventLoopFuture<MulticastChannel> in
                    let provider = channel as! SocketOptionProvider
                                        
                    //guard
                    //    let netInterface = try! System.enumerateInterfaces().first(where: \.multicastSupported)
                    //else {
                    //    preconditionFailure("Can't find a suitable interface!")
                    //}
                    
                    switch self.local {
                    case .v4(let addr):
                        return provider.setIPMulticastIF(addr.address.sin_addr).map {
                            self.statusUpdates.send(.listening(at: self.local))
                            return channel as! MulticastChannel
                        }
                    //case .v6:
                    //    return provider.setIPv6MulticastIF(CUnsignedInt(netInterface.interfaceIndex)).map {
                    //        return channel as! MulticastChannel
                    //    }
                    default:
                        preconditionFailure("Impossible!")
                    }
                }
                .wait() // XXX: Should not wait here...
        } catch (let error) {
            downstream.send(completion: .failure(.cannotJoinMulticastGroup(cause: error)))
            statusUpdates.send(.failed)
        }
        
        return self
    }

}
