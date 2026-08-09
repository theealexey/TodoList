import Foundation

final class AppContainer {
    
    typealias CoreDataPreparation = () async throws -> Void
    
    private let coreDataPreparation: CoreDataPreparation

    let todoRepository: DefaultTodoRepository

    private let coreDataStack: CoreDataStack
    private var preparationTask: Task<Void, Error>?

    init(
        coreDataStack: CoreDataStack = CoreDataStack(),
        todosAPI: TodosAPI = TodosAPI(),
        importStateStore: InitialTodoImportStateStore =
            InitialTodoImportStateStore(),
        coreDataPreparation: CoreDataPreparation? = nil
    ) {
        self.coreDataStack = coreDataStack
        self.coreDataPreparation = coreDataPreparation ?? {
            try await coreDataStack.load()
        }

        let storage = CoreDataTodoStorage(
            container: coreDataStack.container
        )

        let importer = InitialTodoImporter(
            api: todosAPI,
            storage: storage,
            stateStore: importStateStore
        )

        todoRepository = DefaultTodoRepository(
            importer: importer,
            storage: storage
        )
    }

    @MainActor
    func prepare() async throws {
        if let preparationTask {
            try await preparationTask.value
            return
        }

        let task = Task { [coreDataPreparation] in
            try await coreDataPreparation()
        }

        preparationTask = task

        do {
            try await task.value
        } catch {
            preparationTask = nil
            throw error
        }
    }
}
