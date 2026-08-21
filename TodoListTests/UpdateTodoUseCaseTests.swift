import Foundation
import Testing
@testable import TodoList

@Suite
struct UpdateTodoUseCaseTests {

    private enum TestError: Error, Equatable, Sendable {
        case updateFailed
    }

    private actor RepositorySpy: TodoRepository {
        private let shouldFail: Bool
        private var updatedItems: [TodoItem] = []

        init(shouldFail: Bool = false) {
            self.shouldFail = shouldFail
        }

        func loadTodos() async throws -> [TodoItem] { [] }
        func create(_ item: TodoItem) async throws {}

        func update(_ item: TodoItem) async throws {
            if shouldFail {
                throw TestError.updateFailed
            }
            updatedItems.append(item)
        }

        func delete(id: UUID) async throws {}

        func items() -> [TodoItem] {
            updatedItems
        }
    }

    @Test
    func executeUpdatesTextAndPreservesTodoIdentity() async throws {
        let repository = RepositorySpy()
        let useCase = UpdateTodoUseCase(repository: repository)
        let item = Self.makeItem()

        let updatedItem = try await useCase.execute(
            item: item,
            title: "  Updated title  ",
            details: "  Updated details  "
        )

        let expectedItem = TodoItem(
            id: item.id,
            title: "Updated title",
            details: "Updated details",
            createdAt: item.createdAt,
            status: item.status
        )

        #expect(updatedItem == expectedItem)
        #expect(await repository.items() == [expectedItem])
    }

    @Test
    func executeRejectsBlankTitleWithoutUpdatingTodo() async {
        let repository = RepositorySpy()
        let useCase = UpdateTodoUseCase(repository: repository)

        do {
            _ = try await useCase.execute(
                item: Self.makeItem(),
                title: " \n ",
                details: "Details"
            )
            Issue.record("Expected an empty title error")
        } catch let error as UpdateTodoUseCaseError {
            #expect(error == .emptyTitle)
        } catch {
            Issue.record("Received unexpected error: \(error)")
        }

        #expect(await repository.items().isEmpty)
    }

    @Test
    func executePropagatesUpdateError() async {
        let repository = RepositorySpy(shouldFail: true)
        let useCase = UpdateTodoUseCase(repository: repository)

        do {
            _ = try await useCase.execute(
                item: Self.makeItem(),
                title: "Updated title",
                details: "Details"
            )
            Issue.record("Expected update to fail")
        } catch let error as TestError {
            #expect(error == .updateFailed)
        } catch {
            Issue.record("Received unexpected error: \(error)")
        }
    }

    private static func makeItem() -> TodoItem {
        TodoItem(
            id: UUID(),
            title: "Original",
            details: "Original details",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .completed
        )
    }
}
