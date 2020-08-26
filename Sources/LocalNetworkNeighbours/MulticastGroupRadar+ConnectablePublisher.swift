import Combine
import NIO

///

extension MulticastGroupRadar: ConnectablePublisher {

    ///

    public typealias Output = PresenceDatagram

    ///

    public enum Failure: Error {

        case cannotJoinMulticastGroup(cause: Error)
        case cannotCancelChannel(cause: Error)
        case connectionError(cause: Error)

    }

    //

    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        logger.trace("got a subscription request")
        self.sharedDownstream.receive(subscriber: subscriber)
    }

    /// ...

    public func connect() -> Cancellable {

        guard lastRecordedStatus.allowsTransition(to: .starting) else {
            logger.warning("cannot connect when \(lastRecordedStatus)")
            return self
        }

        statusUpdates.send(.starting)

        do {
            self.channel =
                try DatagramBootstrap(group: group)
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .channelInitializer { channel in return channel.pipeline.addHandlers(self) }
                .bind(to: self.local)
                .flatMap { channel -> EventLoopFuture<Channel> in
                    let channel = channel as! MulticastChannel
                    self.statusUpdates.send(.joining(multicastGroup: self.remote))
                    return channel.joinGroup(self.remote).map { channel }
                }
                .flatMap { channel -> EventLoopFuture<MulticastChannel> in
                    let socketOptions = channel as! SocketOptionProvider

                    if case .v4(let addr) = self.local {
                        return socketOptions.setIPMulticastIF(addr.address.sin_addr).map {
                            self.statusUpdates.send(.listening(at: self.local))
                            return channel as! MulticastChannel
                        }
                    } else {
                        preconditionFailure("the only supported multicast addressing is IPv4, sorry...")
                    }
                }
                .wait() // XXX: Maybe should not wait here...
        } catch (let error) {
            statusUpdates.send(.failed)
            downstream.send(completion: .failure(.cannotJoinMulticastGroup(cause: error)))
        }

        return self
    }

}
