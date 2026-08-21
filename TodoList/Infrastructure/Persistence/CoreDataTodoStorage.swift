import CoreData
import Foundation

final class CoreDataTodoStorage: TodoStoring, TodoImportStoring {

    private static let entityName = "StoredTodo"
    private static let localRemoteID: Int64 = 0

    private let container: NSPersistentContainer
    private let operationQueue = OperationQueue()

    init(container: NSPersistentContainer) {
        self.container = container

        // Prevent concurrent fetch-then-insert imports from creating
        // duplicate remote IDs within this storage instance.
        operationQueue.maxConcurrentOperationCount = 1
    }

    func create(_ item: TodoItem) async throws {
        try await performStorageOperation { context in
            let storedTodo = try Self.makeStoredTodo(
                in: context
            )

            storedTodo.id = item.id
            storedTodo.remoteID = Self.localRemoteID
            storedTodo.title = item.title
            storedTodo.details = item.details
            storedTodo.createdAt = item.createdAt
            storedTodo.isCompleted =
                item.status == .completed

            try context.save()
        }
    }

    func update(_ item: TodoItem) async throws {
        try await performStorageOperation { context in
            let request = NSFetchRequest<StoredTodo>(
                entityName: Self.entityName
            )

            request.predicate = NSPredicate(
                format: "id == %@",
                item.id as NSUUID
            )

            request.fetchLimit = 1

            guard let storedTodo = try context
                .fetch(request)
                .first
            else {
                throw TodoStorageError.todoNotFound(
                    id: item.id
                )
            }

            storedTodo.title = item.title
            storedTodo.details = item.details
            storedTodo.createdAt = item.createdAt
            storedTodo.isCompleted =
                item.status == .completed

            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        try await performStorageOperation { context in
            let request = NSFetchRequest<StoredTodo>(
                entityName: Self.entityName
            )

            request.predicate = NSPredicate(
                format: "id == %@",
                id as NSUUID
            )

            request.fetchLimit = 1

            guard let storedTodo = try context
                .fetch(request)
                .first
            else {
                throw TodoStorageError.todoNotFound(
                    id: id
                )
            }

            context.delete(storedTodo)
            try context.save()
        }
    }

    func importTodos(
        _ records: [TodoImportRecord],
        importedAt: Date
    ) async throws {
        guard !records.isEmpty else {
            return
        }

        try await performStorageOperation { context in
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
                storedTodo.isCompleted = record.isCompleted
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    func fetchAll() async throws -> [TodoItem] {
        let items = try await performStorageOperation { context in
            let request = NSFetchRequest<StoredTodo>(
                entityName: Self.entityName
            )
            request.sortDescriptors = [
                NSSortDescriptor(
                    key: #keyPath(StoredTodo.createdAt),
                    ascending: false
                )
            ]

            return try context.fetch(request).map {
                try Self.makeTodoItem(from: $0)
            }
            .sorted(by: Self.isOrderedBefore)
        }

        try Task.checkCancellation()
        return items
    }

    private func performStorageOperation<T: Sendable>(
        _ operation: @escaping @Sendable (
            NSManagedObjectContext
        ) throws -> T
    ) async throws -> T {
        try Task.checkCancellation()

        return try await withCheckedThrowingContinuation {
            continuation in

            operationQueue.addOperation { [container] in
                let result = Result<T, Error> {
                    let context = container.newBackgroundContext()

                    return try context.performAndWait {
                        try operation(context)
                    }
                }

                continuation.resume(with: result)
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
            throw TodoStorageError.invalidStoredData
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
            throw TodoStorageError.storedTodoEntityMissing
        }

        return StoredTodo(
            entity: entity,
            insertInto: context
        )
    }
}
