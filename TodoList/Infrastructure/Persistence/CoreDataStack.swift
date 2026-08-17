import CoreData

enum CoreDataStackError: Error, Equatable, Sendable {
    case persistentStoreNotLoaded
    case persistentStoreIdentifierMissing
}

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
        } else {
            container.persistentStoreDescriptions.forEach {
                $0.shouldAddStoreAsynchronously = true
            }
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

    func loadedStoreIdentifier() throws -> String {
        guard let store = container
            .persistentStoreCoordinator
            .persistentStores
            .first
        else {
            throw CoreDataStackError.persistentStoreNotLoaded
        }

        let metadata = container
            .persistentStoreCoordinator
            .metadata(for: store)

        guard let identifier = metadata[NSStoreUUIDKey] as? String,
              !identifier.isEmpty else {
            throw CoreDataStackError
                .persistentStoreIdentifierMissing
        }

        return identifier
    }
}
