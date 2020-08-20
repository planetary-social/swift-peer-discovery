import PeerDiscovery
import Foundation
import Combine
import Logging
import Metrics
import NIO

/// ...

public final class MulticastPresenceBroadcast: ChannelOutboundHandler, Cancellable {

    /// ...

    public static let debugLabel = "social.planetary.peer-discovery.MulticastPresenceBroadcast"
    
    /// ...

    public static var logger = Logger(label: debugLabel)
    
    /// ...
    
    public static var suggestedMaxMalfunctionsAllowed = 60 // XXX
    
    /// ...
    
    public enum State: Comparable, CaseIterable {
        
        /// ...
        
        case idle, started, ready, suspended, cancelled, failed
         
        /// ...
        
        public func allowsTrigger(of event: StrictEvent) -> Bool {
            switch event {
            case .start   : return self == .idle
            case .suspend : return self == .ready
            case .resume  : return [.started, .ready].contains(self)
            }
        }
        
    }
    
    /// ...
    
    public enum StrictEvent: Equatable {
        
        case start, suspend, resume
        
    }
    
    /// ...
    
    public enum Failure: Error {
        
        case alreadyRunning
        case missingChannel
        case cannotSuspendNotRunning
        case cannotResumeInCurrentState
        case cannotAnnouncePresenceWhenNotReady

    }

    
    /// ...
    
    public let metrics = (
        attemptedAnnouncements: Counter(label: "\(debugLabel).attemptedAnnouncements"),
        confirmedAnnouncements: Counter(label: "\(debugLabel).confirmedAnnouncements")
    )
    
    /// ...
    public typealias OutboundIn = Bool
    
    /// ...
    
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    /// ...
    
    public let presence: PeerPresence
    
    /// ...

    public let remote, local: SocketAddress

    /// ...
    
    public static var defaultLocalHost = try! SocketAddress(ipAddress: "0.0.0.0", port: 0)
    
    /// ...
    
    public var pingInterval: TimeInterval
    
    /// ...
    
    public var status: AnyPublisher<State, Never> { return statusUpdates.eraseToAnyPublisher() }
    
    /// ...
    
    private var lastRecordedStatus: State = .idle
    
    /// ...
    
    private var statusUpdates = CurrentValueSubject<State, Never>(.idle)
    
    /// ...
    
    public static var suggestedPingInterval: TimeInterval = 1
    
    /// ...
    
    private var envelope: AddressedEnvelope<ByteBuffer>

    /// ...
    
    private var timer: Foundation.Timer?
            
    /// ...
    
    private var channel: Channel?
    
    /// ...

    public var malfunctions: AnyPublisher<Error, Never> {
        return malfunctionReports.eraseToAnyPublisher()
    }
    
    /// ...
    
    private var malfunctionsCount: Int {
        didSet {
            if malfunctionsCount > maxMalfunctionsAllowed {
                statusUpdates.send(.failed)
                cancel()
            }
        }
    }
    
    /// ...
    
    public var maxMalfunctionsAllowed: Int
        
    /// ...

    private var malfunctionReports = PassthroughSubject<Error, Never>()


    /// ...
    
    private var subcomponents: [Cancellable] = []
    
    /// ...
    
    public init(announcing presence: PeerPresence,
                via remote: SocketAddress,
                from local: SocketAddress? = nil,
                withPingInterval pingInterval: TimeInterval? = nil) {
        self.presence = presence
        self.remote = remote
        self.local = local ?? Self.defaultLocalHost
        self.envelope = AddressedEnvelope(remoteAddress: remote, data: ByteBuffer(bytes: presence.rawValue))
        self.pingInterval = pingInterval ?? Self.suggestedPingInterval
        self.maxMalfunctionsAllowed = Self.suggestedMaxMalfunctionsAllowed
        self.malfunctionsCount = 0

        self.subcomponents.append(contentsOf: [
            malfunctionReports.count().assign(to: \.malfunctionsCount, on: self),
            statusUpdates.assign(to: \.lastRecordedStatus, on: self),
            malfunctionLogging,
            statusLogging,
        ])
    }
    
    /// ...
    
    private var statusLogging: Cancellable {
        return status.sink { latestStatus in
            Self.logger.trace("status update: \(latestStatus) ")
        }
    }
    
    /// ...
    
    private var malfunctionLogging: Cancellable {
        return malfunctions.sink { error in
            Self.logger.warning("malfunction: \(error)")
        }
    }
                
    /// ...
    
    public func start(on group: EventLoopGroup) throws {
        guard lastRecordedStatus.allowsTrigger(of: .start) else { throw Failure.alreadyRunning }
        
        statusUpdates.send(.started)

        let bootstrap =
            DatagramBootstrap(group: group)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in return channel.pipeline.addHandlers(self) }

        self.channel = try bootstrap.bind(to: local).wait()
        
        try resume()
    }
        
    /// ...
    
    public func suspend() throws {
        guard lastRecordedStatus.allowsTrigger(of: .suspend) else { throw Failure.cannotSuspendNotRunning }

        statusUpdates.send(.suspended)
        timer?.invalidate()
        timer = nil
    }

    
    /// ...
    
    public func resume(withPingInterval pingInterval: TimeInterval? = nil) throws {
        guard lastRecordedStatus.allowsTrigger(of: .resume) else { throw Failure.cannotResumeInCurrentState }
        guard let channel = self.channel else { throw Failure.missingChannel }
        guard timer == nil else { throw Failure.alreadyRunning }
        
        statusUpdates.send(.ready)
        
        timer = .scheduledTimer(withTimeInterval: pingInterval ?? self.pingInterval, repeats: true) { _ in
            // FIXME: would be better to log in response to attempt counter increment...
            Self.logger.trace("announcing presence")
            self.metrics.attemptedAnnouncements.increment()

            guard
                self.lastRecordedStatus == .ready,
                channel.isActive
            else {
                self.malfunctionReports.send(Failure.cannotAnnouncePresenceWhenNotReady)
                return
            }
            
            channel.writeAndFlush(self.envelope).whenComplete { result in
                switch result {
                case .success:
                    Self.logger.trace("presence announcement sent")
                    self.metrics.confirmedAnnouncements.increment()
                case .failure(let error):
                    self.malfunctionReports.send(error)
                }
            }
        }
    }
    
    /// ...
    
    public func cancel() {
        do { try suspend() } catch (let error) {
            malfunctionReports.send(error)
        }
        
        statusUpdates.send(.cancelled)
        statusUpdates.send(completion: .finished)
        
        do { try channel?.close().wait() } catch (let error) {
            malfunctionReports.send(error)
        }

        channel = nil
        subcomponents.forEach { $0.cancel() }
        malfunctionReports.send(completion: .finished)
    }
    
    /// ...

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        Self.logger.trace("writing outbound announcement datagram")
        context.write(self.wrapOutboundOut(self.envelope), promise: promise)
    }
    
}
