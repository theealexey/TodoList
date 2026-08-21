import Foundation

enum UpdateTodoUseCaseError: Error, Equatable, Sendable {
    case emptyTitle
}

protocol UpdateTodoUseCaseProtocol: Sendable {
    func execute(
        item: TodoItem,
        title: String,
        details: String
    ) async throws -> TodoItem
}

struct UpdateTodoUseCase<Repository: TodoRepository>: UpdateTodoUseCaseProtocol {

    private let repository: Repository

    init(repository: Repository) {
        self.repository = repository
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

        try await repository.update(updatedItem)

        return updatedItem
    }
}
