import Foundation

/// A transport that performs HTTP requests for TwitchKit.
public protocol HTTPClient: Sendable {
    /// Performs the request and returns the response data and metadata.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default HTTP transport backed by `URLSession`.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    @concurrent
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
