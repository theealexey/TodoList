import CoreData
import Testing
@testable import TodoList

struct CoreDataStackTests {

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
}
