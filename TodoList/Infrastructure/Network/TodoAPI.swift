import Foundation

struct TodosAPI: TodosFetching {

    private let session: any NetworkSession

    init(
        session: any NetworkSession = URLSession.shared
    ) {
        self.session = session
    }

    func fetchTodos() async throws -> [TodoDTO] {
        guard let url = URL(
            string: "https://dummyjson.com/todos?limit=0"
        ) else {
            throw URLError(.badURL)
        }

        let request = URLRequest(
            url: url,
            timeoutInterval: 15
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(
                for: request
            )
        } catch let error as URLError
            where error.code == .cancelled {
            throw CancellationError()
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let responseDTO = try JSONDecoder().decode(
            TodosResponseDTO.self,
            from: data
        )

        return responseDTO.todos
    }
}
