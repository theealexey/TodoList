import Foundation
import Testing
@testable import TodoList

@Suite
struct CreateTodoUseCaseTests {

    private actor RepositorySpy: TodoRepository {
        private var createdItems: [TodoItem] = []

        func loadTodos() async throws -> [TodoItem] { [] }

        func create(_ item: TodoItem) async throws {
            createdItems.append(item)
        }

        func update(_ item: TodoItem) async throws {}
        func delete(id: UUID) async throws {}

        func items() -> [TodoItem] {
            createdItems
        }
    }

    @Test
    func makeDraftUsesInjectedIdentityAndDate() throws {
        let id = try #require(
            UUID(
                uuidString: "11111111-1111-1111-1111-111111111111"
            )
        )
        let createdAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )
        let useCase = CreateTodoUseCase(
            repository: RepositorySpy(),
            makeID: { id },
            currentDate: { createdAt }
        )

        #expect(
            useCase.makeDraft() == NewTodoDraft(
                id: id,
                createdAt: createdAt
            )
        )
    }

    @Test
    func executeCreatesPendingTodoWithNormalizedInput() async throws {
        let draft = NewTodoDraft(
            id: try #require(
                UUID(
                    uuidString: "11111111-1111-1111-1111-111111111111"
                )
            ),
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            )
        )
        let repository = RepositorySpy()
        let useCase = CreateTodoUseCase(repository: repository)

        let item = try await useCase.execute(
            draft: draft,
            title: "  Buy milk \n",
            details: "  Two cartons  "
        )

        let expectedItem = TodoItem(
            id: draft.id,
            title: "Buy milk",
            details: "Two cartons",
            createdAt: draft.createdAt,
            status: .pending
        )

        #expect(item == expectedItem)
        #expect(await repository.items() == [expectedItem])
    }

    @Test
    func executeRejectsBlankTitleWithoutCreatingTodo() async {
        let repository = RepositorySpy()
        let useCase = CreateTodoUseCase(repository: repository)
        let draft = NewTodoDraft(
            id: UUID(),
            createdAt: Date()
        )

        do {
            _ = try await useCase.execute(
                draft: draft,
                title: " \n ",
                details: "Details"
            )
            Issue.record("Expected an empty title error")
        } catch let error as CreateTodoUseCaseError {
            #expect(error == .emptyTitle)
        } catch {
            Issue.record("Received unexpected error: \(error)")
        }

        #expect(await repository.items().isEmpty)
    }
}
