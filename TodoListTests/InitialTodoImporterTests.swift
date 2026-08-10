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

        let firstSession = URLProtocolStub.makeSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

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

        let firstAPI = TodosAPI(
            session: firstSession
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

        let secondSession = URLProtocolStub.makeSession { _ in
            throw URLError(.badServerResponse)
        }

        let secondAPI = TodosAPI(
            session: secondSession
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

        let failingSession = URLProtocolStub.makeSession { _ in
            throw URLError(.notConnectedToInternet)
        }

        let failingAPI = TodosAPI(
            session: failingSession
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

        let successfulSession = URLProtocolStub.makeSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

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

        let successfulAPI = TodosAPI(
            session: successfulSession
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
