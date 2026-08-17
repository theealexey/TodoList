import Foundation

protocol NetworkSession: Sendable {
    func data(
        for request: URLRequest
    ) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {

    func data(
        for request: URLRequest
    ) async throws -> (Data, URLResponse) {
        try await data(
            for: request,
            delegate: nil
        )
    }
}
