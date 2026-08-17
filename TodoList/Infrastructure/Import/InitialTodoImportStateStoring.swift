protocol InitialTodoImportStateStoring: Sendable {
    func isCompleted(for storeIdentifier: String) -> Bool
    func markCompleted(for storeIdentifier: String)
}
