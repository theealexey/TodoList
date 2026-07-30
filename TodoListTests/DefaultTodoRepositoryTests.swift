import Foundation
import Testing
@testable import TodoList

@Suite
struct DefaultTodoRepositoryTests {

    @Test
    func loadTodosImportsRemoteDataAndReturnsDomainItems() async throws {
        let suiteName =
            "DefaultTodoRepositoryTests.\(UUID().uuidString)"

        let defaults = try #require(
            UserDefaults(suiteName: suiteName)
        )

        defer {
            defaults.removePersistentDomain(
                forName: suiteName
            )
        }

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
              "id": 10,
              "todo": "Loaded through repository",
              "completed": false
            }
          ]
        }
        """

        let api = TodosAPI(
            dataLoader: { _ in
                (
                    Data(json.utf8),
                    response
                )
            }
        )

        let stateStore = InitialTodoImportStateStore(
            defaults: defaults
        )

        let importer = InitialTodoImporter(
            api: api,
            storage: storage,
            stateStore: stateStore
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
