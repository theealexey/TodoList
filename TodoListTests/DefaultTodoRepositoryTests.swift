import Foundation
import Testing
@testable import TodoList

@Suite
struct DefaultTodoRepositoryTests {

    private enum TestError: Error, Sendable {
        case failed
    }

    private actor ImporterStub: InitialTodoImporting {
        enum Behavior: Sendable {
            case succeed
            case fail
            case cancel
        }

        private let behavior: Behavior
        private var receivedDates: [Date] = []

        init(behavior: Behavior = .succeed) {
            self.behavior = behavior
        }

        func run(importedAt: Date) async throws {
            receivedDates.append(importedAt)

            switch behavior {
            case .succeed:
                return
            case .fail:
                throw TestError.failed
            case .cancel:
                throw CancellationError()
            }
        }

        func dates() -> [Date] {
            receivedDates
        }
    }

    private actor SuspendedImporter: InitialTodoImporting {
        private var didStart = false
        private var startContinuation:
            CheckedContinuation<Void, Never>?
        private var resultContinuation:
            CheckedContinuation<Void, Error>?

        func run(importedAt: Date) async throws {
            didStart = true
            startContinuation?.resume()
            startContinuation = nil

            try await withCheckedThrowingContinuation {
                continuation in
                resultContinuation = continuation
            }
        }

        func waitUntilStarted() async {
            guard !didStart else {
                return
            }

            await withCheckedContinuation { continuation in
                startContinuation = continuation
            }
        }

        func succeed() {
            resultContinuation?.resume()
            resultContinuation = nil
        }

        func fail() {
            resultContinuation?.resume(
                throwing: TestError.failed
            )
            resultContinuation = nil
        }
    }

    private actor StorageStub: TodoStoring {
        enum Failure: Sendable {
            case none
            case generic
            case cancel
            case notFound(UUID)
        }

        private let items: [TodoItem]
        private let fetchFailure: Failure
        private let createFailure: Failure
        private let updateFailure: Failure
        private let deleteFailure: Failure
        private var numberOfFetches = 0

        init(
            items: [TodoItem] = [],
            fetchFailure: Failure = .none,
            createFailure: Failure = .none,
            updateFailure: Failure = .none,
            deleteFailure: Failure = .none
        ) {
            self.items = items
            self.fetchFailure = fetchFailure
            self.createFailure = createFailure
            self.updateFailure = updateFailure
            self.deleteFailure = deleteFailure
        }

        func create(_ item: TodoItem) async throws {
            try throwIfNeeded(createFailure)
        }

        func update(_ item: TodoItem) async throws {
            try throwIfNeeded(updateFailure)
        }

        func delete(id: UUID) async throws {
            try throwIfNeeded(deleteFailure)
        }

        func fetchAll() async throws -> [TodoItem] {
            numberOfFetches += 1
            try throwIfNeeded(fetchFailure)
            return items
        }

        func fetchCallCount() -> Int {
            numberOfFetches
        }

        private func throwIfNeeded(_ failure: Failure) throws {
            switch failure {
            case .none:
                return
            case .generic:
                throw TestError.failed
            case .cancel:
                throw CancellationError()
            case let .notFound(id):
                throw TodoStorageError.todoNotFound(id: id)
            }
        }
    }

    @Test
    func loadTodosRunsImporterWithCurrentDateAndReturnsStoredItems() async throws {
        let importedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let expectedItems = [Self.makeItem()]
        let importer = ImporterStub()
        let storage = StorageStub(items: expectedItems)
        let repository = DefaultTodoRepository(
            importer: importer,
            storage: storage,
            currentDate: { importedAt }
        )

        let items = try await repository.loadTodos()

        #expect(items == expectedItems)
        #expect(await importer.dates() == [importedAt])
    }

    @Test
    func loadTodosMapsImportFailureToRepositoryError() async {
        let repository = DefaultTodoRepository(
            importer: ImporterStub(behavior: .fail),
            storage: StorageStub()
        )

        await #expect(throws: TodoRepositoryError.loadFailed) {
            _ = try await repository.loadTodos()
        }
    }

    @Test
    func loadTodosPreservesCancellation() async {
        let repository = DefaultTodoRepository(
            importer: ImporterStub(behavior: .cancel),
            storage: StorageStub()
        )

        await #expect(throws: CancellationError.self) {
            _ = try await repository.loadTodos()
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledLoadMapsLateImporterFailureToCancellation() async {
        let importer = SuspendedImporter()
        let repository = DefaultTodoRepository(
            importer: importer,
            storage: StorageStub()
        )

        let load = Task {
            try await repository.loadTodos()
        }

        await importer.waitUntilStarted()
        load.cancel()
        await importer.fail()

        let result = await load.result

        #expect(throws: CancellationError.self) {
            try result.get()
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledLoadDoesNotFetchAfterImporterCompletes() async {
        let importer = SuspendedImporter()
        let storage = StorageStub()
        let repository = DefaultTodoRepository(
            importer: importer,
            storage: storage
        )

        let load = Task {
            try await repository.loadTodos()
        }

        await importer.waitUntilStarted()
        load.cancel()
        await importer.succeed()

        let result = await load.result

        #expect(throws: CancellationError.self) {
            try result.get()
        }
        #expect(await storage.fetchCallCount() == 0)
    }

    @Test
    func createMapsStorageFailureToRepositoryError() async {
        let repository = DefaultTodoRepository(
            importer: ImporterStub(),
            storage: StorageStub(createFailure: .generic)
        )

        await #expect(throws: TodoRepositoryError.createFailed) {
            try await repository.create(Self.makeItem())
        }
    }

    @Test
    func updateMapsNotFoundToRepositoryError() async {
        let item = Self.makeItem()
        let repository = DefaultTodoRepository(
            importer: ImporterStub(),
            storage: StorageStub(
                updateFailure: .notFound(item.id)
            )
        )

        await #expect(
            throws: TodoRepositoryError.todoNotFound(id: item.id)
        ) {
            try await repository.update(item)
        }
    }

    @Test
    func deleteMapsNotFoundToRepositoryError() async {
        let id = UUID()
        let repository = DefaultTodoRepository(
            importer: ImporterStub(),
            storage: StorageStub(
                deleteFailure: .notFound(id)
            )
        )

        await #expect(
            throws: TodoRepositoryError.todoNotFound(id: id)
        ) {
            try await repository.delete(id: id)
        }
    }

    @Test
    func loadTodosMapsStorageFailureToRepositoryError() async {
        let repository = DefaultTodoRepository(
            importer: ImporterStub(),
            storage: StorageStub(fetchFailure: .generic)
        )

        await #expect(throws: TodoRepositoryError.loadFailed) {
            _ = try await repository.loadTodos()
        }
    }

    @Test
    func createPreservesCancellation() async {
        let repository = DefaultTodoRepository(
            importer: ImporterStub(),
            storage: StorageStub(createFailure: .cancel)
        )

        await #expect(throws: CancellationError.self) {
            try await repository.create(Self.makeItem())
        }
    }

    @Test
    func updateMapsGenericStorageFailureToRepositoryError() async {
        let repository = DefaultTodoRepository(
            importer: ImporterStub(),
            storage: StorageStub(updateFailure: .generic)
        )

        await #expect(throws: TodoRepositoryError.updateFailed) {
            try await repository.update(Self.makeItem())
        }
    }

    @Test
    func deleteMapsGenericStorageFailureToRepositoryError() async {
        let repository = DefaultTodoRepository(
            importer: ImporterStub(),
            storage: StorageStub(deleteFailure: .generic)
        )

        await #expect(throws: TodoRepositoryError.deleteFailed) {
            try await repository.delete(id: UUID())
        }
    }

    private static func makeItem() -> TodoItem {
        TodoItem(
            id: UUID(),
            title: "Task",
            details: "Details",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .pending
        )
    }
}
