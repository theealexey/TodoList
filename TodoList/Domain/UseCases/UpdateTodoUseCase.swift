import Foundation

enum UpdateTodoUseCaseError: Error, Equatable, Sendable {
    case emptyTitle
}

struct UpdateTodoUseCase {

    typealias Update = (TodoItem) async throws -> Void

    private let update: Update

    init(update: @escaping Update) {
        self.update = update
    }

    func execute(
        item: TodoItem,
        title: String,
        details: String
    ) async throws -> TodoItem {
        let normalizedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedTitle.isEmpty else {
            throw UpdateTodoUseCaseError.emptyTitle
        }

        let normalizedDetails = details.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let updatedItem = TodoItem(
            id: item.id,
            title: normalizedTitle,
            details: normalizedDetails,
            createdAt: item.createdAt,
            status: item.status
        )

        try await update(updatedItem)

        return updatedItem
    }
}
