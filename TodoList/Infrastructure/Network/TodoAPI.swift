import Foundation

struct TodosAPI {

    private let session: URLSession
    private let operationQueue: OperationQueue
    
    init(
        session: URLSession = .shared,
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.session = session
        self.operationQueue = operationQueue

        operationQueue.qualityOfService = .userInitiated
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

        return try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<[TodoDTO], Error>
            ) in
            
            let operation = TodosFetchOperation(
                request: request,
                session: session
            ) { result in
                continuation.resume(with: result)
            }
            
            operationQueue.addOperation(operation)
        }

    }
}
