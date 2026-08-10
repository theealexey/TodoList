import Foundation
import Testing
@testable import TodoList

@Suite
struct ToggleTodoStatusUseCaseTests {

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
    func executeChangesPendingTodoToCompleted() async throws {
        let item = TodoItem(
            id: UUID(),
            title: "Buy milk",
            details: "Two cartons",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let spy = UpdateSpy()

        let useCase = ToggleTodoStatusUseCase(
            update: { updatedItem in
                await spy.update(updatedItem)
            }
        )

        let updatedItem = try await useCase.execute(
            item: item
        )

        let receivedItems = await spy.items()

        #expect(updatedItem.status == .completed)
        #expect(updatedItem.id == item.id)
        #expect(updatedItem.title == item.title)
        #expect(updatedItem.details == item.details)
        #expect(updatedItem.createdAt == item.createdAt)
        #expect(receivedItems == [updatedItem])
    }

    @Test
    func executeChangesCompletedTodoToPending() async throws {
        let item = TodoItem(
            id: UUID(),
            title: "Completed task",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .completed
        )

        let useCase = ToggleTodoStatusUseCase(
            update: { _ in }
        )

        let updatedItem = try await useCase.execute(
            item: item
        )

        #expect(updatedItem.status == .pending)
    }
}
