import Foundation

/// ...
public struct PeerPresence: RawRepresentable, CustomStringConvertible {
    
    public let rawValue: Data
    
    public init?(rawValue: Data) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        return String(data: self.rawValue, encoding: .utf8)! // XXX
    }
    
}
