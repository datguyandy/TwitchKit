import Foundation

enum HelixQuery {
    static func item(_ name: String, _ value: String?) -> URLQueryItem? {
        value.map { URLQueryItem(name: name, value: $0) }
    }

    static func items(_ name: String, values: [String]) -> [URLQueryItem] {
        values.map { URLQueryItem(name: name, value: $0) }
    }

    static func append(_ item: URLQueryItem?, to queryItems: inout [URLQueryItem]) {
        if let item {
            queryItems.append(item)
        }
    }

    static func appendPagination(
        to queryItems: inout [URLQueryItem],
        first: Int?,
        after cursor: String?,
        before previousCursor: String? = nil,
        validRange: ClosedRange<Int> = 1...100
    ) throws {
        if let first {
            guard validRange.contains(first) else {
                throw HelixError.badRequest(
                    TwitchAPIError.fallback(
                        status: 400,
                        message: "Page size must be between \(validRange.lowerBound) and \(validRange.upperBound)"
                    )
                )
            }
            queryItems.append(URLQueryItem(name: "first", value: String(first)))
        }

        if let cursor {
            queryItems.append(URLQueryItem(name: "after", value: cursor))
        }

        if let previousCursor {
            queryItems.append(URLQueryItem(name: "before", value: previousCursor))
        }
    }
}

extension URLComponents {
    /// Sets `queryItems`, additionally percent-encoding `+` in names and values.
    ///
    /// `URLComponents` leaves `+` literal because RFC 3986 allows it in a
    /// query, but form-style decoders (Twitch's included) read a literal `+`
    /// as a space. Without this, values such as `utc_offset=+05:30`, the
    /// timezone `Etc/GMT+5`, a search for `C++`, or a pagination cursor
    /// containing `+` reach Twitch altered.
    mutating func setFormSafeQueryItems(_ queryItems: [URLQueryItem]?) {
        self.queryItems = queryItems
        percentEncodedQuery = percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    }
}
