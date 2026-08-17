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

    private let loadTodosUseCase: any LoadTodosUseCaseProtocol
    private let toggleTodoStatusUseCase: any ToggleTodoStatusUseCaseProtocol
    private let deleteTodoUseCase: any DeleteTodoUseCaseProtocol
    private let searchQueue: OperationQueue

    private var allItems: [TodoItem] = []
    private var searchQuery = ""
    private var processingItemIDs: Set<UUID> = []
    private var currentSearchOperation: BlockOperation?
    private var currentLoadID: UUID?
    private var stateBeforeLoading: State?
    private var contentRevision = 0

    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?
    var onActionError: ((ActionError) -> Void)?

    init(
        loadTodosUseCase: any LoadTodosUseCaseProtocol,
        toggleTodoStatusUseCase: any ToggleTodoStatusUseCaseProtocol,
        deleteTodoUseCase: any DeleteTodoUseCaseProtocol
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
        let startingContentRevision = contentRevision

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
                restoreStateAfterCancelledLoad(
                    loadID: loadID,
                    startingContentRevision: startingContentRevision
                )
                return
            }

            currentLoadID = nil

            guard contentRevision == startingContentRevision else {
                stateBeforeLoading = nil
                applySearch()
                return
            }

            allItems = loadedItems
            stateBeforeLoading = nil
            applySearch()
        } catch is CancellationError {
            restoreStateAfterCancelledLoad(
                loadID: loadID,
                startingContentRevision: startingContentRevision
            )
        } catch {
            guard currentLoadID == loadID else {
                return
            }

            currentLoadID = nil

            guard contentRevision == startingContentRevision else {
                stateBeforeLoading = nil
                applySearch()
                return
            }

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
            contentRevision += 1
            applySearch()
        } catch is CancellationError {
            return
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

            contentRevision += 1
            applySearch()
        } catch is CancellationError {
            return
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


    private func restoreStateAfterCancelledLoad(
        loadID: UUID,
        startingContentRevision: Int
    ) {
        guard currentLoadID == loadID else {
            return
        }

        currentLoadID = nil

        guard contentRevision == startingContentRevision else {
            stateBeforeLoading = nil
            applySearch()
            return
        }

        let restoredState = stateBeforeLoading ?? .idle
        stateBeforeLoading = nil
        state = restoredState
    }

    private func cancelCurrentSearch() {
        currentSearchOperation?.cancel()
        currentSearchOperation = nil
    }
}
