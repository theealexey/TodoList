
@MainActor
final class TodoListViewModel {

    enum State: Equatable {
        case idle
        case loading
        case empty
        case content([TodoItem])
        case failure
    }

    private let loadTodosUseCase: LoadTodosUseCase

    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?

    init(loadTodosUseCase: LoadTodosUseCase) {
        self.loadTodosUseCase = loadTodosUseCase
    }

    func load() async {
        state = .loading

        do {
            let items = try await loadTodosUseCase.execute()

            state = items.isEmpty
                ? .empty
                : .content(items)
        } catch {
            state = .failure
        }
    }
}
