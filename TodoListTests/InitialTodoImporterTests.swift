import Foundation
import Testing
@testable import TodoList

@Suite
struct InitialTodoImporterTests {

    @Test
    func importsRemoteTodosIntoPersistentStorage() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"

        let defaults = try #require(
            UserDefaults(suiteName: suiteName)
        )

        defer {
            defaults.removePersistentDomain(
                forName: suiteName
            )
        }

        let stateStore = InitialTodoImportStateStore(
            defaults: defaults
        )
        
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
            storage: storage,
            stateStore: stateStore
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
    
    @Test
    func doesNotRequestTodosAfterSuccessfulImport() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"

        let defaults = try #require(
            UserDefaults(suiteName: suiteName)
        )

        defer {
            defaults.removePersistentDomain(
                forName: suiteName
            )
        }

        let stateStore = InitialTodoImportStateStore(
            defaults: defaults
        )

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
              "todo": "Imported once",
              "completed": false
            }
          ]
        }
        """

        let firstAPI = TodosAPI(
            dataLoader: { _ in
                (
                    Data(json.utf8),
                    response
                )
            }
        )

        let firstImporter = InitialTodoImporter(
            api: firstAPI,
            storage: storage,
            stateStore: stateStore
        )

        let firstImportedAt = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        try await firstImporter.run(
            importedAt: firstImportedAt
        )

        let secondAPI = TodosAPI(
            dataLoader: { _ -> (Data, URLResponse) in
                throw URLError(.badServerResponse)
            }
        )

        let secondImporter = InitialTodoImporter(
            api: secondAPI,
            storage: storage,
            stateStore: stateStore
        )

        try await secondImporter.run(
            importedAt: Date(
                timeIntervalSince1970: 1_800_000_000
            )
        )

        let items = try await storage.fetchAll()
        let item = try #require(items.first)

        #expect(items.count == 1)
        #expect(item.title == "Imported once")
        #expect(item.createdAt == firstImportedAt)
    }
    
    @Test
    func retriesImportAfterNetworkFailure() async throws {
        let suiteName =
            "InitialTodoImporterTests.\(UUID().uuidString)"

        let defaults = try #require(
            UserDefaults(suiteName: suiteName)
        )

        defer {
            defaults.removePersistentDomain(
                forName: suiteName
            )
        }

        let stateStore = InitialTodoImportStateStore(
            defaults: defaults
        )

        let stack = CoreDataStack(inMemory: true)
        try await stack.load()

        let storage = CoreDataTodoStorage(
            container: stack.container
        )

        let failingAPI = TodosAPI(
            dataLoader: { _ -> (Data, URLResponse) in
                throw URLError(.notConnectedToInternet)
            }
        )

        let failingImporter = InitialTodoImporter(
            api: failingAPI,
            storage: storage,
            stateStore: stateStore
        )

        do {
            try await failingImporter.run(
                importedAt: Date(
                    timeIntervalSince1970: 1_700_000_000
                )
            )

            Issue.record("Expected the network request to fail")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        }

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
              "todo": "Imported after retry",
              "completed": false
            }
          ]
        }
        """

        let successfulAPI = TodosAPI(
            dataLoader: { _ in
                (
                    Data(json.utf8),
                    response
                )
            }
        )

        let successfulImporter = InitialTodoImporter(
            api: successfulAPI,
            storage: storage,
            stateStore: stateStore
        )

        let successfulImportDate = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        try await successfulImporter.run(
            importedAt: successfulImportDate
        )

        let items = try await storage.fetchAll()
        let item = try #require(items.first)

        #expect(items.count == 1)
        #expect(item.title == "Imported after retry")
        #expect(item.createdAt == successfulImportDate)
    }
    
}
