import Foundation
import Combine

///

public protocol Radar: ConnectablePublisher,
                       Cancellable,
                       CustomDebugStringConvertible

where Self.Output == Presence

{

    ///

    associatedtype Presence: PresenceInfo

    ///

    associatedtype State: Equatable & CustomStringConvertible

}
