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

    @MainActor
    func makeCreateViewController(
        onSaved: @escaping (TodoItem) -> Void
    ) -> TodoEditorViewController {
        let draft = createTodoUseCase.makeDraft()
        let mode = TodoEditorViewModel.Mode.create(
            draft
        )

        return makeViewController(
            mode: mode,
            onSaved: onSaved
        )
    }

    @MainActor
    func makeEditViewController(
        item: TodoItem,
        onSaved: @escaping (TodoItem) -> Void
    ) -> TodoEditorViewController {
        let mode = TodoEditorViewModel.Mode.edit(
            item
        )

        return makeViewController(
            mode: mode,
            onSaved: onSaved
        )
    }

    @MainActor
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
