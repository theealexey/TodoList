import Foundation
import Synchronization

struct TodosAPI {

    private let session: URLSession
    private let operationQueue: OperationQueue
    
    init(
        session: URLSession = .shared,
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.session = session
        self.operationQueue = operationQueue

        operationQueue.qualityOfService = .userInitiated
    }

    func fetchTodos() async throws -> [TodoDTO] {
        guard let url = URL(
            string: "https://dummyjson.com/todos?limit=0"
        ) else {
            throw URLError(.badURL)
        }

        let request = URLRequest(
            url: url,
            timeoutInterval: 15
        )

        let submission = OperationSubmission()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (
                    continuation:
                        CheckedContinuation<[TodoDTO], Error>
                ) in

                let operation = TodosFetchOperation(
                    request: request,
                    session: session,
                    requiresSubmissionCommit: true
                ) { result in
                    continuation.resume(with: result)
                }

                submission.submit(
                    operation,
                    to: operationQueue
                )
            }
        } onCancel: {
            submission.cancel()
        }
    }
}

private final class OperationSubmission: Sendable {

    private enum State {
        case waiting
        case cancellationRequested
        case submitting(
            TodosFetchOperation,
            cancellationRequested: Bool
        )
        case submitted(TodosFetchOperation)
    }

    private enum SubmissionAction {
        case enqueue
        case cancel
        case none
    }

    private let state = Mutex(State.waiting)

    func submit(
        _ operation: TodosFetchOperation,
        to queue: OperationQueue
    ) {
        let action = state.withLock { state in
            switch state {
            case .waiting:
                state = .submitting(
                    operation,
                    cancellationRequested: false
                )
                return SubmissionAction.enqueue

            case .cancellationRequested:
                return SubmissionAction.cancel

            case .submitting, .submitted:
                return SubmissionAction.none
            }
        }

        switch action {
        case .enqueue:
            queue.addOperation(operation)

            let shouldCancel = state.withLock { state in
                guard case let .submitting(
                    submittedOperation,
                    cancellationRequested
                ) = state else {
                    return false
                }

                state = .submitted(submittedOperation)
                return cancellationRequested
            }

            if shouldCancel {
                operation.cancel()
            } else {
                operation.commitSubmission()
            }

        case .cancel:
            operation.cancel()

        case .none:
            break
        }
    }

    func cancel() {
        let operation: TodosFetchOperation? = state.withLock { state in
            switch state {
            case .waiting:
                state = .cancellationRequested
                return nil

            case .cancellationRequested:
                return nil

            case let .submitting(
                operation,
                cancellationRequested: _
            ):
                state = .submitting(
                    operation,
                    cancellationRequested: true
                )
                return nil

            case let .submitted(operation):
                return operation
            }
        }

        operation?.cancel()
    }
}
