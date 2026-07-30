import Foundation

struct InitialTodoImportStateStore {

    private enum Key {
        static let isCompleted =
            "InitialTodoImporter.isCompleted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isCompleted: Bool {
        defaults.bool(forKey: Key.isCompleted)
    }

    func markCompleted() {
        defaults.set(
            true,
            forKey: Key.isCompleted
        )
    }
}
