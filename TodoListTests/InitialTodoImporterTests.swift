import Foundation
import Synchronization
import Testing
@testable import TodoList

@Suite
struct InitialTodoImporterTests {

    @Test
    func runImportsMappedRecordsAndMarksStoreCompleted() async throws {
        let todos = [
            TodoDTO(
                id: 1,
                todo: "First imported task",
                completed: false
            ),
            TodoDTO(
                id: 2,
                todo: "Second imported task",
                completed: true
            )
        ]
        let api = TodosFetcherStub(
            behaviors: [.success(todos)]
        )
        let storage = ImportStorageSpy()
        let stateStore = ImportStateStoreSpy()
        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: "store-a"
        )
        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        try await importer.run(importedAt: importedAt)

        #expect(await api.callCount() == 1)
        #expect(
            await storage.calls() == [
                ImportStorageSpy.Call(
                    records: [
                        TodoImportRecord(
                            remoteID: 1,
                            title: "First imported task",
                            isCompleted: false
                        ),
                        TodoImportRecord(
                            remoteID: 2,
                            title: "Second imported task",
                            isCompleted: true
                        )
                    ],
                    importedAt: importedAt
                )
            ]
        )
        #expect(stateStore.isCompleted(for: "store-a"))
    }

    @Test
    func completedStoreSkipsFetchAndImport() async throws {
        let api = TodosFetcherStub(
            behaviors: [.failure(ImporterTestError.failed)]
        )
        let storage = ImportStorageSpy()
        let stateStore = ImportStateStoreSpy(
            completedStoreIdentifier: "store-a"
        )
        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: "store-a"
        )

        try await importer.run(importedAt: Date())

        #expect(await api.callCount() == 0)
        #expect(await storage.calls().isEmpty)
    }

    @Test
    func failedImportDoesNotMarkCompletionAndSameImporterCanRetry() async throws {
        let api = TodosFetcherStub(
            behaviors: [
                .failure(ImporterTestError.failed),
                .success([
                    TodoDTO(
                        id: 1,
                        todo: "Imported after retry",
                        completed: false
                    )
                ])
            ]
        )
        let storage = ImportStorageSpy()
        let stateStore = ImportStateStoreSpy()
        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: "store-a"
        )

        do {
            try await importer.run(
                importedAt: Date(
                    timeIntervalSince1970: 1_700_000_000
                )
            )
            Issue.record("Expected import to fail")
        } catch {
            #expect(error is ImporterTestError)
        }

        #expect(!stateStore.isCompleted(for: "store-a"))

        let successfulImportDate = Date(
            timeIntervalSince1970: 1_800_000_000
        )
        try await importer.run(
            importedAt: successfulImportDate
        )

        #expect(await api.callCount() == 2)
        #expect(await storage.calls().count == 1)
        #expect(
            await storage.calls().first?.importedAt
                == successfulImportDate
        )
        #expect(stateStore.isCompleted(for: "store-a"))
    }

    @Test
    func concurrentRunsShareSingleInFlightImport() async throws {
        let api = ControlledTodosFetcher(
            todos: [
                TodoDTO(
                    id: 1,
                    todo: "Imported once",
                    completed: false
                )
            ]
        )
        let storage = ImportStorageSpy()
        let stateStore = ImportStateStoreSpy()
        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: "store-a"
        )
        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let firstRun = Task {
            try await importer.run(importedAt: importedAt)
        }

        await api.waitUntilStarted()

        let secondRun = Task {
            try await importer.run(importedAt: importedAt)
        }

        for _ in 0..<10 {
            await Task.yield()
        }

        await api.release()

        try await firstRun.value
        try await secondRun.value

        #expect(await api.callCount() == 1)
        #expect(await storage.calls().count == 1)
        #expect(stateStore.isCompleted(for: "store-a"))
    }

    @Test
    func differentPersistentStoreRunsImportAgain() async throws {
        let stateStore = ImportStateStoreSpy(
            completedStoreIdentifier: "store-a"
        )
        let api = TodosFetcherStub(
            behaviors: [
                .success([
                    TodoDTO(
                        id: 1,
                        todo: "Second store",
                        completed: false
                    )
                ])
            ]
        )
        let storage = ImportStorageSpy()
        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore,
            storeIdentifier: "store-b"
        )

        try await importer.run(importedAt: Date())

        #expect(await api.callCount() == 1)
        #expect(await storage.calls().count == 1)
        #expect(stateStore.isCompleted(for: "store-b"))
        #expect(!stateStore.isCompleted(for: "store-a"))
    }
}

private enum ImporterTestError: Error, Sendable {
    case failed
}

private actor TodosFetcherStub: TodosFetching {

    enum Behavior: Sendable {
        case success([TodoDTO])
        case failure(ImporterTestError)
    }

    private var behaviors: [Behavior]
    private var numberOfCalls = 0

    init(behaviors: [Behavior]) {
        self.behaviors = behaviors
    }

    func fetchTodos() async throws -> [TodoDTO] {
        numberOfCalls += 1

        guard !behaviors.isEmpty else {
            return []
        }

        let behavior = behaviors.removeFirst()

        switch behavior {
        case let .success(todos):
            return todos
        case let .failure(error):
            throw error
        }
    }

    func callCount() -> Int {
        numberOfCalls
    }
}

private actor ControlledTodosFetcher: TodosFetching {

    private let todos: [TodoDTO]
    private let startedStream: AsyncStream<Void>
    private let startedContinuation: AsyncStream<Void>.Continuation

    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var numberOfCalls = 0

    init(todos: [TodoDTO]) {
        self.todos = todos

        let pair = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        startedStream = pair.stream
        startedContinuation = pair.continuation
    }

    func fetchTodos() async throws -> [TodoDTO] {
        numberOfCalls += 1
        startedContinuation.yield(())

        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }

        return todos
    }

    func waitUntilStarted() async {
        var iterator = startedStream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func callCount() -> Int {
        numberOfCalls
    }
}

private actor ImportStorageSpy: TodoImportStoring {

    struct Call: Equatable, Sendable {
        let records: [TodoImportRecord]
        let importedAt: Date
    }

    private var receivedCalls: [Call] = []

    func importTodos(
        _ records: [TodoImportRecord],
        importedAt: Date
    ) async throws {
        receivedCalls.append(
            Call(
                records: records,
                importedAt: importedAt
            )
        )
    }

    func calls() -> [Call] {
        receivedCalls
    }
}

private final class ImportStateStoreSpy: InitialTodoImportStateStoring {

    private let completedStoreIdentifier: Mutex<String?>

    init(completedStoreIdentifier: String? = nil) {
        self.completedStoreIdentifier = Mutex(
            completedStoreIdentifier
        )
    }

    func isCompleted(for storeIdentifier: String) -> Bool {
        completedStoreIdentifier.withLock {
            $0 == storeIdentifier
        }
    }

    func markCompleted(for storeIdentifier: String) {
        completedStoreIdentifier.withLock {
            $0 = storeIdentifier
        }
    }
}
