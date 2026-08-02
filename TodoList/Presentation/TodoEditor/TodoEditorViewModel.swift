import Foundation

@MainActor
final class TodoEditorViewModel {

    enum Mode: Equatable {
        case create(createdAt: Date)
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

    typealias Create = (
        _ title: String,
        _ details: String
    ) async throws -> TodoItem

    typealias Update = (
        _ item: TodoItem,
        _ title: String,
        _ details: String
    ) async throws -> TodoItem

    let mode: Mode
    let initialContent: InitialContent

    private let create: Create
    private let update: Update

    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?

    init(
        mode: Mode,
        create: @escaping Create,
        update: @escaping Update
    ) {
        self.mode = mode
        self.create = create
        self.update = update

        switch mode {
        case let .create(createdAt):
            initialContent = InitialContent(
                title: "",
                details: "",
                createdAt: createdAt
            )

        case let .edit(item):
            initialContent = InitialContent(
                title: item.title,
                details: item.details,
                createdAt: item.createdAt
            )
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
            case .create:
                savedItem = try await create(
                    title,
                    details
                )

            case let .edit(originalItem):
                savedItem = try await update(
                    originalItem,
                    title,
                    details
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
