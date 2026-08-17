import Foundation
import Testing
@testable import TodoList

@Suite
struct ToggleTodoStatusUseCaseTests {

    private actor RepositorySpy: TodoRepository {
        private var updatedItems: [TodoItem] = []

        func loadTodos() async throws -> [TodoItem] { [] }
        func create(_ item: TodoItem) async throws {}

        func update(_ item: TodoItem) async throws {
            updatedItems.append(item)
        }

        func delete(id: UUID) async throws {}

        func items() -> [TodoItem] {
            updatedItems
        }
    }

    @Test
    func executeChangesPendingTodoToCompleted() async throws {
        let repository = RepositorySpy()
        let useCase = ToggleTodoStatusUseCase(repository: repository)
        let item = Self.makeItem(status: .pending)

        let updatedItem = try await useCase.execute(item: item)

        #expect(updatedItem.status == .completed)
        #expect(await repository.items() == [updatedItem])
    }

    @Test
    func executeChangesCompletedTodoToPending() async throws {
        let repository = RepositorySpy()
        let useCase = ToggleTodoStatusUseCase(repository: repository)
        let item = Self.makeItem(status: .completed)

        let updatedItem = try await useCase.execute(item: item)

        #expect(updatedItem.status == .pending)
        #expect(await repository.items() == [updatedItem])
    }

    private static func makeItem(status: TodoStatus) -> TodoItem {
        TodoItem(
            id: UUID(),
            title: "Task",
            details: "Details",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: status
        )
    }
}
