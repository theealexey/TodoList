import Foundation
import Testing
@testable import TodoList

@Suite
@MainActor
struct CreateTodoViewModelTests {

    private enum TestError: Error {
        case savingFailed
    }

    @Test
    func saveTransitionsFromSavingToSaved() async throws {
        let expectedItem = TodoItem(
            id: UUID(),
            title: "Buy milk",
            details: "Two cartons",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let useCase = CreateTodoUseCase(
            create: { _ in },
            makeID: { expectedItem.id },
            currentDate: { expectedItem.createdAt }
        )

        let viewModel = CreateTodoViewModel(
            createTodoUseCase: useCase
        )

        var receivedStates: [CreateTodoViewModel.State] = []

        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.save(
            title: expectedItem.title,
            details: expectedItem.details
        )

        #expect(
            receivedStates == [
                .saving,
                .saved(expectedItem)
            ]
        )

        #expect(viewModel.state == .saved(expectedItem))
    }

    @Test
    func saveTransitionsToValidationFailureForBlankTitle() async {
        let useCase = CreateTodoUseCase(
            create: { _ in
                Issue.record(
                    "Create operation must not be called"
                )
            }
        )

        let viewModel = CreateTodoViewModel(
            createTodoUseCase: useCase
        )

        var receivedStates: [CreateTodoViewModel.State] = []

        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.save(
            title: " \n ",
            details: "Details"
        )

        #expect(
            receivedStates == [
                .saving,
                .validationFailure
            ]
        )

        #expect(viewModel.state == .validationFailure)
    }

    @Test
    func saveTransitionsToFailureWhenStorageFails() async {
        let useCase = CreateTodoUseCase(
            create: { _ in
                throw TestError.savingFailed
            }
        )

        let viewModel = CreateTodoViewModel(
            createTodoUseCase: useCase
        )

        var receivedStates: [CreateTodoViewModel.State] = []

        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.save(
            title: "Buy milk",
            details: ""
        )

        #expect(
            receivedStates == [
                .saving,
                .failure
            ]
        )

        #expect(viewModel.state == .failure)
    }
}
