import Foundation
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

@Suite
@MainActor
struct TodoListViewModelTests {
    
    private enum TestError: Error {
        case loadingFailed
    }
    
    private func makeViewModel(
        items: [TodoItem],
        update: @escaping ToggleTodoStatusUseCase.Update = { _ in },
        delete: @escaping DeleteTodoUseCase.Delete = { _ in }
    ) -> TodoListViewModel {
        TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCase {
                items
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: update
                ),
            deleteTodoUseCase:
                DeleteTodoUseCase(
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

        let loadTodosUseCase = LoadTodosUseCase {
            expectedItems
        }

        let toggleTodoStatusUseCase =
            ToggleTodoStatusUseCase(
                update: { _ in }
            )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: loadTodosUseCase,
            toggleTodoStatusUseCase:
                toggleTodoStatusUseCase,
            deleteTodoUseCase: DeleteTodoUseCase(
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
        let useCase = LoadTodosUseCase(
            load: {
                []
            }
        )
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCase(
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
        let useCase = LoadTodosUseCase(
            load: { () async throws -> [TodoItem] in
                throw TestError.loadingFailed
            }
        )
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCase(
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
        
        let useCase = LoadTodosUseCase {
            [firstItem, secondItem]
        }
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCase(
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
        
        let useCase = LoadTodosUseCase {
            items
        }
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCase(
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
        
        let useCase = LoadTodosUseCase {
            [item]
        }
        
        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase,
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCase(
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
            loadTodosUseCase: LoadTodosUseCase {
                [firstItem, secondItem]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase: DeleteTodoUseCase(
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
            loadTodosUseCase: LoadTodosUseCase {
                [item]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in
                        throw TestError.updateFailed
                    }
                ),
            deleteTodoUseCase: DeleteTodoUseCase(
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
            loadTodosUseCase: LoadTodosUseCase {
                [firstItem, secondItem]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase:
                DeleteTodoUseCase(
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
            loadTodosUseCase: LoadTodosUseCase {
                [item]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase:
                DeleteTodoUseCase(
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
            loadTodosUseCase: LoadTodosUseCase {
                [item]
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: { _ in }
                ),
            deleteTodoUseCase:
                DeleteTodoUseCase(
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
        var deleteCallCount = 0
        let viewModel = makeViewModel(
            items: [item],
            update: { item in
                await mutation.execute(id: item.id)
            },
            delete: { _ in
                deleteCallCount += 1
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

        #expect(deleteCallCount == 0)
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
        var updateCallCount = 0
        let viewModel = makeViewModel(
            items: [item],
            update: { _ in
                updateCallCount += 1
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

        #expect(updateCallCount == 0)
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
        var updateAttemptCount = 0
        let viewModel = makeViewModel(
            items: [item],
            update: { _ in
                updateAttemptCount += 1

                if updateAttemptCount == 1 {
                    throw TestError.updateFailed
                }
            }
        )

        await viewModel.load()
        await viewModel.toggleStatus(for: item)
        await viewModel.toggleStatus(for: item)

        #expect(updateAttemptCount == 2)
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
