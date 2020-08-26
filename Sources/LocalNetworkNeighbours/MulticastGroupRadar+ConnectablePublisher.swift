import Combine

///

extension MulticastGroupRadar: ConnectablePublisher {

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
