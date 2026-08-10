import Foundation
import Testing
@testable import TodoList

@Suite
struct DeleteTodoUseCaseTests {

    private actor DeleteSpy {

        private var receivedIDs: [UUID] = []

        func delete(id: UUID) {
            receivedIDs.append(id)
        }

        func ids() -> [UUID] {
            receivedIDs
        }
    }

    @Test
    func executePassesTodoIDToDeleteDependency() async throws {
        let expectedID = UUID()
        let spy = DeleteSpy()

        let useCase = DeleteTodoUseCase(
            delete: { id in
                await spy.delete(id: id)
            }
        )

        try await useCase.execute(id: expectedID)

        let receivedIDs = await spy.ids()

        #expect(receivedIDs == [expectedID])
    }

    @Test
    func executePropagatesDeleteError() async {
        enum TestError: Error, Equatable {
            case deleteFailed
        }

        let useCase = DeleteTodoUseCase(
            delete: { _ in
                throw TestError.deleteFailed
            }
        )

        do {
            try await useCase.execute(id: UUID())

            Issue.record(
                "Expected deleteFailed error"
            )
        } catch let error as TestError {
            #expect(error == .deleteFailed)
        } catch {
            Issue.record(
                "Received unexpected error: \(error)"
            )
        }
    }
}
