import Foundation

@MainActor
final class TodoListViewModel {

    enum State: Equatable {
        case idle
        case loading
        case empty
        case noResults
        case content([TodoItem])
        case failure
    }

    enum ActionError: Equatable {
        case statusUpdateFailed
    }

    private let loadTodosUseCase: LoadTodosUseCase
    private let toggleTodoStatusUseCase:
        ToggleTodoStatusUseCase

    private var allItems: [TodoItem] = []
    private var searchQuery = ""
    private var updatingItemIDs: Set<UUID> = []

    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?
    var onActionError: ((ActionError) -> Void)?

    init(
        loadTodosUseCase: LoadTodosUseCase,
        toggleTodoStatusUseCase:
            ToggleTodoStatusUseCase
    ) {
        self.loadTodosUseCase = loadTodosUseCase
        self.toggleTodoStatusUseCase =
            toggleTodoStatusUseCase
    }

    func load() async {
        state = .loading

        do {
            allItems = try await loadTodosUseCase.execute()
            applySearch()
        } catch {
            allItems = []
            state = .failure
        }
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        applySearch()
    }

    func toggleStatus(
        for item: TodoItem
    ) async {
        guard updatingItemIDs
            .insert(item.id)
            .inserted
        else {
            return
        }

        defer {
            updatingItemIDs.remove(item.id)
        }

        do {
            let updatedItem =
                try await toggleTodoStatusUseCase.execute(
                    item: item
                )

            guard let index = allItems.firstIndex(
                where: { $0.id == updatedItem.id }
            ) else {
                return
            }

            allItems[index] = updatedItem
            applySearch()
        } catch {
            onActionError?(.statusUpdateFailed)
        }
    }

    private func applySearch() {
        guard !allItems.isEmpty else {
            state = .empty
            return
        }

        guard !searchQuery.isEmpty else {
            state = .content(allItems)
            return
        }

        let filteredItems = allItems.filter { item in
            item.title.localizedCaseInsensitiveContains(
                searchQuery
            )
            || item.details.localizedCaseInsensitiveContains(
                searchQuery
            )
        }

        state = filteredItems.isEmpty
            ? .noResults
            : .content(filteredItems)
    }
}
