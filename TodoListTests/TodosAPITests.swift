import Foundation
import Synchronization
import Testing
@testable import TodoList

@Suite(.timeLimit(.minutes(1)))
struct TodosAPITests {
    
    @Test
    func fetchTodosReturnsDecodedTodosForSuccessfulResponse() async throws {
        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Do something nice",
              "completed": false
            }
          ]
        }
        """

        let data = try #require(json.data(using: .utf8))

        let session = URLProtocolStub.makeSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            #expect(
                url.absoluteString
                    == "https://dummyjson.com/todos?limit=0"
            )

            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw URLError(.badServerResponse)
            }

            return (response, data)
        }
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(
            session: session
        )

        let todos = try await api.fetchTodos()

        #expect(todos.count == 1)

        let todo = try #require(todos.first)

        #expect(todo.id == 1)
        #expect(todo.todo == "Do something nice")
        #expect(todo.completed == false)
    }
    
    @Test
    func fetchTodosThrowsBadServerResponseForHTTP500() async throws {
        let session = URLProtocolStub.makeSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw URLError(.badServerResponse)
            }

            return (response, Data())
        }
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(
            session: session
        )

        do {
            _ = try await api.fetchTodos()
            Issue.record("Expected fetchTodos() to throw")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test
    func fetchTodosThrowsDecodingErrorForInvalidJSON() async throws {
        let invalidJSON = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Do something nice",
              "completed": "not-a-boolean"
            }
          ]
        }
        """

        let data = try #require(invalidJSON.data(using: .utf8))

        let session = URLProtocolStub.makeSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw URLError(.badServerResponse)
            }

            return (response, data)
        }
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(
            session: session
        )
        
        do {
            _ = try await api.fetchTodos()
            Issue.record("Expected fetchTodos() to throw DecodingError")
        } catch is DecodingError {
            // Ожидаемая ошибка.
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func cancellationBeforeSubmissionDoesNotStartRequest() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(session: session)

        let task = Task<Void, Never> {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }

            do {
                results.record(
                    .success(try await api.fetchTodos())
                )
            } catch {
                results.record(.failure(error))
            }
        }
        defer {
            task.cancel()
        }

        let result = try #require(await results.next())

        expectCancellation(result)
        #expect(starts.count == 0)
        #expect(stops.count == 0)
    }

    @Test
    func cancellationDuringQueueSubmissionDoesNotStartRequest() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(
            session: session,
            operationQueue: CancellationOnAddOperationQueue()
        )
        let task = Task<Void, Never> {
            do {
                results.record(
                    .success(try await api.fetchTodos())
                )
            } catch {
                results.record(.failure(error))
            }
        }
        defer {
            task.cancel()
        }

        let result = try #require(await results.next())

        expectCancellation(result)
        #expect(starts.count == 0)
        #expect(stops.count == 0)
    }

    @Test
    func taskCancellationPropagatesToInFlightURLSessionTask() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(session: session)
        let task = Task<Void, Never> {
            do {
                results.record(
                    .success(try await api.fetchTodos())
                )
            } catch {
                results.record(.failure(error))
            }
        }
        defer {
            task.cancel()
        }

        try #require(await starts.waitForEvent())
        task.cancel()
        try #require(await stops.waitForEvent())
        let result = try #require(await results.next())

        expectCancellation(result)
        #expect(starts.count == 1)
        #expect(stops.count == 1)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct TodosFetchOperationTests {

    @Test
    func cancellationDuringSubmissionCommitDoesNotStartRequest() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()
        let queueDrained = EventProbe()

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        try await confirmation(
            "Submission-commit cancellation completes exactly once",
            expectedCount: 1
        ) { completion in
            let operation = TodosFetchOperation(
                request: try makeTodosRequest(),
                session: session,
                requiresSubmissionCommit: true
            ) { result in
                completion()
                results.record(result)
            }

            let observation = operation.observe(
                \.isReady,
                options: [.prior]
            ) { observedOperation, change in
                guard change.isPrior else {
                    return
                }

                observedOperation.cancel()
            }
            defer {
                observation.invalidate()
            }

            let queue = OperationQueue()
            queue.addOperation(operation)
            queue.addBarrierBlock {
                queueDrained.record()
            }

            operation.commitSubmission()

            let result = try #require(await results.next())
            try #require(await queueDrained.waitForEvent())

            expectCancellation(result)
            #expect(starts.count == 0)
            #expect(stops.count == 0)
            #expect(results.count == 1)
            #expect(operation.isFinished)
            #expect(!operation.isExecuting)
        }
    }

    @Test
    func cancellationBeforeStartFinishesExactlyOnceWithoutRequest() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()
        let queueDrained = EventProbe()

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        try await confirmation(
            "Operation completes exactly once",
            expectedCount: 1
        ) { completion in
            let operation = TodosFetchOperation(
                request: try makeTodosRequest(),
                session: session
            ) { result in
                completion()
                results.record(result)
            }

            let queue = OperationQueue()
            queue.isSuspended = true
            queue.addOperation(operation)
            queue.addBarrierBlock {
                queueDrained.record()
            }

            operation.cancel()
            operation.cancel()

            let result = try #require(await results.next())
            queue.isSuspended = false
            try #require(await queueDrained.waitForEvent())

            expectCancellation(result)
            #expect(results.count == 1)
            #expect(starts.count == 0)
            #expect(stops.count == 0)
            #expect(operation.isFinished)
            #expect(!operation.isExecuting)
        }

    }

    @Test
    func cancellationDuringRequestWaitsForTransportCompletion() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        try await confirmation(
            "Operation completes exactly once",
            expectedCount: 1
        ) { completion in
            let operation = TodosFetchOperation(
                request: try makeTodosRequest(),
                session: session
            ) { result in
                completion()
                results.record(result)
            }

            let queue = OperationQueue()
            queue.addOperation(operation)

            try #require(await starts.waitForEvent())
            #expect(operation.isExecuting)

            operation.cancel()

            try #require(await stops.waitForEvent())
            let result = try #require(await results.next())

            operation.cancel()

            expectCancellation(result)
            #expect(starts.count == 1)
            #expect(stops.count == 1)
            #expect(results.count == 1)
            #expect(operation.isFinished)
            #expect(!operation.isExecuting)
        }

    }

    @Test
    func cancellationDuringTaskCreationDoesNotStartRequest() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()
        let operationStorage = Mutex<TodosFetchOperation?>(nil)
        defer {
            operationStorage.withLock {
                $0 = nil
            }
        }

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        try await confirmation(
            "Task-creation cancellation completes exactly once",
            expectedCount: 1
        ) { completion in
            let operation = TodosFetchOperation(
                request: try makeTodosRequest(),
                session: session,
                dataTaskFactory: { request, dataTaskCompletion in
                    let task = session.dataTask(
                        with: request,
                        completionHandler: dataTaskCompletion
                    )

                    let operation = operationStorage.withLock { $0 }
                    operation?.cancel()

                    return task
                }
            ) { result in
                completion()
                results.record(result)
            }

            operationStorage.withLock {
                $0 = operation
            }

            operation.start()
            let result = try #require(await results.next())

            operation.cancel()

            expectCancellation(result)
            #expect(starts.count == 0)
            #expect(stops.count == 0)
            #expect(results.count == 1)
            #expect(operation.isFinished)
            #expect(!operation.isExecuting)
        }
    }

    @Test
    func lateTransportCompletionAfterCancellationDoesNotCompleteTwice() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()
        let transportCompletion = Mutex<
            TodosFetchOperation.DataTaskCompletion?
        >(nil)

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        try await confirmation(
            "Late transport callback does not complete twice",
            expectedCount: 1
        ) { completion in
            let operation = TodosFetchOperation(
                request: try makeTodosRequest(),
                session: session,
                dataTaskFactory: { request, completion in
                    transportCompletion.withLock {
                        $0 = completion
                    }

                    return session.dataTask(with: request) { _, _, _ in }
                }
            ) { result in
                completion()
                results.record(result)
            }

            let queue = OperationQueue()
            queue.addOperation(operation)

            try #require(await starts.waitForEvent())
            operation.cancel()
            try #require(await stops.waitForEvent())

            let callback = try #require(
                transportCompletion.withLock { $0 }
            )
            let response = try makeSuccessfulResponse()
            let data = try makeSuccessfulTodosData()
            let shouldReenter = Mutex(true)
            let observation = operation.observe(
                \.isFinished,
                options: [.prior]
            ) { _, change in
                guard change.isPrior else {
                    return
                }

                let shouldInvokeCallback = shouldReenter.withLock { value in
                    guard value else {
                        return false
                    }

                    value = false
                    return true
                }

                if shouldInvokeCallback {
                    callback(data, response, nil)
                }
            }
            defer {
                observation.invalidate()
            }

            callback(data, response, nil)
            callback(data, response, nil)

            let result = try #require(await results.next())

            expectCancellation(result)
            #expect(starts.count == 1)
            #expect(stops.count == 1)
            #expect(results.count == 1)
            #expect(operation.isFinished)
            #expect(!operation.isExecuting)
        }
    }

    @Test
    func reentrantCancellationFromPriorKVOFinishesExactlyOnce() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = OperationResultProbe()
        let shouldCancel = Mutex(true)

        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in
                starts.record()
            },
            onStop: {
                stops.record()
            }
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        try await confirmation(
            "Prior KVO cancellation completes exactly once",
            expectedCount: 1
        ) { completion in
            let operation = TodosFetchOperation(
                request: try makeTodosRequest(),
                session: session
            ) { result in
                completion()
                results.record(result)
            }

            let observation = operation.observe(
                \.isExecuting,
                options: [.prior]
            ) { observedOperation, change in
                guard change.isPrior else {
                    return
                }

                let shouldCancelNow = shouldCancel.withLock { value in
                    guard value else {
                        return false
                    }

                    value = false
                    return true
                }

                if shouldCancelNow {
                    observedOperation.cancel()
                }
            }
            defer {
                observation.invalidate()
            }

            operation.start()
            let result = try #require(await results.next())

            expectCancellation(result)
            #expect(starts.count == 0)
            #expect(stops.count == 0)
            #expect(results.count == 1)
            #expect(operation.isFinished)
            #expect(!operation.isExecuting)
        }
    }

    @Test
    func cancellationDuringFinishedKVOCannotOverwriteChosenSuccess() async throws {
        let data = try makeSuccessfulTodosData()
        let results = OperationResultProbe()

        let session = URLProtocolStub.makeSession { _ in
            return (try makeSuccessfulResponse(), data)
        }
        defer {
            URLProtocolStub.invalidate(session)
        }

        try await confirmation(
            "Finished KVO cancellation does not overwrite terminal result",
            expectedCount: 1
        ) { completion in
            let operation = TodosFetchOperation(
                request: try makeTodosRequest(),
                session: session
            ) { result in
                completion()
                results.record(result)
            }

            let observation = operation.observe(
                \.isFinished,
                options: [.prior]
            ) { observedOperation, change in
                guard change.isPrior else {
                    return
                }

                observedOperation.cancel()
            }
            defer {
                observation.invalidate()
            }

            let queue = OperationQueue()
            queue.addOperation(operation)

            let result = try #require(await results.next())

            switch result {
            case .success(let todos):
                #expect(todos.count == 1)

            case .failure(let error):
                Issue.record("Expected success, received \(error)")
            }

            #expect(results.count == 1)
            #expect(operation.isFinished)
            #expect(!operation.isExecuting)
        }
    }
}

private final class EventProbe: Sendable {

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let eventCount = Mutex(0)

    var count: Int {
        eventCount.withLock { $0 }
    }

    init() {
        let pair = AsyncStream<Void>.makeStream(
            bufferingPolicy: .unbounded
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func record() {
        eventCount.withLock {
            $0 += 1
        }
        continuation.yield(())
    }

    func waitForEvent() async -> Bool {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next() != nil
    }
}

private final class OperationResultProbe: Sendable {

    typealias Value = Result<[TodoDTO], Error>

    private let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation
    private let resultCount = Mutex(0)

    var count: Int {
        resultCount.withLock { $0 }
    }

    init() {
        let pair = AsyncStream<Value>.makeStream(
            bufferingPolicy: .unbounded
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func record(_ result: Value) {
        resultCount.withLock {
            $0 += 1
        }
        continuation.yield(result)
    }

    func next() async -> Value? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }
}

private final class CancellationOnAddOperationQueue:
    OperationQueue,
    @unchecked Sendable {

    // SAFETY: This final test queue adds no mutable state. It only cancels the
    // current Swift Task synchronously before delegating to OperationQueue.
    override func addOperation(_ operation: Operation) {
        withUnsafeCurrentTask { currentTask in
            currentTask?.cancel()
        }

        super.addOperation(operation)
    }
}

private func makeTodosRequest() throws -> URLRequest {
    let url = try #require(
        URL(string: "https://dummyjson.com/todos?limit=0")
    )

    return URLRequest(url: url)
}

private func makeSuccessfulResponse() throws -> HTTPURLResponse {
    let url = try #require(
        URL(string: "https://dummyjson.com/todos?limit=0")
    )

    return try #require(
        HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
    )
}

private func makeSuccessfulTodosData() throws -> Data {
    let json = """
    {
      "todos": [
        {
          "id": 1,
          "todo": "Controlled response",
          "completed": false
        }
      ]
    }
    """

    return try #require(json.data(using: .utf8))
}

private func expectCancellation(
    _ result: Result<[TodoDTO], Error>
) {
    switch result {
    case .failure(let error):
        #expect(error is CancellationError)

    case .success:
        Issue.record("Expected cancellation, received success")
    }
}
