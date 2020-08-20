import Combine

public class PeerDiscoverySession: Publisher, Cancellable {

    public typealias Output = PeerPresence
    
    public enum Failure: Error {
        
        case radarFailure(cause: Error)
        
    }
        
    private var downstream: AnyPublisher<Output, Failure>
    
    private var downstreamSubject = PassthroughSubject<Output, Failure>()
    
    public typealias Radar = AnyPublisher<Output, Error>
    
    public var subcomponents: [Cancellable] = []
    
    public init(radars: [Radar]) {
        downstream =
            radars.reduce(downstreamSubject.eraseToAnyPublisher()) { downstream, radar in
                return downstream.merge(with: radar.mapError(Failure.radarFailure)).eraseToAnyPublisher()
            }
        
        subcomponents.append(contentsOf: radars.map { $0 as! Cancellable })
    }
    
    deinit {
        cancel()
        downstreamSubject.send(completion: .finished)
    }
    
    public func receive<S>(subscriber: S)
    where S :Subscriber, Failure == S.Failure, Output == S.Input {
        self.downstream.receive(subscriber: subscriber)
    }
    
    public func cancel() {
        subcomponents.forEach { service in service.cancel() }
    }

}
