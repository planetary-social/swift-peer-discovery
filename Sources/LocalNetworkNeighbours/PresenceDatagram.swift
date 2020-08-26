import PeerDiscovery
import Foundation

/// ...

public struct PresenceDatagram: PresenceInfo {

    public let rawValue: Data

    public init?(rawValue: Data) {
        self.rawValue = rawValue
    }

    public var description: String {
        return String(data: self.rawValue, encoding: .utf8)! // XXX
    }

}
