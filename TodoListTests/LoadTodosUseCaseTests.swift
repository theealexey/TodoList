import Foundation
import Testing
@testable import TodoList

@Suite
struct LoadTodosUseCaseTests {

    private enum TestError: Error, Equatable, Sendable {
        case loadingFailed
    }

    private actor RepositoryStub: TodoRepository {
        private let result: Result<[TodoItem], TestError>

        init(result: Result<[TodoItem], TestError>) {
            self.result = result
        }

        func loadTodos() async throws -> [TodoItem] {
            try result.get()
        }

        func create(_ item: TodoItem) async throws {}
        func update(_ item: TodoItem) async throws {}
        func delete(id: UUID) async throws {}
    }

    @Test
    func executeReturnsLoadedTodos() async throws {
        let expectedItems = [
            TodoItem(
                id: UUID(),
                title: "First task",
                details: "First details",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                status: .pending
            ),
            TodoItem(
                id: UUID(),
                title: "Second task",
                details: "Second details",
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                status: .completed
            )
        ]
        let repository = RepositoryStub(result: .success(expectedItems))
        let useCase = LoadTodosUseCase(repository: repository)

        #expect(try await useCase.execute() == expectedItems)
    }

    @Test
    func executePropagatesLoadingError() async {
        let repository = RepositoryStub(result: .failure(.loadingFailed))
        let useCase = LoadTodosUseCase(repository: repository)

        do {
            _ = try await useCase.execute()
            Issue.record("Expected loading to fail")
        } catch let error as TestError {
            #expect(error == .loadingFailed)
        } catch {
            Issue.record("Received unexpected error: \(error)")
        }
    }
}
