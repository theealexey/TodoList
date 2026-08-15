import Foundation

final class TodosFetchOperation: Operation, @unchecked Sendable {

    typealias Completion = @Sendable (
        Result<[TodoDTO], Error>
    ) -> Void

    typealias DataTaskCompletion = @Sendable (
        Data?,
        URLResponse?,
        Error?
    ) -> Void

    typealias DataTaskFactory = @Sendable (
        URLRequest,
        @escaping DataTaskCompletion
    ) -> URLSessionDataTask

    private enum Phase: Equatable {
        case ready
        case executing
        case finished
    }

    private enum StartAction {
        case begin
        case cancel
        case none
    }

    private enum SubmissionReadiness: Equatable {
        case pending
        case committing
        case committed
    }

    private enum CancellationForwarding: Equatable {
        case pending
        case forwarding
        case forwarded
    }

    // SAFETY: This final Operation subclass has one synchronization domain.
    // Request, task factory, and completion are immutable and Sendable.
    // All mutable lifecycle state and the URLSession task are accessed only
    // while holding stateLock. Lifecycle KVO transitions are atomic under the
    // recursive lock; readiness has one monotonic, lock-protected commit.
    // Reentrant lifecycle calls are gated by isTransitioning and cancellation
    // forwarding state, so they cannot commit a second terminal transition.
    // Result completion is emitted only after terminal state is reserved.
    private let stateLock = NSRecursiveLock()
    private var phase = Phase.ready
    private var submissionReadiness: SubmissionReadiness
    private var isTransitioning = false
    private var cancellationRequested = false
    private var cancellationForwarding = CancellationForwarding.pending
    private var dataTask: URLSessionDataTask?

    private let request: URLRequest
    private let dataTaskFactory: DataTaskFactory
    private let completion: Completion

    init(
        request: URLRequest,
        session: URLSession,
        requiresSubmissionCommit: Bool = false,
        dataTaskFactory: DataTaskFactory? = nil,
        completion: @escaping Completion
    ) {
        self.request = request
        submissionReadiness = requiresSubmissionCommit
            ? .pending
            : .committed
        self.dataTaskFactory = dataTaskFactory ?? { request, completion in
            session.dataTask(
                with: request,
                completionHandler: completion
            )
        }
        self.completion = completion
    }

    override var isReady: Bool {
        let isSubmissionCommitted = stateLock.withLock {
            submissionReadiness == .committed
        }

        return isSubmissionCommitted && super.isReady
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        stateLock.withLock {
            phase == .executing
        }
    }

    override var isFinished: Bool {
        stateLock.withLock {
            phase == .finished
        }
    }

    func commitSubmission() {
        let shouldCommit = stateLock.withLock {
            guard phase == .ready,
                  submissionReadiness == .pending else {
                return false
            }

            submissionReadiness = .committing
            return true
        }

        guard shouldCommit else {
            return
        }

        willChangeValue(forKey: "isReady")

        stateLock.withLock {
            if phase == .ready,
               submissionReadiness == .committing {
                submissionReadiness = .committed
            } else {
                submissionReadiness = .pending
            }
        }

        didChangeValue(forKey: "isReady")
    }

    override func start() {
        let action = stateLock.withLock {
            guard phase == .ready,
                  submissionReadiness == .committed,
                  !isTransitioning else {
                return StartAction.none
            }

            guard !cancellationRequested else {
                return StartAction.cancel
            }

            transitionLocked(to: .executing)

            if cancellationRequested {
                return StartAction.cancel
            }

            return StartAction.begin
        }

        switch action {
        case .cancel:
            finishOnce(
                with: .failure(CancellationError())
            )
            return

        case .none:
            return

        case .begin:
            break
        }

        let task = dataTaskFactory(request) { [self] data, response, error in
            finishOnce(
                with: makeResult(
                    data: data,
                    response: response,
                    error: error
                )
            )
        }

        let shouldCancel = stateLock.withLock {
            guard phase == .executing else {
                return true
            }

            dataTask = task
            return cancellationRequested
        }

        if shouldCancel {
            task.cancel()
        } else {
            task.resume()
        }
    }

    override func cancel() {
        let shouldForwardCancellation = stateLock.withLock {
            cancellationRequested = true

            guard cancellationForwarding == .pending else {
                return false
            }

            cancellationForwarding = .forwarding
            return true
        }

        guard shouldForwardCancellation else {
            return
        }

        super.cancel()

        let action: (
            task: URLSessionDataTask?,
            shouldFinish: Bool
        ) = stateLock.withLock {
            cancellationForwarding = .forwarded

            switch phase {
            case .ready:
                return (nil, true)

            case .executing:
                return (dataTask, false)

            case .finished:
                return (nil, false)
            }
        }

        action.task?.cancel()

        if action.shouldFinish {
            finishOnce(
                with: .failure(CancellationError())
            )
        }
    }

    private func makeResult(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> Result<[TodoDTO], Error> {
        if let error {
            return .failure(error)
        }

        guard let data,
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return .failure(URLError(.badServerResponse))
        }

        do {
            let responseDTO = try JSONDecoder().decode(
                TodosResponseDTO.self,
                from: data
            )

            return .success(responseDTO.todos)
        } catch {
            return .failure(error)
        }
    }

    private func finishOnce(
        with proposedResult: Result<[TodoDTO], Error>
    ) {
        let terminalResult: Result<[TodoDTO], Error>? =
            stateLock.withLock {
                guard !isTransitioning,
                      phase != .finished else {
                    return nil
                }

                let result: Result<[TodoDTO], Error>

                if cancellationRequested
                    || proposedResult.isCancellation {
                    result = .failure(CancellationError())
                } else {
                    result = proposedResult
                }

                dataTask = nil
                transitionLocked(to: .finished)
                return result
            }

        if let terminalResult {
            completion(terminalResult)
        }
    }

    private func transitionLocked(to newPhase: Phase) {
        isTransitioning = true
        defer {
            isTransitioning = false
        }

        let wasExecuting = phase == .executing
        let wasFinished = phase == .finished
        let willExecute = newPhase == .executing
        let willFinish = newPhase == .finished

        if wasExecuting != willExecute {
            willChangeValue(forKey: "isExecuting")
        }

        if wasFinished != willFinish {
            willChangeValue(forKey: "isFinished")
        }

        phase = newPhase

        if wasFinished != willFinish {
            didChangeValue(forKey: "isFinished")
        }

        if wasExecuting != willExecute {
            didChangeValue(forKey: "isExecuting")
        }
    }
}

private extension Result where Failure == Error {

    var isCancellation: Bool {
        guard case let .failure(error) = self else {
            return false
        }

        if error is CancellationError {
            return true
        }

        return (error as? URLError)?.code == .cancelled
    }
}
