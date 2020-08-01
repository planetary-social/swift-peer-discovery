/// ...
public class PeerToPeerSession {
    
    /// The peer being announced and represented on the distributed network.
    public let impersonating: Peer
    
    /// Create a peer-to-peer connectivity session.
    public init(as peer: Peer) {
        impersonating = peer
    }

}
