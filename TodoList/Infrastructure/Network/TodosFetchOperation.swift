import Foundation

final class TodosFetchOperation: AsyncOperation, @unchecked Sendable {

    typealias Completion = (Result<[TodoDTO], Error>) -> Void

    private let request: URLRequest
    private let session: URLSession
    private let completion: Completion

    private let taskLock = NSLock()
    private var dataTask: URLSessionDataTask?

    init(
        request: URLRequest,
        session: URLSession,
        completion: @escaping Completion
    ) {
        self.request = request
        self.session = session
        self.completion = completion
    }

    override func main() {
        guard !isCancelled else {
            finish()
            return
        }

        let task = session.dataTask(
            with: request
        ) { [weak self] data, response, error in
            guard let self else {
                return
            }

            defer {
                self.finish()
            }

            if let error {
                self.completion(.failure(error))
                return
            }

            guard let data else {
                self.completion(
                    .failure(URLError(.badServerResponse))
                )
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.completion(
                    .failure(URLError(.badServerResponse))
                )
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                self.completion(
                    .failure(URLError(.badServerResponse))
                )
                return
            }

            do {
                let responseDTO = try JSONDecoder().decode(
                    TodosResponseDTO.self,
                    from: data
                )

                self.completion(
                    .success(responseDTO.todos)
                )
            } catch {
                self.completion(.failure(error))
            }
        }

        taskLock.withLock {
            dataTask = task
        }

        task.resume()
    }

    override func cancel() {
        super.cancel()

        let task = taskLock.withLock {
            dataTask
        }

        task?.cancel()
    }
}
