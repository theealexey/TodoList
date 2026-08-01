import Foundation

final class DefaultTodoRepository: TodoRepository {

    private let importer: InitialTodoImporter
    private let storage: CoreDataTodoStorage
    private let currentDate: () -> Date

    init(
        importer: InitialTodoImporter,
        storage: CoreDataTodoStorage,
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.importer = importer
        self.storage = storage
        self.currentDate = currentDate
    }
    
    func create(_ item: TodoItem) async throws {
        try await storage.create(item)
    }
    
    func loadTodos() async throws -> [TodoItem] {
        try await importer.run(
            importedAt: currentDate()
        )

        return try await storage.fetchAll()
    }
    
    func update(_ item: TodoItem) async throws {
        try await storage.update(item)
    }
}
