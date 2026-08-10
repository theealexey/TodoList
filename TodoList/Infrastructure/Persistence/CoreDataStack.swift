import CoreData

final class CoreDataStack {

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TodoList")

        if inMemory {
            let storeURL = URL(
                fileURLWithPath: NSTemporaryDirectory()
            )
            .appendingPathComponent(UUID().uuidString)

            let description = NSPersistentStoreDescription(
                url: storeURL
            )
            description.type = NSInMemoryStoreType
            description.shouldAddStoreAsynchronously = false

            container.persistentStoreDescriptions = [description]
        }
    }

    func load() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }
}
