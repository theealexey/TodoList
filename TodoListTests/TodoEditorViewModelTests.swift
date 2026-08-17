import Foundation
import Testing
@testable import TodoList

@Suite
struct TodoEditorViewModelTests {

    private actor CreateSpy {
        struct Call: Equatable {
            let draft: NewTodoDraft
            let title: String
            let details: String
        }

        private var receivedCalls: [Call] = []

        func record(
            draft: NewTodoDraft,
            title: String,
            details: String
        ) {
            receivedCalls.append(
                Call(
                    draft: draft,
                    title: title,
                    details: details
                )
            )
        }

        func calls() -> [Call] {
            receivedCalls
        }
    }

    private actor UpdateSpy {
        struct Call: Equatable {
            let item: TodoItem
            let title: String
            let details: String
        }

        private var receivedCalls: [Call] = []

        func record(
            item: TodoItem,
            title: String,
            details: String
        ) {
            receivedCalls.append(
                Call(
                    item: item,
                    title: title,
                    details: details
                )
            )
        }

        func calls() -> [Call] {
            receivedCalls
        }
    }

    @Test
    @MainActor
    func createModeProvidesEmptyInitialContent() {
        let draft = Self.makeDraft()
        let viewModel = makeViewModel(
            mode: .create(draft)
        )

        #expect(
            viewModel.initialContent ==
                TodoEditorViewModel.InitialContent(
                    title: "",
                    details: "",
                    createdAt: draft.createdAt
                )
        )
    }

    @Test
    @MainActor
    func editModeProvidesExistingTodoContent() {
        let item = Self.makeItem()
        let viewModel = makeViewModel(mode: .edit(item))

        #expect(
            viewModel.initialContent ==
                TodoEditorViewModel.InitialContent(
                    title: item.title,
                    details: item.details,
                    createdAt: item.createdAt
                )
        )
    }

    @Test
    @MainActor
    func createModeWhitespaceOnlyInputHasNoChanges() {
        let viewModel = makeViewModel(
            mode: .create(Self.makeDraft())
        )

        #expect(
            !viewModel.hasChanges(
                title: "  \n ",
                details: "   "
            )
        )
    }

    @Test
    @MainActor
    func editModeNormalizedOriginalContentHasNoChanges() {
        let item = Self.makeItem()
        let viewModel = makeViewModel(mode: .edit(item))

        #expect(
            !viewModel.hasChanges(
                title: "  \(item.title)  ",
                details: "  \(item.details)  "
            )
        )
    }

    @Test
    @MainActor
    func editModeChangedContentReportsChanges() {
        let viewModel = makeViewModel(
            mode: .edit(Self.makeItem())
        )

        #expect(
            viewModel.hasChanges(
                title: "Changed title",
                details: "Original details"
            )
        )
    }

    @Test
    @MainActor
    func saveInCreateModeUsesCreateDependency() async {
        let draft = Self.makeDraft()
        let expectedItem = Self.makeItem(
            id: draft.id,
            createdAt: draft.createdAt
        )
        let spy = CreateSpy()

        let viewModel = TodoEditorViewModel(
            mode: .create(draft),
            createTodoUseCase: CreateTodoUseCaseStub(draft: draft) {
                receivedDraft,
                title,
                details in

                await spy.record(
                    draft: receivedDraft,
                    title: title,
                    details: details
                )
                return expectedItem
            },
            updateTodoUseCase: UpdateTodoUseCaseStub { _, _, _ in
                throw TestError.unexpectedCall
            }
        )

        var receivedStates: [TodoEditorViewModel.State] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.save(
            title: "New title",
            details: "New details"
        )

        #expect(
            await spy.calls() == [
                CreateSpy.Call(
                    draft: draft,
                    title: "New title",
                    details: "New details"
                )
            ]
        )
        #expect(
            receivedStates == [
                .saving,
                .saved(expectedItem)
            ]
        )
    }

    @Test
    @MainActor
    func saveInEditModeUsesUpdateDependency() async {
        let originalItem = Self.makeItem()
        let updatedItem = TodoItem(
            id: originalItem.id,
            title: "Updated title",
            details: "Updated details",
            createdAt: originalItem.createdAt,
            status: originalItem.status
        )
        let spy = UpdateSpy()

        let viewModel = TodoEditorViewModel(
            mode: .edit(originalItem),
            createTodoUseCase: CreateTodoUseCaseStub { _, _, _ in
                throw TestError.unexpectedCall
            },
            updateTodoUseCase: UpdateTodoUseCaseStub { item, title, details in
                await spy.record(
                    item: item,
                    title: title,
                    details: details
                )
                return updatedItem
            }
        )

        await viewModel.save(
            title: "Updated title",
            details: "Updated details"
        )

        #expect(
            await spy.calls() == [
                UpdateSpy.Call(
                    item: originalItem,
                    title: "Updated title",
                    details: "Updated details"
                )
            ]
        )
        #expect(viewModel.state == .saved(updatedItem))
    }

    @Test
    @MainActor
    func createValidationErrorTransitionsToValidationFailure() async {
        let draft = Self.makeDraft()
        let viewModel = TodoEditorViewModel(
            mode: .create(draft),
            createTodoUseCase: CreateTodoUseCaseStub(draft: draft) { _, _, _ in
                throw CreateTodoUseCaseError.emptyTitle
            },
            updateTodoUseCase: UpdateTodoUseCaseStub { _, _, _ in
                throw TestError.unexpectedCall
            }
        )

        await viewModel.save(title: "", details: "")

        #expect(viewModel.state == .validationFailure)
    }

    @Test
    @MainActor
    func updateValidationErrorTransitionsToValidationFailure() async {
        let viewModel = TodoEditorViewModel(
            mode: .edit(Self.makeItem()),
            createTodoUseCase: CreateTodoUseCaseStub { _, _, _ in
                throw TestError.unexpectedCall
            },
            updateTodoUseCase: UpdateTodoUseCaseStub { _, _, _ in
                throw UpdateTodoUseCaseError.emptyTitle
            }
        )

        await viewModel.save(title: "", details: "")

        #expect(viewModel.state == .validationFailure)
    }

    @Test
    @MainActor
    func unexpectedErrorTransitionsToFailure() async {
        let viewModel = TodoEditorViewModel(
            mode: .edit(Self.makeItem()),
            createTodoUseCase: CreateTodoUseCaseStub { _, _, _ in
                throw TestError.unexpectedCall
            },
            updateTodoUseCase: UpdateTodoUseCaseStub { _, _, _ in
                throw TestError.storageFailed
            }
        )

        await viewModel.save(
            title: "Updated title",
            details: ""
        )

        #expect(viewModel.state == .failure)
    }

    @MainActor
    private func makeViewModel(
        mode: TodoEditorViewModel.Mode
    ) -> TodoEditorViewModel {
        TodoEditorViewModel(
            mode: mode,
            createTodoUseCase: CreateTodoUseCaseStub { _, _, _ in
                throw TestError.unexpectedCall
            },
            updateTodoUseCase: UpdateTodoUseCaseStub { _, _, _ in
                throw TestError.unexpectedCall
            }
        )
    }

    private static func makeDraft() -> NewTodoDraft {
        NewTodoDraft(
            id: UUID(
                uuidString: "11111111-1111-1111-1111-111111111111"
            ) ?? UUID(),
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            )
        )
    }

    private static func makeItem(
        id: UUID = UUID(
            uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        ) ?? UUID(),
        createdAt: Date = Date(
            timeIntervalSince1970: 1_700_000_000
        )
    ) -> TodoItem {
        TodoItem(
            id: id,
            title: "Original title",
            details: "Original details",
            createdAt: createdAt,
            status: .completed
        )
    }

    private enum TestError: Error {
        case unexpectedCall
        case storageFailed
    }
}
