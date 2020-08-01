import PeerDiscovery
import Network

/// ...
@available(OSX 10.15, *)
public class MulticastGroupNetworkPeerDiscoverySession : PeerDiscoverySession {

    /// ...
    public typealias Port = UInt16

    /// ...
    public typealias Host = String

    /// ...
    public var port: Port = 8008 // FIXME: Config

    /// ...
    public var host: Host = "224.0.0.1" // FIXME: Config

    /// ...
    public init(impersonating peer: Peer, at host: Host? = nil, on port: Port? = nil) {
        if let host = host { self.host = host }
        if let port = port { self.port = port }

        super.init(as: peer)
    }

}
