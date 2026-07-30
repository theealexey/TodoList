import Foundation

enum TodoStatus: Equatable, Sendable {
    case pending
    case complited
}

struct TodoItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let details: String
    let createdAt: Date
    let status: TodoStatus
}
