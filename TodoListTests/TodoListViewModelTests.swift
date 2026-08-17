import Foundation
import Synchronization
import Testing
@testable import TodoList

private actor SuspendedMutation {

    private struct StartWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private let suspendedIDs: Set<UUID>
    private var startedIDs: [UUID] = []
    private var startWaiters: [StartWaiter] = []
    private var releaseContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    init(suspendedIDs: Set<UUID>) {
        self.suspendedIDs = suspendedIDs
    }

    func execute(id: UUID) async {
        startedIDs.append(id)
        resumeReadyStartWaiters()

        guard suspendedIDs.contains(id) else {
            return
        }

        guard releaseContinuations[id] == nil else {
            return
        }

        await withCheckedContinuation { continuation in
            releaseContinuations[id] = continuation
        }
    }

    func waitForStartCount(_ expectedCount: Int) async {
        guard startedIDs.count < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            startWaiters.append(
                StartWaiter(
                    expectedCount: expectedCount,
                    continuation: continuation
                )
            )
        }
    }

    func invocationCount(for id: UUID) -> Int {
        startedIDs.filter { $0 == id }.count
    }

    func startedItemIDs() -> Set<UUID> {
        Set(startedIDs)
    }

    func release(id: UUID) {
        releaseContinuations.removeValue(
            forKey: id
        )?.resume()
    }

    private func resumeReadyStartWaiters() {
        let readyWaiters = startWaiters.filter {
            startedIDs.count >= $0.expectedCount
        }

        startWaiters.removeAll {
            startedIDs.count >= $0.expectedCount
        }

        readyWaiters.forEach {
            $0.continuation.resume()
        }
    }
}

private enum ControlledLoadError: Error, Sendable {
    case failed
}

private actor ControlledLoad {

    private struct StartWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var invocationCount = 0
    private var continuations: [
        Int: CheckedContinuation<[TodoItem], Error>
    ] = [:]
    private var startWaiters: [StartWaiter] = []

    func execute() async throws -> [TodoItem] {
        invocationCount += 1
        let invocation = invocationCount
        resumeReadyStartWaiters()

        return try await withCheckedThrowingContinuation { continuation in
            continuations[invocation] = continuation
        }
    }

    func waitForStartCount(_ expectedCount: Int) async {
        guard invocationCount < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            startWaiters.append(
                StartWaiter(
                    expectedCount: expectedCount,
                    continuation: continuation
                )
            )
        }
    }

    func succeed(
        invocation: Int,
        with items: [TodoItem]
    ) {
        continuations.removeValue(
            forKey: invocation
        )?.resume(returning: items)
    }

    func fail(invocation: Int) {
        continuations.removeValue(
            forKey: invocation
        )?.resume(throwing: ControlledLoadError.failed)
    }

    private func resumeReadyStartWaiters() {
        let readyWaiters = startWaiters.filter {
            invocationCount >= $0.expectedCount
        }

        startWaiters.removeAll {
            invocationCount >= $0.expectedCount
        }

        readyWaiters.forEach {
            $0.continuation.resume()
        }
    }
}

@Suite
@MainActor
struct TodoListViewModelTests {
    
    private enum TestError: Error {
        case loadingFailed
    }
    
    private func makeViewModel(
        items: [TodoItem],
        update: @escaping ToggleTodoStatusUseCaseStub.Update = { _ in },
        delete: @escaping DeleteTodoUseCaseStub.Delete = { _ in }
    ) -> TodoListViewModel {
        TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                items
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: update
                ),
            deleteTodoUseCase:
                DeleteTodoUseCaseStub(
                    delete: delete
                )
        )
    }
    
    private func waitForState(
        _ expectedState: TodoListViewModel.State,
        in viewModel: TodoListViewModel
    ) async {
        guard viewModel.state != expectedState else {
            return
        }

        await withCheckedContinuation { continuation in
            viewModel.onStateChange = { state in
                guard state == expectedState else {
                    return
                }

                viewModel.onStateChange = nil
                continuation.resume()
            }
        }
    }
    
    @Test
    func loadTransitionsFromLoadingToContent() async {
        let expectedItems = [
            TodoItem(
                id: UUID(),
                title: "Loaded task",
                details: "Task details",
                createdAt: Date(
                    timeIntervalSince1970: 1_700_000_000
                ),
                status: .pending
            )
        ]

        let loadTodosUseCase = LoadTodosUseCaseStub {
            expectedItems
        }

        let toggleTodoStatusUseCase =
            ToggleTodoStatusUseCaseStub(
                update: { _ in }
            )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: loadTodosUseCase,
            toggleTodoStatusUseCase:
                toggleTodoStatusUseCase,
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
)
        
        var receivedStates: [
            TodoListViewModel.State
        ] = []

        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()

        #expect(
            receivedStates == [
                .loading,
                .content(expectedItems)
            ]
        )

        #expect(
            viewModel.state == .content(
                expectedItems
            )
        )
    }
    
    @Test
    func loadTransitionsFromLoadingToEmpty() async {
        let useCase = LoadTodosUseCaseStub({
                []
            }
        )
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            ),
        )
        
        var receivedStates: [TodoListViewModel.State] = []
        
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }
        
        await viewModel.load()
        
        #expect(
            receivedStates == [
                .loading,
                .empty
            ]
        )
        
        #expect(viewModel.state == .empty)
    }
    
    @Test
    func loadTransitionsFromLoadingToFailure() async {
        let useCase = LoadTodosUseCaseStub({ () async throws -> [TodoItem] in
                throw TestError.loadingFailed
            }
        )
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )
        
        var receivedStates: [TodoListViewModel.State] = []
        
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }
        
        await viewModel.load()
        
        #expect(
            receivedStates == [
                .loading,
                .failure
            ]
        )
        
        #expect(viewModel.state == .failure)
    }
    
    @Test
    func newerLoadResultWinsWhenOlderLoadFinishesLast() async {
        let olderItems = [makeItem(title: "Older result")]
        let newerItems = [makeItem(title: "Newer result")]
        let controlledLoad = ControlledLoad()
        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                try await controlledLoad.execute()
            },
            toggleTodoStatusUseCase: ToggleTodoStatusUseCaseStub(
                update: { _ in }
            ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        let olderLoad = Task {
            await viewModel.load()
        }

        await controlledLoad.waitForStartCount(1)

        let newerLoad = Task {
            await viewModel.load()
        }

        await controlledLoad.waitForStartCount(2)
        await controlledLoad.succeed(
            invocation: 2,
            with: newerItems
        )
        await newerLoad.value

        #expect(viewModel.state == .content(newerItems))

        await controlledLoad.succeed(
            invocation: 1,
            with: olderItems
        )
        await olderLoad.value

        #expect(viewModel.state == .content(newerItems))
    }

    @Test
    func cancelledLoadDoesNotTransitionToFailure() async {
        let useCase = LoadTodosUseCaseStub {
            try await Task.sleep(for: .seconds(60))
            return [TodoItem]()
        }
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase: ToggleTodoStatusUseCaseStub(
                update: { _ in }
            ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        var loadTask: Task<Void, Never>?

        await withCheckedContinuation { continuation in
            var didResume = false

            viewModel.onStateChange = { state in
                guard
                    !didResume,
                    state == .loading
                else {
                    return
                }

                didResume = true
                continuation.resume()
            }

            loadTask = Task {
                await viewModel.load()
            }
        }

        loadTask?.cancel()
        await loadTask?.value

        #expect(viewModel.state == .idle)
    }

    @Test
    func searchChangeDuringLoadDoesNotReplaceLoadingState() async {
        let matchingItem = makeItem(title: "Buy milk")
        let otherItem = makeItem(title: "Clean apartment")
        let controlledLoad = ControlledLoad()
        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                try await controlledLoad.execute()
            },
            toggleTodoStatusUseCase: ToggleTodoStatusUseCaseStub(
                update: { _ in }
            ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        let loadTask = Task {
            await viewModel.load()
        }

        await controlledLoad.waitForStartCount(1)

        viewModel.updateSearchQuery("milk")
        #expect(viewModel.state == .loading)

        await controlledLoad.succeed(
            invocation: 1,
            with: [matchingItem, otherItem]
        )
        await loadTask.value

        await waitForState(
            .content([matchingItem]),
            in: viewModel
        )

        #expect(viewModel.state == .content([matchingItem]))
    }

    @Test
    func toggleDuringRefreshPreventsStaleLoadFromRestoringOldItem() async {
        let item = makeItem(title: "Refresh toggle")
        let controlledLoad = ControlledLoad()
        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                try await controlledLoad.execute()
            },
            toggleTodoStatusUseCase: ToggleTodoStatusUseCaseStub(
                update: { _ in }
            ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        let initialLoad = Task {
            await viewModel.load()
        }
        await controlledLoad.waitForStartCount(1)
        await controlledLoad.succeed(
            invocation: 1,
            with: [item]
        )
        await initialLoad.value

        let refresh = Task {
            await viewModel.load()
        }
        await controlledLoad.waitForStartCount(2)

        await viewModel.toggleStatus(for: item)
        #expect(viewModel.state == .loading)

        await controlledLoad.succeed(
            invocation: 2,
            with: [item]
        )
        await refresh.value

        let expectedItem = TodoItem(
            id: item.id,
            title: item.title,
            details: item.details,
            createdAt: item.createdAt,
            status: .completed
        )

        #expect(viewModel.state == .content([expectedItem]))
    }

    @Test
    func deleteDuringRefreshPreventsStaleLoadFromRestoringDeletedItem() async {
        let item = makeItem(title: "Refresh delete")
        let controlledLoad = ControlledLoad()
        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                try await controlledLoad.execute()
            },
            toggleTodoStatusUseCase: ToggleTodoStatusUseCaseStub(
                update: { _ in }
            ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        let initialLoad = Task {
            await viewModel.load()
        }
        await controlledLoad.waitForStartCount(1)
        await controlledLoad.succeed(
            invocation: 1,
            with: [item]
        )
        await initialLoad.value

        let refresh = Task {
            await viewModel.load()
        }
        await controlledLoad.waitForStartCount(2)

        await viewModel.delete(item)
        #expect(viewModel.state == .loading)

        await controlledLoad.succeed(
            invocation: 2,
            with: [item]
        )
        await refresh.value

        #expect(viewModel.state == .empty)
    }

    @Test
    func mutationDuringRefreshPreventsStaleFailureFromReplacingContent() async {
        let item = makeItem(title: "Refresh failure")
        let controlledLoad = ControlledLoad()
        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                try await controlledLoad.execute()
            },
            toggleTodoStatusUseCase: ToggleTodoStatusUseCaseStub(
                update: { _ in }
            ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        let initialLoad = Task {
            await viewModel.load()
        }
        await controlledLoad.waitForStartCount(1)
        await controlledLoad.succeed(
            invocation: 1,
            with: [item]
        )
        await initialLoad.value

        let refresh = Task {
            await viewModel.load()
        }
        await controlledLoad.waitForStartCount(2)

        await viewModel.toggleStatus(for: item)
        await controlledLoad.fail(invocation: 2)
        await refresh.value

        let expectedItem = TodoItem(
            id: item.id,
            title: item.title,
            details: item.details,
            createdAt: item.createdAt,
            status: .completed
        )

        #expect(viewModel.state == .content([expectedItem]))
    }

    @Test
    func searchFiltersItemsByTitleAndDetailsIgnoringCase() async {
        let firstItem = TodoItem(
            id: UUID(),
            title: "Buy Milk",
            details: "Two cartons",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )
        
        let secondItem = TodoItem(
            id: UUID(),
            title: "Clean apartment",
            details: "Kitchen and bathroom",
            createdAt: Date(
                timeIntervalSince1970: 1_800_000_000
            ),
            status: .completed
        )
        
        let useCase = LoadTodosUseCaseStub {
            [firstItem, secondItem]
        }
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )
        
        await viewModel.load()
        
        viewModel.updateSearchQuery("MILK")
        
        await waitForState(
            .content([firstItem]),
            in: viewModel
        )
        
        #expect(
            viewModel.state == .content([firstItem])
        )
        
        viewModel.updateSearchQuery("bathroom")
        
        await waitForState(
            .content([secondItem]),
            in: viewModel
        )
        
        #expect(
            viewModel.state == .content([secondItem])
        )
    }
    
    @Test
    func rapidSearchUpdatesPublishOnlyLatestResult() async {
        let firstItem = TodoItem(
            id: UUID(),
            title: "Buy milk",
            details: "Two cartons",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let secondItem = TodoItem(
            id: UUID(),
            title: "Clean apartment",
            details: "Kitchen and bathroom",
            createdAt: Date(
                timeIntervalSince1970: 1_800_000_000
            ),
            status: .completed
        )

        let viewModel = makeViewModel(
            items: [firstItem, secondItem]
        )

        await viewModel.load()

        var receivedStates: [
            TodoListViewModel.State
        ] = []

        await withCheckedContinuation { continuation in
            var didResume = false

            viewModel.onStateChange = { state in
                receivedStates.append(state)

                guard
                    !didResume,
                    state == .content([secondItem])
                else {
                    return
                }

                didResume = true
                continuation.resume()
            }

            viewModel.updateSearchQuery("milk")
            viewModel.updateSearchQuery("bathroom")
        }

        #expect(
            receivedStates == [
                .content([secondItem])
            ]
        )
    }

    @Test
    func clearingSearchRestoresAllLoadedItems() async {
        let items = [
            TodoItem(
                id: UUID(),
                title: "First task",
                details: "",
                createdAt: Date(
                    timeIntervalSince1970: 1_700_000_000
                ),
                status: .pending
            ),
            TodoItem(
                id: UUID(),
                title: "Second task",
                details: "",
                createdAt: Date(
                    timeIntervalSince1970: 1_800_000_000
                ),
                status: .completed
            )
        ]
        
        let useCase = LoadTodosUseCaseStub {
            items
        }
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )
        
        await viewModel.load()
        
        viewModel.updateSearchQuery("First")
        viewModel.updateSearchQuery("   ")
        
        #expect(viewModel.state == .content(items))
    }
    
    @Test
    func searchTransitionsToNoResultsWhenNothingMatches() async {
        let item = TodoItem(
            id: UUID(),
            title: "Buy milk",
            details: "Two cartons",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )
        
        let useCase = LoadTodosUseCaseStub {
            [item]
        }
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )
        
        await viewModel.load()
        
        viewModel.updateSearchQuery(
            "Something completely different"
        )

        await waitForState(
            .noResults,
            in: viewModel
        )

        #expect(viewModel.state == .noResults)
    }
    
    @Test
    func toggleStatusUpdatesItemAndPreservesSearch() async {
        let firstItem = TodoItem(
            id: UUID(),
            title: "Buy milk",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let secondItem = TodoItem(
            id: UUID(),
            title: "Clean apartment",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_800_000_000
            ),
            status: .pending
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                [firstItem, secondItem]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        await viewModel.load()
        viewModel.updateSearchQuery("milk")

        await waitForState(
            .content([firstItem]),
            in: viewModel
        )

        let expectedItem = TodoItem(
            id: firstItem.id,
            title: firstItem.title,
            details: firstItem.details,
            createdAt: firstItem.createdAt,
            status: .completed
        )

        await viewModel.toggleStatus(
            for: firstItem
        )

        await waitForState(
            .content([expectedItem]),
            in: viewModel
        )

        #expect(
            viewModel.state == .content([expectedItem])
        )
    }
    
    @Test
    func toggleStatusFailureKeepsCurrentItems() async {
        enum TestError: Error {
            case updateFailed
        }

        let item = TodoItem(
            id: UUID(),
            title: "Buy milk",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                [item]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in
                        throw TestError.updateFailed
                    }
                ),
            deleteTodoUseCase: DeleteTodoUseCaseStub(
                delete: { _ in }
            )
        )

        var receivedError:
            TodoListViewModel.ActionError?

        viewModel.onActionError = { error in
            receivedError = error
        }

        await viewModel.load()
        await viewModel.toggleStatus(for: item)

        #expect(viewModel.state == .content([item]))
        #expect(
            receivedError == .statusUpdateFailed
        )
    }
    
    @Test
    func deleteRemovesItemAndPreservesSearch() async {
        let firstItem = TodoItem(
            id: UUID(),
            title: "Buy milk",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let secondItem = TodoItem(
            id: UUID(),
            title: "Clean apartment",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_800_000_000
            ),
            status: .pending
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                [firstItem, secondItem]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase:
                DeleteTodoUseCaseStub(
                    delete: { _ in }
                )
        )

        await viewModel.load()
        viewModel.updateSearchQuery("clean")

        await waitForState(
            .content([secondItem]),
            in: viewModel
        )

        await viewModel.delete(secondItem)

        await waitForState(
            .noResults,
            in: viewModel
        )

        #expect(viewModel.state == .noResults)

        viewModel.updateSearchQuery("")

        #expect(
            viewModel.state == .content([firstItem])
        )
    }
    
    @Test
    func deleteLastItemTransitionsToEmpty() async {
        let item = TodoItem(
            id: UUID(),
            title: "Only task",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                [item]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase:
                DeleteTodoUseCaseStub(
                    delete: { _ in }
                )
        )

        await viewModel.load()
        await viewModel.delete(item)

        #expect(viewModel.state == .empty)
    }
    
    @Test
    func deleteFailureKeepsCurrentItems() async {
        enum TestError: Error {
            case deleteFailed
        }

        let item = TodoItem(
            id: UUID(),
            title: "Keep task",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCaseStub {
                [item]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCaseStub(
                    update: { _ in }
                ),
            deleteTodoUseCase:
                DeleteTodoUseCaseStub(
                    delete: { _ in
                        throw TestError.deleteFailed
                    }
                )
        )

        var receivedError:
            TodoListViewModel.ActionError?

        viewModel.onActionError = { error in
            receivedError = error
        }

        await viewModel.load()
        await viewModel.delete(item)

        #expect(
            viewModel.state == .content([item])
        )
        #expect(receivedError == .deleteFailed)
    }

    @Test
    func toggleCancellationKeepsCurrentItemsWithoutReportingFailure() async {
        let item = makeItem(title: "Cancelled toggle")
        let viewModel = makeViewModel(
            items: [item],
            update: { _ in
                throw CancellationError()
            }
        )
        var receivedError: TodoListViewModel.ActionError?
        viewModel.onActionError = { error in
            receivedError = error
        }

        await viewModel.load()
        await viewModel.toggleStatus(for: item)

        #expect(viewModel.state == .content([item]))
        #expect(receivedError == nil)
    }

    @Test
    func deleteCancellationKeepsCurrentItemsWithoutReportingFailure() async {
        let item = makeItem(title: "Cancelled delete")
        let viewModel = makeViewModel(
            items: [item],
            delete: { _ in
                throw CancellationError()
            }
        )
        var receivedError: TodoListViewModel.ActionError?
        viewModel.onActionError = { error in
            receivedError = error
        }

        await viewModel.load()
        await viewModel.delete(item)

        #expect(viewModel.state == .content([item]))
        #expect(receivedError == nil)
    }

    @Test
    func repeatedToggleReportsOperationInProgressWithoutSecondUpdate() async {
        let item = makeItem(title: "Single toggle")
        let mutation = SuspendedMutation(
            suspendedIDs: [item.id]
        )
        let viewModel = makeViewModel(
            items: [item],
            update: { item in
                await mutation.execute(id: item.id)
            }
        )
        var receivedErrors: [TodoListViewModel.ActionError] = []

        viewModel.onActionError = { error in
            receivedErrors.append(error)
        }

        await viewModel.load()

        let firstToggle = Task {
            await viewModel.toggleStatus(for: item)
        }

        await mutation.waitForStartCount(1)
        await viewModel.toggleStatus(for: item)

        #expect(await mutation.invocationCount(for: item.id) == 1)
        #expect(receivedErrors == [.operationInProgress])

        await mutation.release(id: item.id)
        await firstToggle.value
    }

    @Test
    func deleteDuringPendingToggleReportsOperationInProgressWithoutDelete() async {
        let item = makeItem(title: "Toggle before delete")
        let mutation = SuspendedMutation(
            suspendedIDs: [item.id]
        )
        let deleteCallCount = Mutex(0)
        let viewModel = makeViewModel(
            items: [item],
            update: { item in
                await mutation.execute(id: item.id)
            },
            delete: { _ in
                deleteCallCount.withLock {
                    $0 += 1
                }
            }
        )
        var receivedErrors: [TodoListViewModel.ActionError] = []

        viewModel.onActionError = { error in
            receivedErrors.append(error)
        }

        await viewModel.load()

        let toggle = Task {
            await viewModel.toggleStatus(for: item)
        }

        await mutation.waitForStartCount(1)
        await viewModel.delete(item)

        #expect(deleteCallCount.withLock { $0 } == 0)
        #expect(receivedErrors == [.operationInProgress])

        await mutation.release(id: item.id)
        await toggle.value
    }

    @Test
    func toggleDuringPendingDeleteReportsOperationInProgressWithoutUpdate() async {
        let item = makeItem(title: "Delete before toggle")
        let mutation = SuspendedMutation(
            suspendedIDs: [item.id]
        )
        let updateCallCount = Mutex(0)
        let viewModel = makeViewModel(
            items: [item],
            update: { _ in
                updateCallCount.withLock {
                    $0 += 1
                }
            },
            delete: { id in
                await mutation.execute(id: id)
            }
        )
        var receivedErrors: [TodoListViewModel.ActionError] = []

        viewModel.onActionError = { error in
            receivedErrors.append(error)
        }

        await viewModel.load()

        let delete = Task {
            await viewModel.delete(item)
        }

        await mutation.waitForStartCount(1)
        await viewModel.toggleStatus(for: item)

        #expect(updateCallCount.withLock { $0 } == 0)
        #expect(receivedErrors == [.operationInProgress])

        await mutation.release(id: item.id)
        await delete.value
        #expect(viewModel.state == .empty)
    }

    @Test
    func mutationsForDifferentItemsRunIndependently() async {
        let firstItem = makeItem(title: "First task")
        let secondItem = makeItem(title: "Second task")
        let mutation = SuspendedMutation(
            suspendedIDs: [firstItem.id]
        )
        let viewModel = makeViewModel(
            items: [firstItem, secondItem],
            update: { item in
                await mutation.execute(id: item.id)
            }
        )

        await viewModel.load()

        let firstToggle = Task {
            await viewModel.toggleStatus(for: firstItem)
        }

        await mutation.waitForStartCount(1)
        await viewModel.toggleStatus(for: secondItem)

        #expect(
            await mutation.startedItemIDs()
                == [firstItem.id, secondItem.id]
        )

        await mutation.release(id: firstItem.id)
        await firstToggle.value
    }

    @Test
    func failedMutationClearsProcessingStateForRetry() async {
        enum TestError: Error {
            case updateFailed
        }

        let item = makeItem(title: "Retry mutation")
        let updateAttemptCount = Mutex(0)
        let viewModel = makeViewModel(
            items: [item],
            update: { _ in
                let attempt = updateAttemptCount.withLock { count in
                    count += 1
                    return count
                }

                if attempt == 1 {
                    throw TestError.updateFailed
                }
            }
        )

        await viewModel.load()
        await viewModel.toggleStatus(for: item)
        await viewModel.toggleStatus(for: item)

        #expect(updateAttemptCount.withLock { $0 } == 2)
        #expect(
            viewModel.state == .content([
                TodoItem(
                    id: item.id,
                    title: item.title,
                    details: item.details,
                    createdAt: item.createdAt,
                    status: .completed
                )
            ])
        )
    }

    @Test
    func deleteAfterToggleCompletionRemovesUpdatedItem() async {
        let item = makeItem(title: "Delete after toggle")
        let mutation = SuspendedMutation(
            suspendedIDs: [item.id]
        )
        let viewModel = makeViewModel(
            items: [item],
            update: { item in
                await mutation.execute(id: item.id)
            }
        )

        await viewModel.load()

        let toggle = Task {
            await viewModel.toggleStatus(for: item)
        }

        await mutation.waitForStartCount(1)
        await mutation.release(id: item.id)
        await toggle.value

        let updatedItem = TodoItem(
            id: item.id,
            title: item.title,
            details: item.details,
            createdAt: item.createdAt,
            status: .completed
        )

        await viewModel.delete(updatedItem)

        #expect(viewModel.state == .empty)
    }

    private func makeItem(title: String) -> TodoItem {
        TodoItem(
            id: UUID(),
            title: title,
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )
    }
}
