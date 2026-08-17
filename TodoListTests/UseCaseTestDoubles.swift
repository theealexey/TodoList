import Foundation
@testable import TodoList

struct LoadTodosUseCaseStub: LoadTodosUseCaseProtocol {
    typealias Load = @Sendable () async throws -> [TodoItem]

    private let handler: Load

    init(_ handler: @escaping Load) {
        self.handler = handler
    }

    func execute() async throws -> [TodoItem] {
        try await handler()
    }
}

struct ToggleTodoStatusUseCaseStub: ToggleTodoStatusUseCaseProtocol {
    typealias Update = @Sendable (TodoItem) async throws -> Void

    private let handler: @Sendable (TodoItem) async throws -> TodoItem

    init(
        _ handler: @escaping @Sendable (TodoItem) async throws -> TodoItem
    ) {
        self.handler = handler
    }

    init(update: @escaping Update) {
        self.handler = { item in
            let updatedStatus: TodoStatus =
                item.status == .completed ? .pending : .completed

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

    func execute(item: TodoItem) async throws -> TodoItem {
        try await handler(item)
    }
}

struct DeleteTodoUseCaseStub: DeleteTodoUseCaseProtocol {
    typealias Delete = @Sendable (UUID) async throws -> Void

    private let handler: Delete

    init(_ handler: @escaping Delete) {
        self.handler = handler
    }

    init(delete: @escaping Delete) {
        self.handler = delete
    }

    func execute(id: UUID) async throws {
        try await handler(id)
    }
}

struct CreateTodoUseCaseStub: CreateTodoUseCaseProtocol {
    private let draft: NewTodoDraft
    private let handler: @Sendable (
        NewTodoDraft,
        String,
        String
    ) async throws -> TodoItem

    init(
        draft: NewTodoDraft = NewTodoDraft(
            id: UUID(),
            createdAt: Date()
        ),
        _ handler: @escaping @Sendable (
            NewTodoDraft,
            String,
            String
        ) async throws -> TodoItem
    ) {
        self.draft = draft
        self.handler = handler
    }

    func makeDraft() -> NewTodoDraft {
        draft
    }

    func execute(
        draft: NewTodoDraft,
        title: String,
        details: String
    ) async throws -> TodoItem {
        try await handler(draft, title, details)
    }
}

struct UpdateTodoUseCaseStub: UpdateTodoUseCaseProtocol {
    private let handler: @Sendable (
        TodoItem,
        String,
        String
    ) async throws -> TodoItem

    init(
        _ handler: @escaping @Sendable (
            TodoItem,
            String,
            String
        ) async throws -> TodoItem
    ) {
        self.handler = handler
    }

    func execute(
        item: TodoItem,
        title: String,
        details: String
    ) async throws -> TodoItem {
        try await handler(item, title, details)
    }
}
