import Foundation
import Synchronization

final class URLProtocolStub: URLProtocol {

    typealias Handler = @Sendable (
        URLRequest
    ) throws -> (HTTPURLResponse, Data)

    private enum Header {
        static let handlerID =
            "X-URLProtocolStub-Handler-ID"
    }

    private struct Behavior: Sendable {
        let handler: Handler?
        let onStart: @Sendable (URLRequest) -> Void
        let onStop: @Sendable () -> Void
    }

    private final class Registry: Sendable {

        private let behaviors = Mutex([String: Behavior]())

        func register(
            _ behavior: Behavior
        ) -> String {
            let id = UUID().uuidString

            behaviors.withLock {
                $0[id] = behavior
            }

            return id
        }

        func behavior(
            for id: String
        ) -> Behavior? {
            behaviors.withLock {
                $0[id]
            }
        }

        func removeBehavior(
            for id: String
        ) {
            behaviors.withLock {
                $0[id] = nil
            }
        }
    }

    private static let registry = Registry()

    static func makeSession(
        handler: @escaping Handler
    ) -> URLSession {
        makeSession(
            behavior: Behavior(
                handler: handler,
                onStart: { _ in },
                onStop: {}
            )
        )
    }

    static func makeControlledSession(
        onStart: @escaping @Sendable (URLRequest) -> Void,
        onStop: @escaping @Sendable () -> Void
    ) -> URLSession {
        makeSession(
            behavior: Behavior(
                handler: nil,
                onStart: onStart,
                onStop: onStop
            )
        )
    }

    static func invalidate(
        _ session: URLSession
    ) {
        let handlerID = session.configuration
            .httpAdditionalHeaders?[Header.handlerID] as? String

        session.invalidateAndCancel()

        if let handlerID {
            registry.removeBehavior(for: handlerID)
        }
    }

    private static func makeSession(
        behavior: Behavior
    ) -> URLSession {
        let handlerID = registry.register(behavior)

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
            let behavior = Self.registry.behavior(
                for: handlerID
            )
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.unknown)
            )
            return
        }

        behavior.onStart(request)

        guard let handler = behavior.handler else {
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

    override func stopLoading() {
        guard
            let handlerID = request.value(
                forHTTPHeaderField: Header.handlerID
            ),
            let behavior = Self.registry.behavior(
                for: handlerID
            )
        else {
            return
        }

        behavior.onStop()
    }
}
