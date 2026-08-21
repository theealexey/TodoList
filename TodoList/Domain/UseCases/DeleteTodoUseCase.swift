import Foundation

protocol DeleteTodoUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws
}

struct DeleteTodoUseCase<Repository: TodoRepository>: DeleteTodoUseCaseProtocol {

    private let repository: Repository

    init(repository: Repository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}
