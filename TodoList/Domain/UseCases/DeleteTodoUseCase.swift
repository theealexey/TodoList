import Foundation

struct DeleteTodoUseCase {

    typealias Delete = (UUID) async throws -> Void

    private let delete: Delete

    init(delete: @escaping Delete) {
        self.delete = delete
    }

    func execute(id: UUID) async throws {
        try await delete(id)
    }
}
