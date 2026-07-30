import Foundation
import Testing
@testable import TodoList

struct TodosResponseDTOTests {

    @Test
    func decodesTodosResponse() throws {
        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Do something nice",
              "completed": false,
              "userId": 152
            }
          ],
          "total": 254,
          "skip": 0,
          "limit": 30
        }
        """

        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(
            TodosResponseDTO.self,
            from: data
        )

        #expect(response.todos.count == 1)

        let todo = try #require(response.todos.first)

        #expect(todo.id == 1)
        #expect(todo.todo == "Do something nice")
        #expect(todo.completed == false)
    }
    
    @Test
    func failsWhenCompletedFieldIsMissing() throws {
        let json = """
        {
          "todos": [
            {
              "id": 1,
              "todo": "Do something nice"
            }
          ]
        }
        """

        let data = try #require(json.data(using: .utf8))

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                TodosResponseDTO.self,
                from: data
            )
        }
    }
}
