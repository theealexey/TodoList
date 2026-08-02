import CoreData

struct TodoImportRecord: Equatable, Sendable {
    let remoteID: Int
    let title: String
    let isCompleted: Bool
}

enum CoreDataTodoStorageError: Error, Equatable, Sendable {
    case storedTodoEntityMissing
    case invalidStoredData
    case todoNotFound(id: UUID)
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
                    let storedTodo = try Self.makeStoredTodo(
                        in: context
                    )

                    storedTodo.id = item.id
                    storedTodo.title = item.title
                    storedTodo.details = item.details
                    storedTodo.createdAt = item.createdAt
                    storedTodo.isCompleted =
                        item.status == .completed

                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func update(_ item: TodoItem) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<StoredTodo>(
                        entityName: "StoredTodo"
                    )

                    request.predicate = NSPredicate(
                        format: "id == %@",
                        item.id as NSUUID
                    )
                    request.fetchLimit = 1

                    guard let storedTodo =
                        try context.fetch(request).first
                    else {
                        throw CoreDataTodoStorageError.todoNotFound(
                            id: item.id
                        )
                    }

                    storedTodo.title = item.title
                    storedTodo.details = item.details
                    storedTodo.createdAt = item.createdAt
                    storedTodo.isCompleted =
                        item.status == .completed

                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }
    
    func delete(id: UUID) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<StoredTodo>(
                        entityName: "StoredTodo"
                    )

                    request.predicate = NSPredicate(
                        format: "id == %@",
                        id as NSUUID
                    )
                    request.fetchLimit = 1

                    guard let storedTodo =
                        try context.fetch(request).first
                    else {
                        throw CoreDataTodoStorageError.todoNotFound(
                            id: id
                        )
                    }

                    context.delete(storedTodo)
                    try context.save()

                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }
    
    func createImportedTodo(
        remoteID: Int,
        title: String,
        importedAt: Date,
        isCompleted: Bool
    ) async throws {
        let record = TodoImportRecord(
            remoteID: remoteID,
            title: title,
            isCompleted: isCompleted
        )

        try await importTodos(
            [record],
            importedAt: importedAt
        )
    }
    
    func importTodos(
        _ records: [TodoImportRecord],
        importedAt: Date
    ) async throws {
        guard !records.isEmpty else {
            return
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            container.performBackgroundTask { context in
                do {
                    let candidateRemoteIDs = Set(
                        records.map { Int64($0.remoteID) }
                    )

                    let request = NSFetchRequest<StoredTodo>(
                        entityName: "StoredTodo"
                    )

                    request.predicate = NSPredicate(
                        format: "remoteID IN %@",
                        candidateRemoteIDs.map {
                            NSNumber(value: $0)
                        }
                    )

                    let existingRemoteIDs = Set(
                        try context.fetch(request).map(\.remoteID)
                    )

                    var processedRemoteIDs = existingRemoteIDs

                    for record in records {
                        let remoteID = Int64(record.remoteID)

                        guard processedRemoteIDs
                            .insert(remoteID)
                            .inserted
                        else {
                            continue
                        }

                        let storedTodo = try Self.makeStoredTodo(
                            in: context
                        )

                        storedTodo.id = UUID()
                        storedTodo.remoteID = remoteID
                        storedTodo.title = record.title
                        storedTodo.details = ""
                        storedTodo.createdAt = importedAt
                        storedTodo.isCompleted =
                            record.isCompleted
                    }

                    if context.hasChanges {
                        try context.save()
                    }

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
    
    private static func makeStoredTodo(
        in context: NSManagedObjectContext
    ) throws -> StoredTodo {
        guard let entity = NSEntityDescription.entity(
            forEntityName: "StoredTodo",
            in: context
        ) else {
            throw CoreDataTodoStorageError
                .storedTodoEntityMissing
        }

        return StoredTodo(
            entity: entity,
            insertInto: context
        )
    }
    
}
