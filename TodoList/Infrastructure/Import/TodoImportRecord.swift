import Foundation

struct TodoImportRecord: Equatable, Sendable {
    let remoteID: Int
    let title: String
    let isCompleted: Bool
}
