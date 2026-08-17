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
            try await importer.run(
                importedAt: currentDate()
            )

            return try await storage.fetchAll()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TodoRepositoryError.loadFailed
        }
    }

    func create(_ item: TodoItem) async throws {
        do {
            try await storage.create(item)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TodoRepositoryError.createFailed
        }
    }

    func update(_ item: TodoItem) async throws {
        do {
            try await storage.update(item)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as TodoStorageError {
            switch error {
            case let .todoNotFound(id):
                throw TodoRepositoryError.todoNotFound(id: id)
            case .storedTodoEntityMissing,
                 .invalidStoredData:
                throw TodoRepositoryError.updateFailed
            }
        } catch {
            throw TodoRepositoryError.updateFailed
        }
    }

    func delete(id: UUID) async throws {
        do {
            try await storage.delete(id: id)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as TodoStorageError {
            switch error {
            case let .todoNotFound(id):
                throw TodoRepositoryError.todoNotFound(id: id)
            case .storedTodoEntityMissing,
                 .invalidStoredData:
                throw TodoRepositoryError.deleteFailed
            }
        } catch {
            throw TodoRepositoryError.deleteFailed
        }
    }
}
