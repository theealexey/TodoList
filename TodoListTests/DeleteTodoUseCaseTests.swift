import Foundation
import Testing
@testable import TodoList

@Suite
struct DeleteTodoUseCaseTests {

    private enum TestError: Error, Equatable, Sendable {
        case deleteFailed
    }

    private actor RepositorySpy: TodoRepository {
        private let shouldFail: Bool
        private var deletedIDs: [UUID] = []

        init(shouldFail: Bool = false) {
            self.shouldFail = shouldFail
        }

        func loadTodos() async throws -> [TodoItem] { [] }
        func create(_ item: TodoItem) async throws {}
        func update(_ item: TodoItem) async throws {}

        func delete(id: UUID) async throws {
            if shouldFail {
                throw TestError.deleteFailed
            }
            deletedIDs.append(id)
        }

        func ids() -> [UUID] {
            deletedIDs
        }
    }

    @Test
    func executePassesTodoIDToDeleteDependency() async throws {
        let repository = RepositorySpy()
        let useCase = DeleteTodoUseCase(repository: repository)
        let id = UUID()

        try await useCase.execute(id: id)

        #expect(await repository.ids() == [id])
    }

    @Test
    func executePropagatesDeleteError() async {
        let repository = RepositorySpy(shouldFail: true)
        let useCase = DeleteTodoUseCase(repository: repository)

        do {
            try await useCase.execute(id: UUID())
            Issue.record("Expected delete to fail")
        } catch let error as TestError {
            #expect(error == .deleteFailed)
        } catch {
            Issue.record("Received unexpected error: \(error)")
        }
    }
}
