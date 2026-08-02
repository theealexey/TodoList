import Foundation
import Testing
@testable import TodoList

@Suite
struct TodoEditorViewModelTests {

    private actor CreateSpy {

        struct Call: Equatable {
            let title: String
            let details: String
        }

        private var receivedCalls: [Call] = []

        func record(
            title: String,
            details: String
        ) {
            receivedCalls.append(
                Call(
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
        let expectedDate = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let viewModel = TodoEditorViewModel(
            mode: .create(
                createdAt: expectedDate
            ),
            create: { _, _ in
                throw TestError.unexpectedCall
            },
            update: { _, _, _ in
                throw TestError.unexpectedCall
            }
        )

        #expect(
            viewModel.initialContent ==
                TodoEditorViewModel.InitialContent(
                    title: "",
                    details: "",
                    createdAt: expectedDate
                )
        )
    }

    @Test
    @MainActor
    func editModeProvidesExistingTodoContent() {
        let item = Self.makeItem()

        let viewModel = TodoEditorViewModel(
            mode: .edit(item),
            create: { _, _ in
                throw TestError.unexpectedCall
            },
            update: { _, _, _ in
                throw TestError.unexpectedCall
            }
        )

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
    func saveInCreateModeUsesCreateDependency() async {
        let expectedItem = Self.makeItem()
        let spy = CreateSpy()

        let viewModel = TodoEditorViewModel(
            mode: .create(
                createdAt: expectedItem.createdAt
            ),
            create: { title, details in
                await spy.record(
                    title: title,
                    details: details
                )

                return expectedItem
            },
            update: { _, _, _ in
                throw TestError.unexpectedCall
            }
        )

        var receivedStates: [
            TodoEditorViewModel.State
        ] = []

        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.save(
            title: "New title",
            details: "New details"
        )

        let calls = await spy.calls()

        #expect(
            calls == [
                CreateSpy.Call(
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
            create: { _, _ in
                throw TestError.unexpectedCall
            },
            update: { item, title, details in
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

        let calls = await spy.calls()

        #expect(
            calls == [
                UpdateSpy.Call(
                    item: originalItem,
                    title: "Updated title",
                    details: "Updated details"
                )
            ]
        )

        #expect(
            viewModel.state == .saved(
                updatedItem
            )
        )
    }

    @Test
    @MainActor
    func createValidationErrorTransitionsToValidationFailure() async {
        let viewModel = TodoEditorViewModel(
            mode: .create(
                createdAt: Date(
                    timeIntervalSince1970:
                        1_700_000_000
                )
            ),
            create: { _, _ in
                throw CreateTodoUseCaseError.emptyTitle
            },
            update: { _, _, _ in
                throw TestError.unexpectedCall
            }
        )

        await viewModel.save(
            title: "",
            details: ""
        )

        #expect(
            viewModel.state ==
                .validationFailure
        )
    }

    @Test
    @MainActor
    func updateValidationErrorTransitionsToValidationFailure() async {
        let viewModel = TodoEditorViewModel(
            mode: .edit(Self.makeItem()),
            create: { _, _ in
                throw TestError.unexpectedCall
            },
            update: { _, _, _ in
                throw UpdateTodoUseCaseError.emptyTitle
            }
        )

        await viewModel.save(
            title: "",
            details: ""
        )

        #expect(
            viewModel.state ==
                .validationFailure
        )
    }

    @Test
    @MainActor
    func unexpectedErrorTransitionsToFailure() async {
        let viewModel = TodoEditorViewModel(
            mode: .edit(Self.makeItem()),
            create: { _, _ in
                throw TestError.unexpectedCall
            },
            update: { _, _, _ in
                throw TestError.storageFailed
            }
        )

        await viewModel.save(
            title: "Updated title",
            details: ""
        )

        #expect(
            viewModel.state == .failure
        )
    }

    private static func makeItem() -> TodoItem {
        TodoItem(
            id: UUID(
                uuidString:
                    "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
            ) ?? UUID(),
            title: "Original title",
            details: "Original details",
            createdAt: Date(
                timeIntervalSince1970:
                    1_700_000_000
            ),
            status: .completed
        )
    }

    private enum TestError: Error {
        case unexpectedCall
        case storageFailed
    }
}
