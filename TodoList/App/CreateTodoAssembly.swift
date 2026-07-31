@MainActor
struct CreateTodoAssembly {

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func makeViewController() -> CreateTodoViewController {
        let createTodoUseCase = CreateTodoUseCase(
            create: { item in
                try await container.prepare()

                try await container
                    .todoRepository
                    .create(item)
            }
        )

        let viewModel = CreateTodoViewModel(
            createTodoUseCase: createTodoUseCase
        )

        return CreateTodoViewController(
            viewModel: viewModel
        )
    }
}
