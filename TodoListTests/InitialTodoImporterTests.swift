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
        let expectedRecords = [
            try TodoImportRecord(
                remoteID: 1,
                title: "First imported task",
                isCompleted: false
            ),
            try TodoImportRecord(
                remoteID: 2,
                title: "Second imported task",
                isCompleted: true
            )
        ]

        try await importer.run(importedAt: importedAt)

        #expect(await api.callCount() == 1)
        #expect(
            await storage.calls() == [
                ImportStorageSpy.Call(
                    records: expectedRecords,
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

    @Test(.timeLimit(.minutes(1)))
    func concurrentRunsShareSingleInFlightImport() async throws {
        let api = ControlledTodosFetcher(
            behaviors: [
                .success([
                    TodoDTO(
                        id: 1,
                        todo: "Imported once",
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
        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let firstRun = Task {
            try await importer.run(importedAt: importedAt)
        }

        await api.waitForCallCount(1)

        let secondRun = Task {
            try await importer.run(importedAt: importedAt)
        }

        await stateStore.waitForCheckCount(2)
        #expect(await api.callCount() == 1)

        await api.release()

        try await firstRun.value
        try await secondRun.value

        #expect(await api.callCount() == 1)
        #expect(await storage.calls().count == 1)
        #expect(stateStore.isCompleted(for: "store-a"))
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledFirstWaiterDoesNotCancelSharedImportForActiveWaiter() async throws {
        let api = ControlledTodosFetcher(
            behaviors: [
                .success([
                    TodoDTO(
                        id: 1,
                        todo: "Shared import",
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

        let firstRun = Task {
            try await importer.run(importedAt: Date())
        }

        await api.waitForCallCount(1)

        let secondRun = Task {
            try await importer.run(importedAt: Date())
        }

        await stateStore.waitForCheckCount(2)

        firstRun.cancel()
        let firstResult = await firstRun.result

        #expect(throws: CancellationError.self) {
            try firstResult.get()
        }
        #expect(await api.callCount() == 1)
        #expect(!stateStore.isCompleted(for: "store-a"))

        await api.release()
        try await secondRun.value

        #expect(await storage.calls().count == 1)
        #expect(stateStore.isCompleted(for: "store-a"))
    }

    @Test(.timeLimit(.minutes(1)))
    func sharedImportFailureIsDeliveredToActiveWaiterAndCanRetry() async throws {
        let api = ControlledTodosFetcher(
            behaviors: [
                .failure(ImporterTestError.failed),
                .success([
                    TodoDTO(
                        id: 1,
                        todo: "Imported after shared failure",
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

        let cancelledRun = Task {
            try await importer.run(importedAt: Date())
        }

        await api.waitForCallCount(1)

        let activeRun = Task {
            try await importer.run(importedAt: Date())
        }

        await stateStore.waitForCheckCount(2)

        cancelledRun.cancel()
        let cancelledResult = await cancelledRun.result

        #expect(throws: CancellationError.self) {
            try cancelledResult.get()
        }

        await api.release()
        let activeResult = await activeRun.result

        #expect(throws: ImporterTestError.self) {
            try activeResult.get()
        }
        #expect(!stateStore.isCompleted(for: "store-a"))
        #expect(await storage.calls().isEmpty)

        let retryRun = Task {
            try await importer.run(importedAt: Date())
        }

        await api.waitForCallCount(2)
        await api.release()
        try await retryRun.value

        #expect(await api.callCount() == 2)
        #expect(await storage.calls().count == 1)
        #expect(stateStore.isCompleted(for: "store-a"))
    }

    @Test(arguments: [0, -1])
    func nonPositiveRemoteIDDoesNotPersistOrCompleteImport(
        remoteID: Int
    ) async {
        let api = TodosFetcherStub(
            behaviors: [
                .success([
                    TodoDTO(
                        id: remoteID,
                        todo: "Invalid remote task",
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
            try await importer.run(importedAt: Date())
            Issue.record("Expected invalid remote ID error")
        } catch let error as TodoImportRecordError {
            #expect(error == .invalidRemoteID(remoteID))
        } catch {
            Issue.record("Received unexpected error: \(error)")
        }

        #expect(await api.callCount() == 1)
        #expect(await storage.calls().isEmpty)
        #expect(!stateStore.isCompleted(for: "store-a"))
    }

    @Test
    func emptyRemotePayloadCompletesImportWithoutStoredRecords() async throws {
        let api = TodosFetcherStub(
            behaviors: [.success([])]
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
        try await importer.run(importedAt: importedAt)

        #expect(await api.callCount() == 1)
        #expect(
            await storage.calls() == [
                ImportStorageSpy.Call(
                    records: [],
                    importedAt: importedAt
                )
            ]
        )
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

    enum Behavior: Sendable {
        case success([TodoDTO])
        case failure(ImporterTestError)
    }

    private struct StartWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var behaviors: [Behavior]
    private var numberOfCalls = 0
    private var startWaiters: [StartWaiter] = []
    private var releaseContinuation:
        CheckedContinuation<[TodoDTO], Error>?

    init(behaviors: [Behavior]) {
        self.behaviors = behaviors
    }

    func fetchTodos() async throws -> [TodoDTO] {
        numberOfCalls += 1
        resumeReadyStartWaiters()

        return try await withCheckedThrowingContinuation {
            continuation in
            releaseContinuation = continuation
        }
    }

    func waitForCallCount(_ expectedCount: Int) async {
        guard numberOfCalls < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            startWaiters.append(
                StartWaiter(
                    expectedCount: expectedCount,
                    continuation: continuation
                )
            )
        }
    }

    func release() {
        guard
            let continuation = releaseContinuation,
            !behaviors.isEmpty
        else {
            return
        }

        releaseContinuation = nil

        switch behaviors.removeFirst() {
        case let .success(todos):
            continuation.resume(returning: todos)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    func callCount() -> Int {
        numberOfCalls
    }

    private func resumeReadyStartWaiters() {
        let readyWaiters = startWaiters.filter {
            numberOfCalls >= $0.expectedCount
        }

        startWaiters.removeAll {
            numberOfCalls >= $0.expectedCount
        }

        readyWaiters.forEach {
            $0.continuation.resume()
        }
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
    private let checkCount = Mutex(0)
    private let checkStream: AsyncStream<Void>
    private let checkContinuation: AsyncStream<Void>.Continuation

    init(completedStoreIdentifier: String? = nil) {
        self.completedStoreIdentifier = Mutex(
            completedStoreIdentifier
        )

        let pair = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        checkStream = pair.stream
        checkContinuation = pair.continuation
    }

    func isCompleted(for storeIdentifier: String) -> Bool {
        checkCount.withLock {
            $0 += 1
        }
        checkContinuation.yield()

        return completedStoreIdentifier.withLock {
            $0 == storeIdentifier
        }
    }

    func markCompleted(for storeIdentifier: String) {
        completedStoreIdentifier.withLock {
            $0 = storeIdentifier
        }
    }

    func waitForCheckCount(_ expectedCount: Int) async {
        guard checkCount.withLock({ $0 }) < expectedCount else {
            return
        }

        var iterator = checkStream.makeAsyncIterator()

        while checkCount.withLock({ $0 }) < expectedCount {
            _ = await iterator.next()
        }
    }
}
