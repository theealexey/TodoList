import Foundation

enum TodoRepositoryError: Error, Equatable, Sendable {
    case loadFailed
    case createFailed
    case updateFailed
    case deleteFailed
    case todoNotFound(id: UUID)
}

protocol TodoRepository: Sendable {
    func loadTodos() async throws -> [TodoItem]
    func create(_ item: TodoItem) async throws
    func update(_ item: TodoItem) async throws
    func delete(id: UUID) async throws
}
