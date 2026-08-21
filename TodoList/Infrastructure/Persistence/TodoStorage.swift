import Foundation

enum TodoStorageError: Error, Equatable, Sendable {
    case storedTodoEntityMissing
    case invalidStoredData
    case todoNotFound(id: UUID)
}

protocol TodoStoring: Sendable {
    func create(_ item: TodoItem) async throws
    func update(_ item: TodoItem) async throws
    func delete(id: UUID) async throws
    func fetchAll() async throws -> [TodoItem]
}

protocol TodoImportStoring: Sendable {
    func importTodos(
        _ records: [TodoImportRecord],
        importedAt: Date
    ) async throws
}
