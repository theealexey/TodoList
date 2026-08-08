import CoreData
import Foundation

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

    private static let entityName = "StoredTodo"
    private static let localRemoteID: Int64 = 0

    private let container: NSPersistentContainer
    private let operationQueue: OperationQueue

    init(
        container: NSPersistentContainer,
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.container = container
        self.operationQueue = operationQueue

        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInitiated
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
                    storedTodo.remoteID = Self.localRemoteID
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

    func update(_ item: TodoItem) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<StoredTodo>(
                        entityName: Self.entityName
                    )
                    request.predicate = NSPredicate(
                        format: "id == %@",
                        item.id as NSUUID
                    )
                    request.fetchLimit = 1

                    guard let storedTodo = try context.fetch(request).first else {
                        throw CoreDataTodoStorageError.todoNotFound(
                            id: item.id
                        )
                    }

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

    func delete(id: UUID) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<StoredTodo>(
                        entityName: Self.entityName
                    )
                    request.predicate = NSPredicate(
                        format: "id == %@",
                        id as NSUUID
                    )
                    request.fetchLimit = 1

                    guard let storedTodo = try context.fetch(request).first else {
                        throw CoreDataTodoStorageError.todoNotFound(id: id)
                    }

                    context.delete(storedTodo)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
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
                        entityName: Self.entityName
                    )
                    request.predicate = NSPredicate(
                        format: "remoteID > %@ AND remoteID IN %@",
                        NSNumber(value: Self.localRemoteID),
                        candidateRemoteIDs.map(NSNumber.init(value:))
                    )

                    let existingRemoteIDs = Set(
                        try context.fetch(request).map(\.remoteID)
                    )
                    var processedRemoteIDs = existingRemoteIDs

                    for record in records {
                        let remoteID = Int64(record.remoteID)

                        guard processedRemoteIDs.insert(remoteID).inserted else {
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
                        storedTodo.isCompleted = record.isCompleted
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
            (
                continuation: CheckedContinuation<[TodoItem], Error>
            ) in

            operationQueue.addOperation { [container] in
                let context = container.newBackgroundContext()

                context.performAndWait {
                    do {
                        let request = NSFetchRequest<StoredTodo>(
                            entityName: Self.entityName
                        )
                        request.sortDescriptors = [
                            NSSortDescriptor(
                                key: #keyPath(StoredTodo.createdAt),
                                ascending: false
                            )
                        ]

                        let items = try context.fetch(request).map {
                            try Self.makeTodoItem(from: $0)
                        }
                        .sorted(by: Self.isOrderedBefore)

                        continuation.resume(returning: items)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private static func isOrderedBefore(
        _ lhs: TodoItem,
        _ rhs: TodoItem
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
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
            forEntityName: Self.entityName,
            in: context
        ) else {
            throw CoreDataTodoStorageError.storedTodoEntityMissing
        }

        return StoredTodo(
            entity: entity,
            insertInto: context
        )
    }
}
