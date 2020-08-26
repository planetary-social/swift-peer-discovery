import Combine

#warning("this thing probably deserves a separate library, but also does not :/ should be moved somewhere though")

///

public protocol Stateful {

    ///

    associatedtype State: Equatable & CustomStringConvertible // XXX: Not sure

    ///

    var statusUpdates: AnyPublisher<State, Never> { get }

}
