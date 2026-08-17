import Dispatch
import Foundation
import Synchronization
import Testing
@testable import TodoList

@Suite
struct InitialTodoImporterTests {

    @Test
    func importsRemoteTodosIntoPersistentStorage() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"


        let stateStore = InitialTodoImportStateStore(
            namespace: suiteName
        )

        defer {
            stateStore.reset()
        }

        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "First imported task",
              "completed": false
            },
            {
              "id": 2,
              "todo": "Second imported task",
              "completed": true
            }
          ],
          "total": 2,
          "skip": 0,
          "limit": 0
        }
        """

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

            return (
                response,
                Data(json.utf8)
            )
        }

        let api = TodosAPI(
            session: session
        )

        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: try stack.loadedStoreIdentifier()
        )

        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        try await importer.run(
            importedAt: importedAt
        )

        let items = try await storage.fetchAll()

        #expect(items.count == 2)

        #expect(
            items.contains {
                $0.title == "First imported task"
                    && $0.details.isEmpty
                    && $0.createdAt == importedAt
                    && $0.status == .pending
            }
        )

        #expect(
            items.contains {
                $0.title == "Second imported task"
                    && $0.details.isEmpty
                    && $0.createdAt == importedAt
                    && $0.status == .completed
            }
        )
    }

    @Test
    func doesNotRequestTodosAfterSuccessfulImport() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"


        let stateStore = InitialTodoImportStateStore(
            namespace: suiteName
        )

        defer {
            stateStore.reset()
        }

        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Imported once",
              "completed": false
            }
          ]
        }
        """

        let firstSession = URLProtocolStub.makeSession { request in
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

            return (
                response,
                Data(json.utf8)
            )
        }

        let firstAPI = TodosAPI(
            session: firstSession
        )


        let firstImporter = InitialTodoImporter(
            api: firstAPI,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: try stack.loadedStoreIdentifier()
        )

        let firstImportedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        try await firstImporter.run(
            importedAt: firstImportedAt
        )

        let secondSession = URLProtocolStub.makeSession { _ in
            throw URLError(.badServerResponse)
        }

        let secondAPI = TodosAPI(
            session: secondSession
        )

        let secondImporter = InitialTodoImporter(
            api: secondAPI,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: try stack.loadedStoreIdentifier()
        )

        try await secondImporter.run(
            importedAt: Date(
                timeIntervalSince1970: 1_800_000_000
            )
        )

        let items = try await storage.fetchAll()
        let item = try #require(items.first)

        #expect(items.count == 1)
        #expect(item.title == "Imported once")
        #expect(item.createdAt == firstImportedAt)
    }

    @Test
    func retriesImportAfterNetworkFailure() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"


        let stateStore = InitialTodoImportStateStore(
            namespace: suiteName
        )

        defer {
            stateStore.reset()
        }

        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        let requestAttempt = Mutex(0)

        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Imported after retry",
              "completed": false
            }
          ]
        }
        """

        let session = URLProtocolStub.makeSession { request in
            let attempt = requestAttempt.withLock {
                $0 += 1
                return $0
            }

            if attempt == 1 {
                throw URLError(.notConnectedToInternet)
            }

            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }

            return (
                response,
                Data(json.utf8)
            )
        }

        defer {
            URLProtocolStub.invalidate(session)
        }

        let storeIdentifier = try stack
            .loadedStoreIdentifier()

        let importer = InitialTodoImporter(
            api: TodosAPI(session: session),
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: storeIdentifier
        )

        do {
            try await importer.run(
                importedAt: Date(
                    timeIntervalSince1970: 1_700_000_000
                )
            )

            Issue.record("Expected the network request to fail")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        }

        #expect(
            !stateStore.isCompleted(
                for: storeIdentifier
            )
        )

        let successfulImportDate = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        try await importer.run(
            importedAt: successfulImportDate
        )

        let items = try await storage.fetchAll()
        let item = try #require(items.first)

        #expect(requestAttempt.withLock { $0 } == 2)
        #expect(items.count == 1)
        #expect(item.title == "Imported after retry")
        #expect(item.createdAt == successfulImportDate)
        #expect(
            stateStore.isCompleted(
                for: storeIdentifier
            )
        )
    }

    @Test
    func concurrentRunsShareSingleInFlightImport() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"


        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        let requestCount = Mutex(0)
        let requestStarted = ImportEventProbe()
        let responseGate = BlockingResponseGate()

        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Imported once concurrently",
              "completed": false
            }
          ]
        }
        """

        let session = URLProtocolStub.makeSession { request in
            requestCount.withLock {
                $0 += 1
            }

            requestStarted.record()
            responseGate.waitUntilReleased()

            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }

            return (
                response,
                Data(json.utf8)
            )
        }

        defer {
            URLProtocolStub.invalidate(session)
        }

        let stateStore = InitialTodoImportStateStore(
            namespace: suiteName
        )

        defer {
            stateStore.reset()
        }

        let importer = InitialTodoImporter(
            api: TodosAPI(session: session),
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: try stack.loadedStoreIdentifier()
        )

        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let firstRun = Task {
            try await importer.run(
                importedAt: importedAt
            )
        }

        try #require(
            await requestStarted.waitForEvent()
        )

        let secondRunStarted = ImportEventProbe()

        let secondRun = Task {
            secondRunStarted.record()

            try await importer.run(
                importedAt: importedAt
            )
        }

        try #require(
            await secondRunStarted.waitForEvent()
        )

        for _ in 0..<20 {
            await Task.yield()
        }

        responseGate.release()
        responseGate.release()

        try await firstRun.value
        try await secondRun.value

        #expect(
            requestCount.withLock { $0 } == 1
        )

        let items = try await storage.fetchAll()
        #expect(items.count == 1)
    }

    @Test
    func importsAgainWhenPersistentStoreChanges() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"


        let stateStore = InitialTodoImportStateStore(
            namespace: suiteName
        )

        defer {
            stateStore.reset()
        }

        let firstStack = CoreDataStack(inMemory: true)
        try await firstStack.load()

        let firstIdentifier = try firstStack
            .loadedStoreIdentifier()

        let firstStorage = CoreDataTodoStorage(
            container: firstStack.container
        )

        let firstJSON = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "First store",
              "completed": false
            }
          ]
        }
        """

        let firstSession = URLProtocolStub.makeSession { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }

            return (
                response,
                Data(firstJSON.utf8)
            )
        }

        defer {
            URLProtocolStub.invalidate(firstSession)
        }

        let firstImporter = InitialTodoImporter(
            api: TodosAPI(session: firstSession),
            storage: firstStorage,
            stateStore: stateStore,
            storeIdentifier: firstIdentifier
        )

        try await firstImporter.run(
            importedAt: Date(
                timeIntervalSince1970: 1_700_000_000
            )
        )

        #expect(
            stateStore.isCompleted(
                for: firstIdentifier
            )
        )

        let secondStack = CoreDataStack(inMemory: true)
        try await secondStack.load()

        let secondIdentifier = try secondStack
            .loadedStoreIdentifier()

        #expect(firstIdentifier != secondIdentifier)
        #expect(
            !stateStore.isCompleted(
                for: secondIdentifier
            )
        )

        let secondStorage = CoreDataTodoStorage(
            container: secondStack.container
        )

        let secondJSON = """
        {
          "todos": [
            {
              "id": 2,
              "todo": "Second store",
              "completed": true
            }
          ]
        }
        """

        let secondSession = URLProtocolStub.makeSession { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }

            return (
                response,
                Data(secondJSON.utf8)
            )
        }

        defer {
            URLProtocolStub.invalidate(secondSession)
        }

        let secondImporter = InitialTodoImporter(
            api: TodosAPI(session: secondSession),
            storage: secondStorage,
            stateStore: stateStore,
            storeIdentifier: secondIdentifier
        )

        try await secondImporter.run(
            importedAt: Date(
                timeIntervalSince1970: 1_800_000_000
            )
        )

        let items = try await secondStorage.fetchAll()
        let item = try #require(items.first)

        #expect(items.count == 1)
        #expect(item.title == "Second store")
        #expect(item.status == .completed)
        #expect(
            stateStore.isCompleted(
                for: secondIdentifier
            )
        )
    }
}

private final class ImportEventProbe: Sendable {

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let pair = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func record() {
        continuation.yield(())
    }

    func waitForEvent() async -> Bool {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next() != nil
    }
}

private final class BlockingResponseGate: Sendable {

    private let semaphore = DispatchSemaphore(value: 0)

    func waitUntilReleased() {
        semaphore.wait()
    }

    func release() {
        semaphore.signal()
    }
}
