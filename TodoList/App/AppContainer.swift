final class AppContainer {

    let todoRepository: DefaultTodoRepository

    init(
        storage: any TodoStoring & TodoImportStoring,
        storeIdentifier: String,
        todosFetcher: any TodosFetching = TodosAPI(),
        importStateStore: any InitialTodoImportStateStoring =
            InitialTodoImportStateStore()
    ) {
        let importer = InitialTodoImporter(
            api: todosFetcher,
            storage: storage,
            stateStore: importStateStore,
            storeIdentifier: storeIdentifier
        )

        todoRepository = DefaultTodoRepository(
            importer: importer,
            storage: storage
        )
    }
}
