import Foundation
import Combine

///

extension MulticastGroupRadar: Cancellable {

    ///

    public func cancel() {
        statusUpdates.send(.cancelled)

        do { try channel?.close().wait() } catch (let error) {
            downstream.send(completion: .failure(.cannotCancelChannel(cause: error)))
            statusUpdates.send(.failed)
            return
        }

        channel = nil
        subcomponents.forEach { $0.cancel() }
        statusUpdates.send(completion: .finished)
        downstream.send(completion: .finished)
    }

}
