import Foundation
import Synchronization
import Testing
@testable import TodoList

@Suite
struct TodoPipelineIntegrationTests {

    @Test
    func loadUseCaseImportsRemoteTodosAndReturnsPersistedDomainItems() async throws {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let requestCount = Mutex(0)
        let json = """
        {
          "todos": [
            {
              "id": 42,
              "todo": "Pipeline task",
              "completed": true
            }
          ]
        }
        """

        let session = URLProtocolStub.makeSession { request in
            requestCount.withLock {
                $0 += 1
            }

            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }

            return (response, Data(json.utf8))
        }
        defer {
            URLProtocolStub.invalidate(session)
        }

        let storage = CoreDataTodoStorage(
            container: stack.container
        )
        let importer = InitialTodoImporter(
            api: TodosAPI(session: session),
            storage: storage,
            stateStore: InitialTodoImportStateStore(
                namespace: "TodoPipelineIntegrationTests.\(UUID().uuidString)"
            ),
            storeIdentifier: try stack.loadedStoreIdentifier()
        )
        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )
        let repository = DefaultTodoRepository(
            importer: importer,
            storage: storage,
            currentDate: { importedAt }
        )
        let useCase = LoadTodosUseCase(
            repository: repository
        )

        let items = try await useCase.execute()
        let item = try #require(items.first)

        #expect(requestCount.withLock { $0 } == 1)
        #expect(items.count == 1)
        #expect(item.title == "Pipeline task")
        #expect(item.details.isEmpty)
        #expect(item.createdAt == importedAt)
        #expect(item.status == .completed)

        let persistedItems = try await storage.fetchAll()
        #expect(persistedItems == items)
    }
}
