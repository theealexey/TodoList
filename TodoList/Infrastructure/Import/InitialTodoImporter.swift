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
        try Task.checkCancellation()

        guard !stateStore.isCompleted(
            for: storeIdentifier
        ) else {
            return
        }

        let task: Task<Void, Error>

        if let inFlightTask {
            task = inFlightTask
        } else {
            task = Task { [self] in
                defer {
                    inFlightTask = nil
                }

                try await performImport(
                    importedAt: importedAt
                )
            }

            inFlightTask = task
        }

        try await waitForSharedImport(task)
    }

    private func performImport(
        importedAt: Date
    ) async throws {
        let todos = try await api.fetchTodos()

        let records = try todos.map { todo in
            try TodoImportRecord(
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

    private func waitForSharedImport(
        _ task: Task<Void, Error>
    ) async throws {
        let stream = AsyncThrowingStream<Void, Error> {
            continuation in
            let observer = Task {
                do {
                    try await task.value
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                observer.cancel()
            }
        }

        do {
            for try await _ in stream {}
        } catch {
            try Task.checkCancellation()
            throw error
        }

        try Task.checkCancellation()
    }
}
