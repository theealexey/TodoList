import Foundation

@MainActor
final class TodoEditorAssembly {

    private let create: TodoEditorViewModel.Create
    private let update: TodoEditorViewModel.Update

    init(
        create: @escaping TodoEditorViewModel.Create,
        update: @escaping TodoEditorViewModel.Update
    ) {
        self.create = create
        self.update = update
    }

    func makeCreateViewController(
        createdAt: Date,
        onSaved: @escaping (TodoItem) -> Void
    ) -> TodoEditorViewController {
        makeViewController(
            mode: .create(
                createdAt: createdAt
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
            create: create,
            update: update
        )

        let viewController = TodoEditorViewController(
            viewModel: viewModel
        )

        viewController.onSaved = onSaved

        return viewController
    }
}
