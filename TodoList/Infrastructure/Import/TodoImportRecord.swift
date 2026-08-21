import Foundation

enum TodoImportRecordError: Error, Equatable, Sendable {
    case invalidRemoteID(Int)
}

struct TodoImportRecord: Equatable, Sendable {
    let remoteID: Int
    let title: String
    let isCompleted: Bool

    init(
        remoteID: Int,
        title: String,
        isCompleted: Bool
    ) throws {
        guard remoteID > 0 else {
            throw TodoImportRecordError.invalidRemoteID(
                remoteID
            )
        }

        self.remoteID = remoteID
        self.title = title
        self.isCompleted = isCompleted
    }
}
