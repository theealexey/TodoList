import Foundation
import Testing
@testable import TodoList

@Suite
struct CreateTodoUseCaseTests {

    private actor CreateSpy {

        private var receivedItems: [TodoItem] = []

        func create(_ item: TodoItem) {
            receivedItems.append(item)
        }

        func items() -> [TodoItem] {
            receivedItems
        }
    }

    @Test
    func executeCreatesPendingTodoWithNormalizedInput() async throws {
        let id = try #require(
            UUID(
                uuidString:
                    "11111111-1111-1111-1111-111111111111"
            )
        )

        let createdAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let spy = CreateSpy()

        let useCase = CreateTodoUseCase(
            create: { item in
                await spy.create(item)
            },
            makeID: { id },
            currentDate: { createdAt }
        )

        let item = try await useCase.execute(
            title: "  Buy milk \n",
            details: "  Two cartons  "
        )

        let expectedItem = TodoItem(
            id: id,
            title: "Buy milk",
            details: "Two cartons",
            createdAt: createdAt,
            status: .pending
        )

        let receivedItems = await spy.items()

        #expect(item == expectedItem)
        #expect(receivedItems == [expectedItem])
    }

    @Test
    func executeRejectsBlankTitleWithoutCreatingTodo() async {
        let spy = CreateSpy()

        let useCase = CreateTodoUseCase(
            create: { item in
                await spy.create(item)
            }
        )

        do {
            _ = try await useCase.execute(
                title: " \n ",
                details: "Details"
            )

            Issue.record(
                "Expected an empty title error"
            )
        } catch let error as CreateTodoUseCaseError {
            #expect(error == .emptyTitle)
        } catch {
            Issue.record(
                "Received unexpected error: \(error)"
            )
        }

        let receivedItems = await spy.items()

        #expect(receivedItems.isEmpty)
    }
}
