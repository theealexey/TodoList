import Foundation

protocol ToggleTodoStatusUseCaseProtocol: Sendable {
    func execute(item: TodoItem) async throws -> TodoItem
}

struct ToggleTodoStatusUseCase<Repository: TodoRepository>: ToggleTodoStatusUseCaseProtocol {

    private let repository: Repository

    init(repository: Repository) {
        self.repository = repository
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

        try await repository.update(updatedItem)

        return updatedItem
    }
}
