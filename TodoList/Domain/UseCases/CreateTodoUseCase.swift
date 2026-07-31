import Foundation

enum CreateTodoUseCaseError: Error, Equatable, Sendable {
    case emptyTitle
}

struct CreateTodoUseCase {

    typealias Create = (TodoItem) async throws -> Void

    private let create: Create
    private let makeID: () -> UUID
    private let currentDate: () -> Date

    init(
        create: @escaping Create,
        makeID: @escaping () -> UUID = UUID.init,
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.create = create
        self.makeID = makeID
        self.currentDate = currentDate
    }

    func execute(
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
            id: makeID(),
            title: normalizedTitle,
            details: details.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            createdAt: currentDate(),
            status: .pending
        )

        try await create(item)

        return item
    }
}
