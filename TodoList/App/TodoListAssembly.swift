import UIKit

struct TodoListAssembly<Repository: TodoRepository> {

    private let repository: Repository

    init(repository: Repository) {
        self.repository = repository
    }

    @MainActor
    func makeViewController() -> TodoListViewController {
        let loadTodosUseCase = LoadTodosUseCase(
            repository: repository
        )

        let toggleTodoStatusUseCase = ToggleTodoStatusUseCase(
            repository: repository
        )

        let deleteTodoUseCase = DeleteTodoUseCase(
            repository: repository
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: loadTodosUseCase,
            toggleTodoStatusUseCase: toggleTodoStatusUseCase,
            deleteTodoUseCase: deleteTodoUseCase
        )

        let viewController = TodoListViewController(
            viewModel: viewModel
        )

        let createTodoUseCase = CreateTodoUseCase(
            repository: repository
        )

        let updateTodoUseCase = UpdateTodoUseCase(
            repository: repository
        )

        let editorAssembly = TodoEditorAssembly(
            createTodoUseCase: createTodoUseCase,
            updateTodoUseCase: updateTodoUseCase
        )

        configureEditorFlows(
            for: viewController,
            editorAssembly: editorAssembly
        )

        return viewController
    }

    @MainActor
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
