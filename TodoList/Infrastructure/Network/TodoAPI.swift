import Foundation

struct TodosAPI {

    typealias DataLoader = (
        URLRequest
    ) async throws -> (Data, URLResponse)

    private let dataLoader: DataLoader

    init(session: URLSession = .shared) {
        dataLoader = { request in
            try await session.data(for: request)
        }
    }

    init(dataLoader: @escaping DataLoader) {
        self.dataLoader = dataLoader
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

        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let responseDTO = try JSONDecoder().decode(
            TodosResponseDTO.self,
            from: data
        )

        return responseDTO.todos
    }
}
