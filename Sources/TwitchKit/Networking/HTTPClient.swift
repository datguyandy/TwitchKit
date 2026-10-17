import Foundation

/// A transport that performs HTTP requests for TwitchKit.
public protocol HTTPClient: Sendable {
    /// Performs the request and returns the response data and metadata.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default HTTP transport backed by `URLSession`.
///
/// By default it uses ``ephemeralSession``, which keeps no disk cache, no
/// cookies and no credentials, so authenticated responses (a stream key, a
/// user's email, `/oauth2/validate`) and `id.twitch.tv` cookies never touch
/// disk. Pass your own `URLSession` to change that.
public struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    public init(session: URLSession = URLSessionHTTPClient.ephemeralSession) {
        self.session = session
    }

    /// A shared session with no URL cache, cookie storage or credential
    /// storage, that ignores locally cached data.
    public static let ephemeralSession: URLSession = URLSession(configuration: ephemeralConfiguration())

    /// The configuration behind ``ephemeralSession``: start from it to build
    /// a session of your own that keeps the same privacy properties.
    public static func ephemeralConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCredentialStorage = nil
        return configuration
    }

    @concurrent
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
