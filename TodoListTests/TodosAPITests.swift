import Foundation
import Testing
@testable import TodoList

struct TodosAPITests {
    
    @Test
    func fetchTodosReturnsDecodedTodosForSuccessfulResponse() async throws {
        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Do something nice",
              "completed": false
            }
          ]
        }
        """

        let data = try #require(json.data(using: .utf8))

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

            return (response, data)
        }

        let api = TodosAPI(
            session: session
        )

        let todos = try await api.fetchTodos()

        #expect(todos.count == 1)

        let todo = try #require(todos.first)

        #expect(todo.id == 1)
        #expect(todo.todo == "Do something nice")
        #expect(todo.completed == false)
    }
    
    @Test
    func fetchTodosThrowsBadServerResponseForHTTP500() async throws {
        let session = URLProtocolStub.makeSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw URLError(.badServerResponse)
            }

            return (response, Data())
        }

        let api = TodosAPI(
            session: session
        )

        do {
            _ = try await api.fetchTodos()
            Issue.record("Expected fetchTodos() to throw")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test
    func fetchTodosThrowsDecodingErrorForInvalidJSON() async throws {
        let invalidJSON = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Do something nice",
              "completed": "not-a-boolean"
            }
          ]
        }
        """

        let data = try #require(invalidJSON.data(using: .utf8))

        let session = URLProtocolStub.makeSession { request in
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

            return (response, data)
        }

        let api = TodosAPI(
            session: session
        )
        
        do {
            _ = try await api.fetchTodos()
            Issue.record("Expected fetchTodos() to throw DecodingError")
        } catch is DecodingError {
            // Ожидаемая ошибка.
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
