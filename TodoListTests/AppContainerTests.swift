import Foundation
import Synchronization
import Testing
@testable import TodoList

@Suite
struct AppContainerTests {

    @Test
    func usesInjectedInfrastructureContracts() async throws {
        let storage = StorageSpy()
        let todosFetcher = TodosFetcherSpy(
            todos: [
                TodoDTO(
                    id: 1,
                    todo: "Injected todo",
                    completed: true
                )
            ]
        )
        let importStateStore = ImportStateStoreSpy()
        let storeIdentifier = "test-store"

        let appContainer = AppContainer(
            storage: storage,
            storeIdentifier: storeIdentifier,
            todosFetcher: todosFetcher,
            importStateStore: importStateStore
        )

        let items = try await appContainer
            .todoRepository
            .loadTodos()

        let item = try #require(items.first)

        #expect(await todosFetcher.callCount() == 1)
        #expect(await storage.importCallCount() == 1)
        #expect(await storage.fetchCallCount() == 1)
        #expect(importStateStore.isCompleted(for: storeIdentifier))
        #expect(item.title == "Injected todo")
        #expect(item.status == .completed)
    }

    private actor TodosFetcherSpy: TodosFetching {

        private let todos: [TodoDTO]
        private var numberOfCalls = 0

        init(todos: [TodoDTO]) {
            self.todos = todos
        }

        func fetchTodos() async throws -> [TodoDTO] {
            numberOfCalls += 1
            return todos
        }

        func callCount() -> Int {
            numberOfCalls
        }
    }

    private actor StorageSpy: TodoStoring, TodoImportStoring {

        private var items: [TodoItem] = []
        private var numberOfImportCalls = 0
        private var numberOfFetchCalls = 0

        func create(_ item: TodoItem) async throws {
            items.append(item)
        }

        func update(_ item: TodoItem) async throws {
            guard let index = items.firstIndex(
                where: { $0.id == item.id }
            ) else {
                throw TodoStorageError.todoNotFound(id: item.id)
            }

            items[index] = item
        }

        func delete(id: UUID) async throws {
            guard let index = items.firstIndex(
                where: { $0.id == id }
            ) else {
                throw TodoStorageError.todoNotFound(id: id)
            }

            items.remove(at: index)
        }

        func fetchAll() async throws -> [TodoItem] {
            numberOfFetchCalls += 1
            return items
        }

        func importTodos(
            _ records: [TodoImportRecord],
            importedAt: Date
        ) async throws {
            numberOfImportCalls += 1

            items = records.map { record in
                TodoItem(
                    id: UUID(),
                    title: record.title,
                    details: "",
                    createdAt: importedAt,
                    status: record.isCompleted
                        ? .completed
                        : .pending
                )
            }
        }

        func importCallCount() -> Int {
            numberOfImportCalls
        }

        func fetchCallCount() -> Int {
            numberOfFetchCalls
        }
    }

    private final class ImportStateStoreSpy:
        InitialTodoImportStateStoring {

        private let completedStoreIdentifier = Mutex<String?>(nil)

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
}
