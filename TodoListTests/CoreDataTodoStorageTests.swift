import CoreData
import Foundation
import Testing
@testable import TodoList

private struct StoredTodoSnapshot: Equatable, Sendable {
    let id: UUID?
    let remoteID: Int64
    let title: String?
    let details: String?
    let createdAt: Date?
    let isCompleted: Bool
}

struct CoreDataTodoStorageTests {

    @Test
    func createSavesTodoInPersistentStore() async throws {
        let (stack, storage) = try await makeStorage()

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

        let storedSnapshots = try await snapshots(
            in: stack
        )

        let expected = StoredTodoSnapshot(
            id: id,
            remoteID: 0,
            title: item.title,
            details: item.details,
            createdAt: createdAt,
            isCompleted: false
        )

        #expect(storedSnapshots == [expected])
    }

    @Test
    func fetchAllReturnsMappedDomainItems() async throws {
        let (_, storage) = try await makeStorage()

        let item = TodoItem(
            id: UUID(),
            title: "Read stored task",
            details: "Verify StoredTodo mapping",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .completed
        )

        try await storage.create(item)

        let fetchedItems = try await storage.fetchAll()

        #expect(fetchedItems == [item])
    }

    @Test
    func fetchAllReturnsNewestTodosFirst() async throws {
        let (_, storage) = try await makeStorage()

        let oldestItem = TodoItem(
            id: UUID(),
            title: "Oldest task",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let newestItem = TodoItem(
            id: UUID(),
            title: "Newest task",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_900_000_000
            ),
            status: .pending
        )

        let middleItem = TodoItem(
            id: UUID(),
            title: "Middle task",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_800_000_000
            ),
            status: .pending
        )

        try await storage.create(oldestItem)
        try await storage.create(newestItem)
        try await storage.create(middleItem)

        let items = try await storage.fetchAll()

        #expect(
            items == [
                newestItem,
                middleItem,
                oldestItem
            ]
        )
    }

    @Test
    func fetchAllUsesIDAsTieBreakerForEqualCreationDates() async throws {
        let (_, storage) = try await makeStorage()

        let firstID = try #require(
            UUID(
                uuidString:
                    "00000000-0000-0000-0000-000000000001"
            )
        )

        let secondID = try #require(
            UUID(
                uuidString:
                    "00000000-0000-0000-0000-000000000002"
            )
        )

        let createdAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let firstItem = TodoItem(
            id: firstID,
            title: "First deterministic task",
            details: "",
            createdAt: createdAt,
            status: .pending
        )

        let secondItem = TodoItem(
            id: secondID,
            title: "Second deterministic task",
            details: "",
            createdAt: createdAt,
            status: .pending
        )

        try await storage.create(secondItem)
        try await storage.create(firstItem)

        let items = try await storage.fetchAll()

        #expect(
            items == [
                firstItem,
                secondItem
            ]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func alreadyCancelledFetchThrowsCancellationError() async throws {
        let (_, storage) = try await makeStorage()

        let result = await Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }

            return try await storage.fetchAll()
        }.result

        #expect(throws: CancellationError.self) {
            try result.get()
        }
    }

    @Test
    func importTodosStoresRemoteData() async throws {
        let (stack, storage) = try await makeStorage()

        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        try await storage.importTodos(
            [
                TodoImportRecord(
                    remoteID: 42,
                    title: "Imported task",
                    isCompleted: true
                )
            ],
            importedAt: importedAt
        )

        let storedSnapshots = try await snapshots(
            in: stack
        )

        let snapshot = try #require(
            storedSnapshots.first
        )

        #expect(storedSnapshots.count == 1)
        #expect(snapshot.id != nil)
        #expect(snapshot.remoteID == 42)
        #expect(snapshot.title == "Imported task")
        #expect(snapshot.details == "")
        #expect(snapshot.createdAt == importedAt)
        #expect(snapshot.isCompleted)
    }

    @Test
    func importTodosDoesNotDuplicateExistingRemoteID()
        async throws {
        let (_, storage) = try await makeStorage()

        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        try await storage.importTodos(
            [
                TodoImportRecord(
                    remoteID: 42,
                    title: "Imported task",
                    isCompleted: false
                )
            ],
            importedAt: importedAt
        )

        try await storage.importTodos(
            [
                TodoImportRecord(
                    remoteID: 42,
                    title: "Changed remote title",
                    isCompleted: true
                )
            ],
            importedAt: importedAt
        )

        let items = try await storage.fetchAll()
        let item = try #require(items.first)

        #expect(items.count == 1)
        #expect(item.title == "Imported task")
        #expect(item.status == .pending)
    }

    @Test
    func importTodosStoresUniqueRemoteRecords() async throws {
        let (_, storage) = try await makeStorage()

        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let records = [
            TodoImportRecord(
                remoteID: 1,
                title: "First task",
                isCompleted: false
            ),
            TodoImportRecord(
                remoteID: 2,
                title: "Second task",
                isCompleted: true
            ),
            TodoImportRecord(
                remoteID: 1,
                title: "Changed first task",
                isCompleted: true
            )
        ]

        try await storage.importTodos(
            records,
            importedAt: importedAt
        )

        let items = try await storage.fetchAll()

        #expect(items.count == 2)

        #expect(
            items.contains {
                $0.title == "First task"
                    && $0.status == .pending
            }
        )

        #expect(
            items.contains {
                $0.title == "Second task"
                    && $0.status == .completed
            }
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func concurrentImportsDeduplicateOverlappingRemoteIDs() async throws {
        let (stack, storage) = try await makeStorage()

        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let firstRecords = [
            TodoImportRecord(
                remoteID: 42,
                title: "First shared task",
                isCompleted: false
            ),
            TodoImportRecord(
                remoteID: 43,
                title: "First unique task",
                isCompleted: false
            )
        ]

        let secondRecords = [
            TodoImportRecord(
                remoteID: 42,
                title: "Second shared task",
                isCompleted: true
            ),
            TodoImportRecord(
                remoteID: 44,
                title: "Second unique task",
                isCompleted: true
            )
        ]

        async let firstImport: Void = storage.importTodos(
            firstRecords,
            importedAt: importedAt
        )

        async let secondImport: Void = storage.importTodos(
            secondRecords,
            importedAt: importedAt
        )

        _ = try await (firstImport, secondImport)

        let remoteIDs = try await snapshots(in: stack)
            .map(\.remoteID)
            .sorted()

        #expect(remoteIDs == [42, 43, 44])
    }

    @Test(.timeLimit(.minutes(1)))
    func concurrentDistinctMutationsPreserveCommittedData() async throws {
        let (_, storage) = try await makeStorage()

        let itemToUpdate = TodoItem(
            id: UUID(),
            title: "Original task",
            details: "Original details",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        let itemToDelete = TodoItem(
            id: UUID(),
            title: "Delete task",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_710_000_000
            ),
            status: .pending
        )

        try await storage.create(itemToUpdate)
        try await storage.create(itemToDelete)

        let updatedItem = TodoItem(
            id: itemToUpdate.id,
            title: "Updated task",
            details: "Updated details",
            createdAt: itemToUpdate.createdAt,
            status: .completed
        )

        let createdItem = TodoItem(
            id: UUID(),
            title: "Concurrent create",
            details: "",
            createdAt: Date(
                timeIntervalSince1970: 1_720_000_000
            ),
            status: .pending
        )

        async let create: Void = storage.create(createdItem)
        async let update: Void = storage.update(updatedItem)
        async let delete: Void = storage.delete(id: itemToDelete.id)

        _ = try await (create, update, delete)

        let items = try await storage.fetchAll()

        #expect(items == [createdItem, updatedItem])
    }

    @Test
    func updateChangesStoredTodoStatus() async throws {
        let (_, storage) = try await makeStorage()

        let originalItem = TodoItem(
            id: UUID(),
            title: "Toggle task",
            details: "Details",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        try await storage.create(originalItem)

        let updatedItem = TodoItem(
            id: originalItem.id,
            title: originalItem.title,
            details: originalItem.details,
            createdAt: originalItem.createdAt,
            status: .completed
        )

        try await storage.update(updatedItem)

        let items = try await storage.fetchAll()

        #expect(items == [updatedItem])
    }

    @Test
    func updateThrowsNotFoundForMissingTodo() async {
        let missingID = UUID()

        do {
            let (_, storage) = try await makeStorage()

            let missingItem = TodoItem(
                id: missingID,
                title: "Missing task",
                details: "",
                createdAt: Date(
                    timeIntervalSince1970: 1_700_000_000
                ),
                status: .completed
            )

            try await storage.update(missingItem)

            Issue.record(
                "Expected todoNotFound error"
            )
        } catch let error as TodoStorageError {
            #expect(
                error == .todoNotFound(id: missingID)
            )
        } catch {
            Issue.record(
                "Received unexpected error: \(error)"
            )
        }
    }

    @Test
    func deleteRemovesExistingTodo() async throws {
        let (_, storage) = try await makeStorage()

        let item = TodoItem(
            id: UUID(),
            title: "Delete task",
            details: "Task details",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: .pending
        )

        try await storage.create(item)
        try await storage.delete(id: item.id)

        let storedItems = try await storage.fetchAll()

        #expect(storedItems.isEmpty)
    }

    @Test
    func deleteThrowsNotFoundForMissingTodo() async {
        let missingID = UUID()

        do {
            let (_, storage) = try await makeStorage()

            try await storage.delete(id: missingID)

            Issue.record(
                "Expected todoNotFound error"
            )
        } catch let error as TodoStorageError {
            #expect(
                error == .todoNotFound(id: missingID)
            )
        } catch {
            Issue.record(
                "Received unexpected error: \(error)"
            )
        }
    }

    private func makeStorage() async throws -> (
        stack: CoreDataStack,
        storage: CoreDataTodoStorage
    ) {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        return (stack, storage)
    }

    private func snapshots(
        in stack: CoreDataStack
    ) async throws -> [StoredTodoSnapshot] {
        try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<
                        [StoredTodoSnapshot],
                        Error
                    >
            ) in

            stack.container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<StoredTodo>(
                        entityName: "StoredTodo"
                    )

                    let storedTodos = try context.fetch(
                        request
                    )

                    let snapshots = storedTodos.map {
                        StoredTodoSnapshot(
                            id: $0.id,
                            remoteID: $0.remoteID,
                            title: $0.title,
                            details: $0.details,
                            createdAt: $0.createdAt,
                            isCompleted: $0.isCompleted
                        )
                    }

                    continuation.resume(
                        returning: snapshots
                    )
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }
}
