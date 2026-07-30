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
                            remoteID: $0.remoteID,
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
            remoteID: 0,
            title: item.title,
            details: item.details,
            createdAt: createdAt,
            isCompleted: false
        )
        
        #expect(snapshots == [expected])
    }
    
    @Test
    func fetchAllReturnsMappedDomainItems() async throws {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()
        
        let storage = CoreDataTodoStorage(
            container: stack.container
        )
        
        let item = TodoItem(
            id: UUID(),
            title: "Read stored task",
            details: "Verify StoredTodo mapping",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .completed
        )
        
        try await storage.create(item)
        
        let fetchedItems = try await storage.fetchAll()
        
        #expect(fetchedItems == [item])
    }
    
    @Test
    func createImportedTodoStoresRemoteData() async throws {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()
        
        let storage = CoreDataTodoStorage(
            container: stack.container
        )
        
        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )
        
        try await storage.createImportedTodo(
            remoteID: 42,
            title: "Imported task",
            importedAt: importedAt,
            isCompleted: true
        )
        
        let snapshots: [StoredTodoSnapshot] =
        try await withCheckedThrowingContinuation { continuation in
            stack.container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<StoredTodo>(
                        entityName: "StoredTodo"
                    )
                    
                    let snapshots = try context.fetch(request).map {
                        StoredTodoSnapshot(
                            id: $0.id,
                            remoteID: $0.remoteID,
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
        
        let snapshot = try #require(snapshots.first)
        
        #expect(snapshots.count == 1)
        #expect(snapshot.id != nil)
        #expect(snapshot.remoteID == 42)
        #expect(snapshot.title == "Imported task")
        #expect(snapshot.details == "")
        #expect(snapshot.createdAt == importedAt)
        #expect(snapshot.isCompleted)
    }
    
    @Test
    func createImportedTodoDoesNotDuplicateExistingRemoteID() async throws {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()
        
        let storage = CoreDataTodoStorage(
            container: stack.container
        )
        
        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )
        
        try await storage.createImportedTodo(
            remoteID: 42,
            title: "Imported task",
            importedAt: importedAt,
            isCompleted: false
        )
        
        try await storage.createImportedTodo(
            remoteID: 42,
            title: "Changed remote title",
            importedAt: importedAt,
            isCompleted: true
        )
        
        let items = try await storage.fetchAll()
        let item = try #require(items.first)
        
        #expect(items.count == 1)
        #expect(item.title == "Imported task")
        #expect(item.status == .pending)
    }
    
    @Test
    func importTodosStoresUniqueRemoteRecords() async throws {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

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
    
}
