import Foundation

struct InitialTodoImportStateStore: Sendable {

    private static let defaultKey =
        "InitialTodoImporter.completedStoreIdentifier"

    private let completedStoreIdentifierKey: String

    init(namespace: String? = nil) {
        if let namespace {
            completedStoreIdentifierKey =
                "\(namespace).completedStoreIdentifier"
        } else {
            completedStoreIdentifierKey = Self.defaultKey
        }
    }

    func isCompleted(for storeIdentifier: String) -> Bool {
        UserDefaults.standard.string(
            forKey: completedStoreIdentifierKey
        ) == storeIdentifier
    }

    func markCompleted(for storeIdentifier: String) {
        UserDefaults.standard.set(
            storeIdentifier,
            forKey: completedStoreIdentifierKey
        )
    }

    func reset() {
        UserDefaults.standard.removeObject(
            forKey: completedStoreIdentifierKey
        )
    }
}
