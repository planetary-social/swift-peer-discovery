import Foundation
import Combine

///

public protocol Radar: ConnectablePublisher,
                       Cancellable,
                       Stateful,
                       CustomDebugStringConvertible

where Self.Output == Presence

{

    ///

    associatedtype Presence: PresenceInfo

}
