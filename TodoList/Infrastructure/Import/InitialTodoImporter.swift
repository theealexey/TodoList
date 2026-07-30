import Foundation

struct InitialTodoImporter {

    private let api: TodosAPI
    private let storage: CoreDataTodoStorage
    private let stateStore: InitialTodoImportStateStore

    init(
        api: TodosAPI,
        storage: CoreDataTodoStorage,
        stateStore: InitialTodoImportStateStore =
            InitialTodoImportStateStore()
    ) {
        self.api = api
        self.storage = storage
        self.stateStore = stateStore
    }

    func run(importedAt: Date) async throws {
        guard !stateStore.isCompleted else {
            return
        }

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

        stateStore.markCompleted()
    }
}
