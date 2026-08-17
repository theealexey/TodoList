import Foundation

@MainActor
final class TodoEditorViewModel {

    enum Mode: Equatable {
        case create(NewTodoDraft)
        case edit(TodoItem)
    }

    struct InitialContent: Equatable {
        let title: String
        let details: String
        let createdAt: Date
    }

    enum State: Equatable {
        case idle
        case saving
        case validationFailure
        case saved(TodoItem)
        case failure
    }

    let mode: Mode
    let initialContent: InitialContent

    private let createTodoUseCase: any CreateTodoUseCaseProtocol
    private let updateTodoUseCase: any UpdateTodoUseCaseProtocol

    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?

    init(
        mode: Mode,
        createTodoUseCase: any CreateTodoUseCaseProtocol,
        updateTodoUseCase: any UpdateTodoUseCaseProtocol
    ) {
        self.mode = mode
        self.createTodoUseCase = createTodoUseCase
        self.updateTodoUseCase = updateTodoUseCase

        switch mode {
        case let .create(draft):
            initialContent = InitialContent(
                title: "",
                details: "",
                createdAt: draft.createdAt
            )

        case let .edit(item):
            initialContent = InitialContent(
                title: item.title,
                details: item.details,
                createdAt: item.createdAt
            )
        }
    }


    func hasChanges(
        title: String,
        details: String
    ) -> Bool {
        let normalizedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedDetails = details.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch mode {
        case .create:
            return !normalizedTitle.isEmpty
                || !normalizedDetails.isEmpty

        case .edit:
            return normalizedTitle != initialContent.title
                || normalizedDetails != initialContent.details
        }
    }

    func save(
        title: String,
        details: String
    ) async {
        guard state != .saving else {
            return
        }

        state = .saving

        do {
            let savedItem: TodoItem

            switch mode {
            case let .create(draft):
                savedItem = try await createTodoUseCase.execute(
                    draft: draft,
                    title: title,
                    details: details
                )

            case let .edit(originalItem):
                savedItem = try await updateTodoUseCase.execute(
                    item: originalItem,
                    title: title,
                    details: details
                )
            }

            state = .saved(savedItem)
        } catch let error as CreateTodoUseCaseError {
            handleCreateError(error)
        } catch let error as UpdateTodoUseCaseError {
            handleUpdateError(error)
        } catch {
            state = .failure
        }
    }

    private func handleCreateError(
        _ error: CreateTodoUseCaseError
    ) {
        switch error {
        case .emptyTitle:
            state = .validationFailure
        }
    }

    private func handleUpdateError(
        _ error: UpdateTodoUseCaseError
    ) {
        switch error {
        case .emptyTitle:
            state = .validationFailure
        }
    }
}
