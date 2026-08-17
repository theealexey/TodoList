final class AppContainer {

    let todoRepository: DefaultTodoRepository

    init(
        coreDataStack: CoreDataStack,
        todosAPI: TodosAPI = TodosAPI(),
        importStateStore: InitialTodoImportStateStore =
            InitialTodoImportStateStore()
    ) throws {
        let storage = CoreDataTodoStorage(
            container: coreDataStack.container
        )

        let importer = InitialTodoImporter(
            api: todosAPI,
            storage: storage,
            stateStore: importStateStore,
            storeIdentifier: try coreDataStack
                .loadedStoreIdentifier()
        )

        todoRepository = DefaultTodoRepository(
            importer: importer,
            storage: storage
        )
    }
}
