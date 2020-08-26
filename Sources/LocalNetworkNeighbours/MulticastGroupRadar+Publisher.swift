import Combine

///

extension MulticastGroupRadar: Publisher {

    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        Self.logger.trace("got a subscription request")
        self.sharedDownstream.receive(subscriber: subscriber)
    }
    
}
