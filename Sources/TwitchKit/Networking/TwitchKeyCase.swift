import Foundation

/// Converts between Twitch's snake_case wire keys and TwitchKit's Swift property
/// names, which follow the API Design Guidelines' acronym casing (`userID`,
/// `thumbnailURL`, `userIDs`). Foundation's `.convertFromSnakeCase` would produce
/// `userId`, and `.convertToSnakeCase` turns `userIDs` into `user_i_ds`, so both
/// directions are handled here.
enum TwitchKeyCase {
    private static let acronyms: [String: String] = [
        "id": "ID", "ids": "IDs", "url": "URL", "urls": "URLs", "uri": "URI",
    ]

    /// `user_id` → `userID`, `thumbnail_url` → `thumbnailURL`, `url_1x` → `url1X`.
    static func swiftName(fromSnakeCase key: String) -> String {
        guard key.contains("_") else { return key }
        // Preserve leading/trailing underscores, as `.convertFromSnakeCase` does.
        let leading = key.prefix { $0 == "_" }
        let trailing = key.reversed().prefix { $0 == "_" }
        let core = key.dropFirst(leading.count).dropLast(trailing.count)
        let words = core.split(separator: "_", omittingEmptySubsequences: true)
        guard let first = words.first else { return key }
        var result = String(leading) + first
        for word in words.dropFirst() {
            let lower = word.lowercased()
            // `capitalized` matches `.convertFromSnakeCase` exactly (`1x` → `1X`).
            result += acronyms[lower] ?? word.capitalized
        }
        return result + String(trailing)
    }

    /// `userID` → `user_id`, `userIDs` → `user_ids`, `thumbnailURL` → `thumbnail_url`.
    static func snakeCase(fromSwiftName name: String) -> String {
        var words: [String] = []
        var current = ""
        let chars = Array(name)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char.isUppercase {
                // Prefer a known acronym hump (`IDs`, `URLs`, `ID`, `URL`, `URI`).
                if let match = ["IDs", "URLs", "ID", "URL", "URI"].first(where: { acronym in
                    let end = index + acronym.count
                    guard end <= chars.count, String(chars[index..<end]) == acronym else { return false }
                    return end == chars.count || !chars[end].isLowercase
                }) {
                    if !current.isEmpty { words.append(current) }
                    words.append(match.lowercased())
                    current = ""
                    index += match.count
                    continue
                }
                if !current.isEmpty { words.append(current) }
                current = String(char).lowercased()
            } else {
                current.append(char)
            }
            index += 1
        }
        if !current.isEmpty { words.append(current) }
        return words.joined(separator: "_")
    }
}

struct TwitchCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
