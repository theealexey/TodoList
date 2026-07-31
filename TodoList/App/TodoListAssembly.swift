@MainActor
struct TodoListAssembly {

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func makeViewController() -> TodoListViewController {
        let loadTodosUseCase = LoadTodosUseCase {
            try await container.prepare()

            return try await container
                .todoRepository
                .loadTodos()
        }

        let viewModel = TodoListViewModel(
            loadTodosUseCase: loadTodosUseCase
        )

        return TodoListViewController(
            viewModel: viewModel
        )
    }
}
