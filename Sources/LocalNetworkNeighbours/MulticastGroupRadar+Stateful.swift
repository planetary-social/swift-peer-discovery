import PeerDiscovery // FIXME: replace with wherever we will import Stateful from
import NIO

///

extension MulticastGroupRadar: Stateful {

    ///

    public enum State: Equatable, CustomStringConvertible {

        /// ...

        case idle, starting

        /// ...

        case joining(multicastGroup: SocketAddress)
        case listening(at: SocketAddress)

        /// ...

        case cancelled, failed

        //

        public var description: String {
            switch self {
            case .idle:
                return "idle"
            case .starting:
                return "establishing connection"
            case .joining(let remote):
                return "joining group at \(remote)"
            case .listening(let local):
                return "listening at \(local)"
            case .cancelled:
                return "cancelled"
            case .failed:
                return "failed"
            }
        }

        ///

        public func allowsTransition(to next: Self) -> Bool {
            switch next {
            case .starting:
                return [.idle, .cancelled, .failed].contains(self)
            case .joining(_):
                return self == .starting
            case .listening(_):
                if case .joining(_) = self { return false }
                fallthrough
            default:
                return true
            }
        }

    }

}
