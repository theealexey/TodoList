import Foundation
import Testing
@testable import TodoList

@Suite
struct LoadTodosUseCaseTests {

    private enum TestError: Error, Equatable {
        case loadingFailed
    }

    @Test
    func executeReturnsLoadedTodos() async throws {
        let expectedItems = [
            TodoItem(
                id: UUID(),
                title: "First task",
                details: "First details",
                createdAt: Date(
                    timeIntervalSince1970: 1_700_000_000
                ),
                status: .pending
            ),
            TodoItem(
                id: UUID(),
                title: "Second task",
                details: "Second details",
                createdAt: Date(
                    timeIntervalSince1970: 1_800_000_000
                ),
                status: .completed
            )
        ]

        let useCase = LoadTodosUseCase(
            load: {
                expectedItems
            }
        )

        let items = try await useCase.execute()

        #expect(items == expectedItems)
    }

    @Test
    func executePropagatesLoadingError() async {
        let useCase = LoadTodosUseCase(
            load: {
                throw TestError.loadingFailed
            }
        )

        do {
            _ = try await useCase.execute()

            Issue.record(
                "Expected loading to fail"
            )
        } catch let error as TestError {
            #expect(error == .loadingFailed)
        } catch {
            Issue.record(
                "Received unexpected error: \(error)"
            )
        }
    }
}
