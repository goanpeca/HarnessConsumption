import Foundation

/// A `URLSession` whose requests never leave the process: each one is answered by the handler a test
/// registered for that session, and recorded so the test can inspect what was sent.
struct StubSession {
    struct Reply {
        var status: Int = 200
        var body = Data()
        var failure: Error?

        static func json(_ text: String, status: Int = 200) -> Self {
            Self(status: status, body: Data(text.utf8))
        }
    }

    let session: URLSession
    private let id: String

    init(_ handler: @escaping @Sendable (URLRequest) -> Reply) {
        id = UUID().uuidString
        StubRegistry.shared.register(id: id, handler: handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [StubURLProtocol.idHeader: id]
        session = URLSession(configuration: configuration)
    }

    /// Every request sent through this session, oldest first.
    var requests: [URLRequest] { StubRegistry.shared.requests(id: id) }
}

final class StubRegistry: @unchecked Sendable {
    static let shared = StubRegistry()
    private let lock = NSLock()
    private var handlers: [String: @Sendable (URLRequest) -> StubSession.Reply] = [:]
    private var log: [String: [URLRequest]] = [:]

    func register(id: String, handler: @escaping @Sendable (URLRequest) -> StubSession.Reply) {
        lock.withLock { handlers[id] = handler }
    }

    func reply(id: String, to request: URLRequest) -> StubSession.Reply? {
        lock.withLock {
            log[id, default: []].append(request)
            return handlers[id]?(request)
        }
    }

    func requests(id: String) -> [URLRequest] { lock.withLock { log[id] ?? [] } }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let idHeader = "X-Stub-Session"

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: Self.idHeader) ?? ""
        guard let reply = StubRegistry.shared.reply(id: id, to: request), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        if let failure = reply.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil)
        client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
