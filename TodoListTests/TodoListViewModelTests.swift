import Foundation
import Testing
@testable import TodoList

@Suite
@MainActor
struct TodoListViewModelTests {
    
    private enum TestError: Error {
        case loadingFailed
    }
    
    private func makeViewModel(
        items: [TodoItem],
        update: @escaping ToggleTodoStatusUseCase.Update = { _ in }
    ) -> TodoListViewModel {
        TodoListViewModel(
            loadTodosUseCase: LoadTodosUseCase {
                items
            },
            toggleTodoStatusUseCase:
                ToggleTodoStatusUseCase(
                    update: update
                )
        )
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
                toggleTodoStatusUseCase
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
                )
        )
        
        await viewModel.load()
        
        viewModel.updateSearchQuery("MILK")
        
        #expect(
            viewModel.state == .content([firstItem])
        )
        
        viewModel.updateSearchQuery("bathroom")
        
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
                )
        )
        
        await viewModel.load()
        
        viewModel.updateSearchQuery(
            "Something completely different"
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
                )
        )

        await viewModel.load()
        viewModel.updateSearchQuery("milk")

        await viewModel.toggleStatus(
            for: firstItem
        )

        let expectedItem = TodoItem(
            id: firstItem.id,
            title: firstItem.title,
            details: firstItem.details,
            createdAt: firstItem.createdAt,
            status: .completed
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
}
