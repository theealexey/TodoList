import CoreData

enum CoreDataTodoStorageError: Error, Equatable, Sendable {
    case storedTodoEntityMissing
    case invalidStoredData
}

final class CoreDataTodoStorage {

    private let container: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.container = container
    }

    func create(_ item: TodoItem) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            container.performBackgroundTask { context in
                do {
                    guard let entity = NSEntityDescription.entity(
                        forEntityName: "StoredTodo",
                        in: context
                    ) else {
                        throw CoreDataTodoStorageError.storedTodoEntityMissing
                    }

                    let storedTodo = StoredTodo(
                        entity: entity,
                        insertInto: context
                    )

                    storedTodo.id = item.id
                    storedTodo.title = item.title
                    storedTodo.details = item.details
                    storedTodo.createdAt = item.createdAt
                    storedTodo.isCompleted = item.status == .completed

                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAll() async throws -> [TodoItem] {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[TodoItem], Error>) in

            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<StoredTodo>(
                        entityName: "StoredTodo"
                    )

                    let storedTodos = try context.fetch(request)

                    let items = try storedTodos.map { storedTodo in
                        try Self.makeTodoItem(from: storedTodo)
                    }

                    continuation.resume(returning: items)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func makeTodoItem(
        from storedTodo: StoredTodo
    ) throws -> TodoItem {
        guard
            let id = storedTodo.id,
            let title = storedTodo.title,
            let details = storedTodo.details,
            let createdAt = storedTodo.createdAt
        else {
            throw CoreDataTodoStorageError.invalidStoredData
        }

        return TodoItem(
            id: id,
            title: title,
            details: details,
            createdAt: createdAt,
            status: storedTodo.isCompleted ? .completed : .pending
        )
    }
}
