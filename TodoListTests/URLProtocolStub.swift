import Foundation

final class URLProtocolStub: URLProtocol {

    typealias Handler = @Sendable (
        URLRequest
    ) throws -> (HTTPURLResponse, Data)

    private enum Header {
        static let handlerID =
            "X-URLProtocolStub-Handler-ID"
    }

    private final class Registry: @unchecked Sendable {

        private let lock = NSLock()
        private var handlers: [String: Handler] = [:]

        func register(
            _ handler: @escaping Handler
        ) -> String {
            let id = UUID().uuidString

            lock.withLock {
                handlers[id] = handler
            }

            return id
        }

        func handler(
            for id: String
        ) -> Handler? {
            lock.withLock {
                handlers[id]
            }
        }
    }

    private static let registry = Registry()

    static func makeSession(
        handler: @escaping Handler
    ) -> URLSession {
        let handlerID = registry.register(handler)

        let configuration =
            URLSessionConfiguration.ephemeral

        configuration.protocolClasses = [
            URLProtocolStub.self
        ]

        configuration.httpAdditionalHeaders = [
            Header.handlerID: handlerID
        ]

        return URLSession(
            configuration: configuration
        )
    }

    override class func canInit(
        with request: URLRequest
    ) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let handlerID = request.value(
                forHTTPHeaderField: Header.handlerID
            ),
            let handler = Self.registry.handler(
                for: handlerID
            )
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.unknown)
            )
            return
        }

        do {
            let (response, data) = try handler(request)

            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )

            client?.urlProtocol(
                self,
                didLoad: data
            )

            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(
                self,
                didFailWithError: error
            )
        }
    }

    override func stopLoading() {}
}
