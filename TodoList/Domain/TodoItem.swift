import Foundation

enum TodoStatus: Equatable, Sendable {
    case pending
    case completed
}

struct TodoItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let details: String
    let createdAt: Date
    let status: TodoStatus
}
