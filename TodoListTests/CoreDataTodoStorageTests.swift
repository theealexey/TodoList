import CoreData
import Foundation
import Testing
@testable import TodoList

private struct StoredTodoSnapshot: Equatable, Sendable {
    let id: UUID?
    let title: String?
    let details: String?
    let createdAt: Date?
    let isCompleted: Bool
}

struct CoreDataTodoStorageTests {

    @Test
    func createSavesTodoInPersistentStore() async throws {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        let id = UUID()
        let createdAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let item = TodoItem(
            id: id,
            title: "Prepare test task",
            details: "Verify Core Data persistence",
            createdAt: createdAt,
            status: .pending
        )

        try await storage.create(item)

        let snapshots: [StoredTodoSnapshot] =
            try await withCheckedThrowingContinuation { continuation in
                stack.container.performBackgroundTask { context in
                    do {
                        let request = NSFetchRequest<StoredTodo>(
                            entityName: "StoredTodo"
                        )

                        let storedTodos = try context.fetch(request)

                        let snapshots = storedTodos.map {
                            StoredTodoSnapshot(
                                id: $0.id,
                                title: $0.title,
                                details: $0.details,
                                createdAt: $0.createdAt,
                                isCompleted: $0.isCompleted
                            )
                        }

                        continuation.resume(returning: snapshots)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

        let expected = StoredTodoSnapshot(
            id: id,
            title: item.title,
            details: item.details,
            createdAt: createdAt,
            isCompleted: false
        )

        #expect(snapshots == [expected])
    }
}
