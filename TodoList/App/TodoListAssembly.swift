import UIKit

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

        let viewController = TodoListViewController(
            viewModel: viewModel
        )

        configureCreateTodoFlow(
            for: viewController
        )

        return viewController
    }

    private func configureCreateTodoFlow(
        for viewController: TodoListViewController
    ) {
        viewController.onAddTodo = {
            [weak viewController] in

            guard let viewController else {
                return
            }

            let createAssembly = CreateTodoAssembly(
                container: container
            )

            let createViewController =
                createAssembly.makeViewController()

            let navigationController =
                UINavigationController(
                    rootViewController:
                        createViewController
                )

            createViewController.onCancel = {
                [weak navigationController] in

                navigationController?.dismiss(
                    animated: true
                )
            }

            createViewController.onSaved = {
                [weak navigationController, weak viewController]
                _ in

                navigationController?.dismiss(
                    animated: true
                ) {
                    viewController?.reloadTodos()
                }
            }

            viewController.present(
                navigationController,
                animated: true
            )
        }
    }
}
