import Foundation
import Testing
@testable import TodoList

@Suite
@MainActor
struct TodoListViewModelTests {

    private enum TestError: Error {
        case loadingFailed
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

        let useCase = LoadTodosUseCase(
            load: {
                expectedItems
            }
        )

        let viewModel = TodoListViewModel(
            loadTodosUseCase: useCase
        )

        var receivedStates: [TodoListViewModel.State] = []

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
            viewModel.state == .content(expectedItems)
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
            loadTodosUseCase: useCase
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
            loadTodosUseCase: useCase
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
}
