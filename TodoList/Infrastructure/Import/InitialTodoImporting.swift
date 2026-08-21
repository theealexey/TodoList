import Foundation

protocol InitialTodoImporting: Sendable {
    func run(importedAt: Date) async throws
}
