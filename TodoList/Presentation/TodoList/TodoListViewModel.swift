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
        case deleteFailed
        case operationInProgress
    }

    private let loadTodosUseCase: LoadTodosUseCase
    private let toggleTodoStatusUseCase: ToggleTodoStatusUseCase
    private let deleteTodoUseCase: DeleteTodoUseCase

    private var allItems: [TodoItem] = []
    private var searchQuery = ""
    private var processingItemIDs: Set<UUID> = []

    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?
    var onActionError: ((ActionError) -> Void)?

    init(
        loadTodosUseCase: LoadTodosUseCase,
        toggleTodoStatusUseCase: ToggleTodoStatusUseCase,
        deleteTodoUseCase: DeleteTodoUseCase
    ) {
        self.loadTodosUseCase = loadTodosUseCase
        self.toggleTodoStatusUseCase = toggleTodoStatusUseCase
        self.deleteTodoUseCase = deleteTodoUseCase
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

    func toggleStatus(for item: TodoItem) async {
        guard processingItemIDs.insert(item.id).inserted else {
            onActionError?(.operationInProgress)
            return
        }

        defer {
            processingItemIDs.remove(item.id)
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

    func delete(_ item: TodoItem) async {
        guard processingItemIDs.insert(item.id).inserted else {
            onActionError?(.operationInProgress)
            return
        }

        defer {
            processingItemIDs.remove(item.id)
        }

        do {
            try await deleteTodoUseCase.execute(id: item.id)

            allItems.removeAll {
                $0.id == item.id
            }

            applySearch()
        } catch {
            onActionError?(.deleteFailed)
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
