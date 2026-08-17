import Foundation
import Testing
@testable import TodoList

@Suite
struct DefaultTodoRepositoryTests {

    @Test
    func loadTodosImportsRemoteDataAndReturnsDomainItems() async throws {
        let suiteName =
            "DefaultTodoRepositoryTests.\(UUID().uuidString)"


        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        

        let json = """
        {
          "todos": [
            {
              "id": 10,
              "todo": "Loaded through repository",
              "completed": false
            }
          ]
        }
        """
        
        let session = URLProtocolStub.makeSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            #expect(
                url.absoluteString
                    == "https://dummyjson.com/todos?limit=0"
            )

            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw URLError(.badServerResponse)
            }

            return (
                response,
                Data(json.utf8)
            )
        }

        let api = TodosAPI(
            session: session
        )

        let stateStore = InitialTodoImportStateStore(
            namespace: suiteName
        )

        defer {
            stateStore.reset()
        }

        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore,
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

        let items = try await repository.loadTodos()
        let item = try #require(items.first)

        #expect(items.count == 1)
        #expect(item.title == "Loaded through repository")
        #expect(item.createdAt == importedAt)
        #expect(item.status == .pending)
    }
}
