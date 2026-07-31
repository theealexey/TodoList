@MainActor
final class CreateTodoViewModel {

    enum State: Equatable {
        case idle
        case saving
        case validationFailure
        case saved(TodoItem)
        case failure
    }

    private let createTodoUseCase: CreateTodoUseCase

    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?

    init(createTodoUseCase: CreateTodoUseCase) {
        self.createTodoUseCase = createTodoUseCase
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
            let item = try await createTodoUseCase.execute(
                title: title,
                details: details
            )

            state = .saved(item)
        } catch CreateTodoUseCaseError.emptyTitle {
            state = .validationFailure
        } catch {
            state = .failure
        }
    }
}
