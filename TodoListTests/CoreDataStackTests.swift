import CoreData
import Foundation
import Testing
@testable import TodoList

struct CoreDataStackTests {

    @Test
    func productionStoreLoadsAsynchronously() {
        let stack = CoreDataStack()

        let descriptions = stack.container.persistentStoreDescriptions

        #expect(!descriptions.isEmpty)
        #expect(
            descriptions.allSatisfy {
                $0.shouldAddStoreAsynchronously
            }
        )
    }

    @Test
    func loadsInMemoryStoreWithStoredTodoEntity() async throws {
        let stack = CoreDataStack(inMemory: true)

        try await stack.load()

        let stores = stack
            .container
            .persistentStoreCoordinator
            .persistentStores

        #expect(stores.count == 1)

        let store = try #require(stores.first)

        #expect(store.type == NSInMemoryStoreType)

        let entity = stack
            .container
            .managedObjectModel
            .entitiesByName["StoredTodo"]

        #expect(entity != nil)
    }

    @Test
    func loadPropagatesPersistentStoreFailure() async throws {
        let stack = CoreDataStack(inMemory: true)
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(
                at: temporaryDirectory
            )
        }

        let blockingFileURL = temporaryDirectory
            .appendingPathComponent("not-a-directory")

        try Data().write(to: blockingFileURL)

        let invalidStoreURL = blockingFileURL
            .appendingPathComponent("TodoList.sqlite")

        let description = NSPersistentStoreDescription(
            url: invalidStoreURL
        )
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false

        stack.container.persistentStoreDescriptions = [description]

        await #expect(throws: Error.self) {
            try await stack.load()
        }
    }

    @Test
    func loadedStoreIdentifierRequiresLoadedStore() {
        let stack = CoreDataStack(inMemory: true)

        do {
            _ = try stack.loadedStoreIdentifier()
            Issue.record("Expected store identifier lookup to fail")
        } catch let error as CoreDataStackError {
            #expect(error == .persistentStoreNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func loadedStoreIdentifierReturnsPersistentStoreUUID() async throws {
        let stack = CoreDataStack(inMemory: true)

        try await stack.load()

        let identifier = try stack.loadedStoreIdentifier()

        #expect(!identifier.isEmpty)
    }

}
