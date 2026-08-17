@MainActor
struct TodoEditorAssembly<
    CreateUseCase: CreateTodoUseCaseProtocol,
    UpdateUseCase: UpdateTodoUseCaseProtocol
> {

    private let createTodoUseCase: CreateUseCase
    private let updateTodoUseCase: UpdateUseCase

    init(
        createTodoUseCase: CreateUseCase,
        updateTodoUseCase: UpdateUseCase
    ) {
        self.createTodoUseCase = createTodoUseCase
        self.updateTodoUseCase = updateTodoUseCase
    }

    func makeCreateViewController(
        onSaved: @escaping (TodoItem) -> Void
    ) -> TodoEditorViewController {
        makeViewController(
            mode: .create(
                createTodoUseCase.makeDraft()
            ),
            onSaved: onSaved
        )
    }

    func makeEditViewController(
        item: TodoItem,
        onSaved: @escaping (TodoItem) -> Void
    ) -> TodoEditorViewController {
        makeViewController(
            mode: .edit(item),
            onSaved: onSaved
        )
    }

    private func makeViewController(
        mode: TodoEditorViewModel.Mode,
        onSaved: @escaping (TodoItem) -> Void
    ) -> TodoEditorViewController {
        let viewModel = TodoEditorViewModel(
            mode: mode,
            createTodoUseCase: createTodoUseCase,
            updateTodoUseCase: updateTodoUseCase
        )

        let viewController = TodoEditorViewController(
            viewModel: viewModel
        )
        viewController.onSaved = onSaved
        return viewController
    }
}
