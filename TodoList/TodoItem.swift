import Foundation

enum TodoStatus: Equatable, Sendable {
    case pending
    case complited
}

enum TodoItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let details: String
    let createdAt: Date
    let status: TodoStatus
}
