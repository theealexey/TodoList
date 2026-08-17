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
    private let searchQueue: OperationQueue

    private var allItems: [TodoItem] = []
    private var searchQuery = ""
    private var processingItemIDs: Set<UUID> = []
    private var currentSearchOperation: BlockOperation?
    private var currentLoadID: UUID?
    private var stateBeforeLoading: State?

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

        let searchQueue = OperationQueue()
        searchQueue.maxConcurrentOperationCount = 1
        searchQueue.qualityOfService = .userInitiated
        self.searchQueue = searchQueue
    }
    
    func load() async {
        cancelCurrentSearch()

        let loadID = UUID()

        if currentLoadID == nil {
            stateBeforeLoading = state
        }

        currentLoadID = loadID
        state = .loading

        do {
            let loadedItems = try await loadTodosUseCase.execute()

            guard currentLoadID == loadID else {
                return
            }

            guard !Task.isCancelled else {
                restoreStateAfterCancelledLoad(loadID: loadID)
                return
            }

            allItems = loadedItems
            currentLoadID = nil
            stateBeforeLoading = nil
            applySearch()
        } catch is CancellationError {
            restoreStateAfterCancelledLoad(loadID: loadID)
        } catch {
            guard currentLoadID == loadID else {
                return
            }

            currentLoadID = nil
            stateBeforeLoading = nil
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
        guard currentLoadID == nil else {
            return
        }

        cancelCurrentSearch()

        guard !allItems.isEmpty else {
            state = .empty
            return
        }

        guard !searchQuery.isEmpty else {
            state = .content(allItems)
            return
        }

        let items = allItems
        let query = searchQuery
        let operation = BlockOperation()

        operation.addExecutionBlock {
            [weak operation, weak self] in
            guard let operation, !operation.isCancelled else {
                return
            }

            var filteredItems: [TodoItem] = []
            filteredItems.reserveCapacity(items.count)

            for item in items {
                guard !operation.isCancelled else {
                    return
                }

                let matchesTitle =
                    item.title.localizedCaseInsensitiveContains(
                        query
                    )

                let matchesDetails =
                    item.details.localizedCaseInsensitiveContains(
                        query
                    )

                if matchesTitle || matchesDetails {
                    filteredItems.append(item)
                }
            }

            guard !operation.isCancelled else {
                return
            }

            let result = filteredItems

            DispatchQueue.main.async {
                [weak self, weak operation] in
                guard
                    let self,
                    let operation,
                    !operation.isCancelled,
                    self.currentSearchOperation === operation
                else {
                    return
                }

                self.currentSearchOperation = nil
                self.state = result.isEmpty
                    ? .noResults
                    : .content(result)
            }
        }

        currentSearchOperation = operation
        searchQueue.addOperation(operation)
    }


    private func restoreStateAfterCancelledLoad(loadID: UUID) {
        guard currentLoadID == loadID else {
            return
        }

        currentLoadID = nil

        let restoredState = stateBeforeLoading ?? .idle
        stateBeforeLoading = nil
        state = restoredState
    }

    private func cancelCurrentSearch() {
        currentSearchOperation?.cancel()
        currentSearchOperation = nil
    }
}
