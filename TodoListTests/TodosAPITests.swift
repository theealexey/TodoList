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

        let api = TodosAPI(session: session)
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

        let api = TodosAPI(session: session)

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

        let api = TodosAPI(session: session)
        let receivedDecodingError: Bool

        do {
            _ = try await api.fetchTodos()
            receivedDecodingError = false
        } catch is DecodingError {
            receivedDecodingError = true
        } catch {
            Issue.record("Unexpected error type: \(error)")
            receivedDecodingError = false
        }

        #expect(receivedDecodingError)
    }

    @Test
    func fetchTodosPreservesTransportFailure() async throws {
        let session = URLProtocolStub.makeSession { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(session: session)

        do {
            _ = try await api.fetchTodos()
            Issue.record("Expected fetchTodos() to throw")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func alreadyCancelledCallerReturnsCancellation() async throws {
        let results = APIResultProbe()
        let session = URLProtocolStub.makeControlledSession(
            onStart: { _ in },
            onStop: {}
        )
        defer {
            URLProtocolStub.invalidate(session)
        }

        let api = TodosAPI(session: session)
        let task = Task<Void, Never> {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }

            await recordFetchResult(
                from: api,
                in: results
            )
        }
        defer {
            task.cancel()
        }

        let result = try #require(await results.next())

        expectCancellation(result)
        #expect(results.count == 1)
    }

    @Test
    func taskCancellationStopsInFlightRequest() async throws {
        let starts = EventProbe()
        let stops = EventProbe()
        let results = APIResultProbe()

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
            await recordFetchResult(
                from: api,
                in: results
            )
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
        #expect(results.count == 1)
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
            bufferingPolicy: .bufferingNewest(1)
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

private final class APIResultProbe: Sendable {

    typealias Value = Result<[TodoDTO], Error>

    private let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation
    private let resultCount = Mutex(0)

    var count: Int {
        resultCount.withLock { $0 }
    }

    init() {
        let pair = AsyncStream<Value>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
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

private func recordFetchResult(
    from api: TodosAPI,
    in probe: APIResultProbe
) async {
    do {
        probe.record(
            .success(try await api.fetchTodos())
        )
    } catch {
        probe.record(.failure(error))
    }
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
