import Foundation
import XCTest
@testable import TwitchKit

/// The JSON key strategy maps Twitch's snake_case keys onto API Design
/// Guidelines property names (`userID`, `thumbnailURL`) in both directions.
final class TwitchKeyCaseTests: XCTestCase {
    func testSnakeCaseKeysBecomeAcronymCasedNames() {
        let cases: [(String, String)] = [
            ("user_id", "userID"),
            ("user_ids", "userIDs"),
            ("thumbnail_url", "thumbnailURL"),
            ("verification_uri", "verificationURI"),
            ("broadcaster_user_id", "broadcasterUserID"),
            ("is_prime", "isPrime"),
            ("url_1x", "url1X"),
            ("image_url_1x", "imageURL1X"),
            ("id", "id"),
            ("_links", "_links"),
        ]
        for (key, expected) in cases {
            XCTAssertEqual(TwitchKeyCase.swiftName(fromSnakeCase: key), expected, key)
        }
    }

    func testAcronymCasedNamesBecomeSnakeCaseKeys() {
        let cases: [(String, String)] = [
            ("userID", "user_id"),
            ("userIDs", "user_ids"),
            ("thumbnailURL", "thumbnail_url"),
            ("broadcasterUserID", "broadcaster_user_id"),
            ("emoteSetID", "emote_set_id"),
            ("totalCost", "total_cost"),
            ("id", "id"),
            ("session_id", "session_id"),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(TwitchKeyCase.snakeCase(fromSwiftName: name), expected, name)
        }
    }

    func testEncoderAndDecoderRoundTripAcronymProperties() throws {
        struct Payload: Codable, Equatable {
            let userID: String
            let userIDs: [String]
            let thumbnailURL: String
        }
        let value = Payload(userID: "1", userIDs: ["2", "3"], thumbnailURL: "https://example.com")

        let data = try JSONEncoder.twitch().encode(value)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["user_id", "user_ids", "thumbnail_url"])
        XCTAssertEqual(try JSONDecoder.twitch().decode(Payload.self, from: data), value)
    }

    func testStringKeyedDictionariesKeepTheirKeys() throws {
        struct Payload: Decodable {
            let condition: [String: String]
        }
        let json = Data(#"{"condition":{"broadcaster_user_id":"1"}}"#.utf8)
        let decoded = try JSONDecoder.twitch().decode(Payload.self, from: json)
        XCTAssertEqual(decoded.condition, ["broadcaster_user_id": "1"])
    }
}
