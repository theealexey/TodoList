import Foundation

actor InitialTodoImporter: InitialTodoImporting {

    private let api: any TodosFetching
    private let storage: any TodoImportStoring
    private let stateStore: any InitialTodoImportStateStoring
    private let storeIdentifier: String

    private var inFlightTask: Task<Void, Error>?

    init(
        api: any TodosFetching,
        storage: any TodoImportStoring,
        stateStore: any InitialTodoImportStateStoring =
            InitialTodoImportStateStore(),
        storeIdentifier: String
    ) {
        self.api = api
        self.storage = storage
        self.stateStore = stateStore
        self.storeIdentifier = storeIdentifier
    }

    func run(importedAt: Date) async throws {
        if let inFlightTask {
            try await inFlightTask.value
            return
        }

        guard !stateStore.isCompleted(
            for: storeIdentifier
        ) else {
            return
        }

        try Task.checkCancellation()

        let task = Task {
            try await performImport(
                importedAt: importedAt
            )
        }

        inFlightTask = task

        defer {
            inFlightTask = nil
        }

        try await task.value
    }

    private func performImport(
        importedAt: Date
    ) async throws {
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

        stateStore.markCompleted(
            for: storeIdentifier
        )
    }
}
