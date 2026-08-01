import Foundation

struct ToggleTodoStatusUseCase {

    typealias Update = (TodoItem) async throws -> Void

    private let update: Update

    init(update: @escaping Update) {
        self.update = update
    }

    func execute(
        item: TodoItem
    ) async throws -> TodoItem {
        let updatedStatus: TodoStatus =
            item.status == .completed
            ? .pending
            : .completed

        let updatedItem = TodoItem(
            id: item.id,
            title: item.title,
            details: item.details,
            createdAt: item.createdAt,
            status: updatedStatus
        )

        try await update(updatedItem)

        return updatedItem
    }
}
