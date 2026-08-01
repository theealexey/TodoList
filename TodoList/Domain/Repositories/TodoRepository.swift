import Foundation

protocol TodoRepository {
    func loadTodos() async throws -> [TodoItem]
    func create(_ item: TodoItem) async throws
    func update(_ item: TodoItem) async throws
}
