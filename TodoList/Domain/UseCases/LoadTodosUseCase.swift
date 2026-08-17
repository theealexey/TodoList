protocol LoadTodosUseCaseProtocol: Sendable {
    func execute() async throws -> [TodoItem]
}

struct LoadTodosUseCase<Repository: TodoRepository>: LoadTodosUseCaseProtocol {

    private let repository: Repository

    init(repository: Repository) {
        self.repository = repository
    }

    func execute() async throws -> [TodoItem] {
        try await repository.loadTodos()
    }
}
