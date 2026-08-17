import UIKit

@MainActor
struct TodoListAssembly {

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func makeViewController() -> TodoListViewController {
        let loadTodosUseCase = LoadTodosUseCase {
            try await container
                .todoRepository
                .loadTodos()
        }

        let toggleTodoStatusUseCase =
            ToggleTodoStatusUseCase(
                update: { item in
                    try await container
                        .todoRepository
                        .update(item)
                }
            )

        let deleteTodoUseCase = DeleteTodoUseCase(
            delete: { id in
                try await container
                    .todoRepository
                    .delete(id: id)
            }
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: loadTodosUseCase,
            toggleTodoStatusUseCase:
                toggleTodoStatusUseCase,
            deleteTodoUseCase:
                deleteTodoUseCase
        )

        let viewController = TodoListViewController(
            viewModel: viewModel
        )

        let editorAssembly = makeEditorAssembly()

        configureEditorFlows(
            for: viewController,
            editorAssembly: editorAssembly
        )

        return viewController
    }

    private func makeEditorAssembly()
        -> TodoEditorAssembly {
        let createTodoUseCase = CreateTodoUseCase(
            create: { item in
                try await container
                    .todoRepository
                    .create(item)
            }
        )

        let updateTodoUseCase = UpdateTodoUseCase(
            update: { item in
                try await container
                    .todoRepository
                    .update(item)
            }
        )

        return TodoEditorAssembly(
            create: { title, details in
                try await createTodoUseCase.execute(
                    title: title,
                    details: details
                )
            },
            update: { item, title, details in
                try await updateTodoUseCase.execute(
                    item: item,
                    title: title,
                    details: details
                )
            }
        )
    }

    private func configureEditorFlows(
        for viewController: TodoListViewController,
        editorAssembly: TodoEditorAssembly
    ) {
        viewController.onAddTodo = {
            [weak viewController] in

            guard let viewController else {
                return
            }

            let editorViewController =
                editorAssembly.makeCreateViewController(
                    createdAt: Date()
                ) { [weak viewController] _ in
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
