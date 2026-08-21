import Foundation

final class DefaultTodoRepository: TodoRepository {

    private let importer: any InitialTodoImporting
    private let storage: any TodoStoring
    private let currentDate: @Sendable () -> Date

    init(
        importer: any InitialTodoImporting,
        storage: any TodoStoring,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.importer = importer
        self.storage = storage
        self.currentDate = currentDate
    }

    func loadTodos() async throws -> [TodoItem] {
        do {
            try Task.checkCancellation()

            try await importer.run(
                importedAt: currentDate()
            )

            try Task.checkCancellation()

            let items = try await storage.fetchAll()

            try Task.checkCancellation()
            return items
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }

            throw TodoRepositoryError.loadFailed
        }
    }

    func create(_ item: TodoItem) async throws {
        do {
            try Task.checkCancellation()
            try await storage.create(item)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }

            throw TodoRepositoryError.createFailed
        }
    }

    func update(_ item: TodoItem) async throws {
        do {
            try Task.checkCancellation()
            try await storage.update(item)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as TodoStorageError {
            if Task.isCancelled {
                throw CancellationError()
            }

            switch error {
            case let .todoNotFound(id):
                throw TodoRepositoryError.todoNotFound(id: id)
            case .storedTodoEntityMissing,
                 .invalidStoredData:
                throw TodoRepositoryError.updateFailed
            }
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }

            throw TodoRepositoryError.updateFailed
        }
    }

    func delete(id: UUID) async throws {
        do {
            try Task.checkCancellation()
            try await storage.delete(id: id)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as TodoStorageError {
            if Task.isCancelled {
                throw CancellationError()
            }

            switch error {
            case let .todoNotFound(id):
                throw TodoRepositoryError.todoNotFound(id: id)
            case .storedTodoEntityMissing,
                 .invalidStoredData:
                throw TodoRepositoryError.deleteFailed
            }
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }

            throw TodoRepositoryError.deleteFailed
        }
    }
}
