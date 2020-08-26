import Foundation
import Combine

///

extension MulticastGroupRadar: Cancellable {

    ///

    public func cancel() {
        status.send(.cancelled)

        do { try channel?.close().wait() } catch (let error) {
            downstream.send(completion: .failure(.cannotCancelChannel(cause: error)))
            status.send(.failed)
            return
        }

        channel = nil
        subcomponents.forEach { $0.cancel() }
        status.send(completion: .finished)
        downstream.send(completion: .finished)
    }

}
