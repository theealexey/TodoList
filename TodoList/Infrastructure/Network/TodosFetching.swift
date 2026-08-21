protocol TodosFetching: Sendable {
    func fetchTodos() async throws -> [TodoDTO]
}
