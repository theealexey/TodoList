protocol TodoRepository {
    func loadTodos() async throws -> [TodoItem]
}
