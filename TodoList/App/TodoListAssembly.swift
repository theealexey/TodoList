import UIKit

@MainActor
struct TodoListAssembly<Repository: TodoRepository> {

    private let repository: Repository

    init(repository: Repository) {
        self.repository = repository
    }

    func makeViewController() -> TodoListViewController {
        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCase(
                repository: repository
            ),
            toggleTodoStatusUseCase: ToggleTodoStatusUseCase(
                repository: repository
            ),
            deleteTodoUseCase: DeleteTodoUseCase(
                repository: repository
            )
        )

        let viewController = TodoListViewController(
            viewModel: viewModel
        )

        let editorAssembly = TodoEditorAssembly(
            createTodoUseCase: CreateTodoUseCase(
                repository: repository
            ),
            updateTodoUseCase: UpdateTodoUseCase(
                repository: repository
            )
        )

        configureEditorFlows(
            for: viewController,
            editorAssembly: editorAssembly
        )

        return viewController
    }

    private func configureEditorFlows<
        CreateUseCase: CreateTodoUseCaseProtocol,
        UpdateUseCase: UpdateTodoUseCaseProtocol
    >(
        for viewController: TodoListViewController,
        editorAssembly: TodoEditorAssembly<CreateUseCase, UpdateUseCase>
    ) {
        viewController.onAddTodo = {
            [weak viewController] in

            guard let viewController else {
                return
            }

            let editorViewController =
                editorAssembly.makeCreateViewController {
                    [weak viewController] _ in
                    viewController?.reloadTodos()
                }

            viewController.navigationController?
                .pushViewController(
                    editorViewController,
                    animated: true
                )
        }

        viewController.onEditTodo = {
            [weak viewController] item in

            guard let viewController else {
                return
            }

            let editorViewController =
                editorAssembly.makeEditViewController(
                    item: item
                ) { [weak viewController] _ in
                    viewController?.reloadTodos()
                }

            viewController.navigationController?
                .pushViewController(
                    editorViewController,
                    animated: true
                )
        }
    }
}
