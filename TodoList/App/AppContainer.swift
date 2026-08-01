import Foundation

final class AppContainer {

    let todoRepository: DefaultTodoRepository

    private let coreDataStack: CoreDataStack
    private var isPrepared = false

    init(
        coreDataStack: CoreDataStack = CoreDataStack(),
        todosAPI: TodosAPI = TodosAPI(),
        importStateStore: InitialTodoImportStateStore =
            InitialTodoImportStateStore()
    ) {
        self.coreDataStack = coreDataStack

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
        guard !isPrepared else {
            return
        }

        try await coreDataStack.load()
        isPrepared = true
    }
}
