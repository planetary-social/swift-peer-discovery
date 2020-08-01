import Combine

/// ...
@available(OSX 10.15, *)
open class PeerDiscoverySession {
    
    /// The peer being announced and represented on the distributed network.
    public let impersonating: Peer

    /// Reporting presence of the peers happens via the discoveries.
    public let discoveries = PassthroughSubject<Peer, Never>() // TODO: Adjust failure.
                             .share()
                             .makeConnectable()
    
    /// Session may accept suggestions about peers.
    ///
    /// Accepting suggestions allows reliability feedback loop with subscribers of the `discoveries`.
    ///
    // TODO: Elaborate, or explain better! ^
    public let suggestions = PassthroughSubject<Peer, Never>() // TODO: Adjust failure type too.
    
    /// Create a peer-to-peer connectivity session.
    public init(as peer: Peer) {
        impersonating = peer
    }

}
