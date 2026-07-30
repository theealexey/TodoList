import Foundation

struct InitialTodoImporter {

    private let api: TodosAPI
    private let storage: CoreDataTodoStorage

    init(
        api: TodosAPI,
        storage: CoreDataTodoStorage
    ) {
        self.api = api
        self.storage = storage
    }

    func run(importedAt: Date) async throws {
        let todos = try await api.fetchTodos()

        let records = todos.map { todo in
            TodoImportRecord(
                remoteID: todo.id,
                title: todo.todo,
                isCompleted: todo.completed
            )
        }

        try await storage.importTodos(
            records,
            importedAt: importedAt
        )
    }
}
