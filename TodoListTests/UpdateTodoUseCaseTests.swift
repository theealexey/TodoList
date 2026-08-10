import Foundation
import Testing
@testable import TodoList

@Suite
struct UpdateTodoUseCaseTests {

    private actor UpdateSpy {

        private var receivedItems: [TodoItem] = []

        func update(_ item: TodoItem) {
            receivedItems.append(item)
        }

        func items() -> [TodoItem] {
            receivedItems
        }
    }

    @Test
    func executeUpdatesTextAndPreservesTodoIdentity() async throws {
        let originalItem = TodoItem(
            id: UUID(),
            title: "Old title",
            details: "Old details",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .completed
        )

        let spy = UpdateSpy()

        let useCase = UpdateTodoUseCase(
            update: { item in
                await spy.update(item)
            }
        )

        let updatedItem = try await useCase.execute(
            item: originalItem,
            title: "  New title  ",
            details: "  New details  "
        )

        #expect(updatedItem.id == originalItem.id)
        #expect(updatedItem.title == "New title")
        #expect(updatedItem.details == "New details")
        #expect(updatedItem.createdAt == originalItem.createdAt)
        #expect(updatedItem.status == originalItem.status)

        let receivedItems = await spy.items()

        #expect(receivedItems == [updatedItem])
    }

    @Test
    func executeRejectsBlankTitleWithoutUpdatingTodo() async {
        let originalItem = TodoItem(
            id: UUID(),
            title: "Original title",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let spy = UpdateSpy()

        let useCase = UpdateTodoUseCase(
            update: { item in
                await spy.update(item)
            }
        )

        do {
            _ = try await useCase.execute(
                item: originalItem,
                title: "   \n ",
                details: "Details"
            )

            Issue.record(
                "Expected emptyTitle error"
            )
        } catch let error as UpdateTodoUseCaseError {
            #expect(error == .emptyTitle)
        } catch {
            Issue.record(
                "Received unexpected error: \(error)"
            )
        }

        let receivedItems = await spy.items()

        #expect(receivedItems.isEmpty)
    }

    @Test
    func executePropagatesUpdateError() async {
        enum TestError: Error, Equatable {
            case updateFailed
        }

        let originalItem = TodoItem(
            id: UUID(),
            title: "Original title",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let useCase = UpdateTodoUseCase(
            update: { _ in
                throw TestError.updateFailed
            }
        )

        do {
            _ = try await useCase.execute(
                item: originalItem,
                title: "Updated title",
                details: ""
            )

            Issue.record(
                "Expected updateFailed error"
            )
        } catch let error as TestError {
            #expect(error == .updateFailed)
        } catch {
            Issue.record(
                "Received unexpected error: \(error)"
            )
        }
    }
}
