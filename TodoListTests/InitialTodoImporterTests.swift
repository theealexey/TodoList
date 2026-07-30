import Foundation
import Testing
@testable import TodoList

@Suite
struct InitialTodoImporterTests {

    @Test
    func importsRemoteTodosIntoPersistentStorage() async throws {
        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        let url = try #require(
            URL(string: "https://dummyjson.com/todos?limit=0")
        )

        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )

        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "First imported task",
              "completed": false
            },
            {
              "id": 2,
              "todo": "Second imported task",
              "completed": true
            }
          ],
          "total": 2,
          "skip": 0,
          "limit": 0
        }
        """

        let api = TodosAPI(
            dataLoader: { request in
                #expect(request.url == url)

                return (
                    Data(json.utf8),
                    response
                )
            }
        )

        let importer = InitialTodoImporter(
            api: api,
            storage: storage
        )

        let importedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        try await importer.run(
            importedAt: importedAt
        )

        let items = try await storage.fetchAll()

        #expect(items.count == 2)

        #expect(
            items.contains {
                $0.title == "First imported task"
                    && $0.details.isEmpty
                    && $0.createdAt == importedAt
                    && $0.status == .pending
            }
        )

        #expect(
            items.contains {
                $0.title == "Second imported task"
                    && $0.details.isEmpty
                    && $0.createdAt == importedAt
                    && $0.status == .completed
            }
        )
    }
}
