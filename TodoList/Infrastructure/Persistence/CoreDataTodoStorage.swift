import CoreData

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
                    let storedTodo = StoredTodo(context: context)

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
}
