import Foundation

enum CreateTodoUseCaseError: Error, Equatable, Sendable {
    case emptyTitle
}

protocol CreateTodoUseCaseProtocol: Sendable {
    func makeDraft() -> NewTodoDraft

    func execute(
        draft: NewTodoDraft,
        title: String,
        details: String
    ) async throws -> TodoItem
}

struct CreateTodoUseCase<Repository: TodoRepository>: CreateTodoUseCaseProtocol {

    private let repository: Repository
    private let makeID: @Sendable () -> UUID
    private let currentDate: @Sendable () -> Date

    init(
        repository: Repository,
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.makeID = makeID
        self.currentDate = currentDate
    }

    func makeDraft() -> NewTodoDraft {
        NewTodoDraft(
            id: makeID(),
            createdAt: currentDate()
        )
    }

    func execute(
        draft: NewTodoDraft,
        title: String,
        details: String
    ) async throws -> TodoItem {
        let normalizedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedTitle.isEmpty else {
            throw CreateTodoUseCaseError.emptyTitle
        }

        let item = TodoItem(
            id: draft.id,
            title: normalizedTitle,
            details: details.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            createdAt: draft.createdAt,
            status: .pending
        )

        try await repository.create(item)
        return item
    }
}
