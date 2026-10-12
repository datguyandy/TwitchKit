import XCTest
@testable import TwitchKit

final class TwitchScopeTests: XCTestCase {
    func test_allKnownScopeFamiliesAreRepresented() {
        let scopes = Set(TwitchScope.allCases.map(\.rawValue))

        XCTAssertTrue(scopes.contains("analytics:read:extensions"))
        XCTAssertTrue(scopes.contains("channel:manage:polls"))
        XCTAssertTrue(scopes.contains("moderator:manage:warnings"))
        XCTAssertTrue(scopes.contains("user:read:whispers"))
        XCTAssertTrue(scopes.contains("chat:edit"))
        XCTAssertTrue(scopes.contains("whispers:read"))
    }

    func test_anyScopeStringIsAScope() {
        let literal: TwitchScope = "user:read:new_thing"

        XCTAssertEqual(literal, TwitchScope("user:read:new_thing"))
        XCTAssertEqual(literal.rawValue, "user:read:new_thing")
        XCTAssertEqual(TwitchScope(rawValue: "user:read:chat"), .userReadChat)
        XCTAssertEqual("\(TwitchScope.userReadChat)", "user:read:chat")
        XCTAssertFalse(TwitchScope.allCases.contains(literal))
    }

    func test_knownScopesKeepTheirStrings() {
        XCTAssertEqual(TwitchScope.channelBot.rawValue, "channel:bot")
        XCTAssertEqual(TwitchScope.moderatorManageBannedUsers.rawValue, "moderator:manage:banned_users")
        XCTAssertEqual(TwitchScope.allCases.count, Set(TwitchScope.allCases).count, "no scope is listed twice")
        XCTAssertEqual(TwitchScope.allCases.count, 81)
    }

    func test_scopesEncodeAsStrings() throws {
        let scopes: [TwitchScope] = [.userReadChat, "future:scope"]

        let data = try JSONEncoder().encode(scopes)

        XCTAssertEqual(String(data: data, encoding: .utf8), #"["user:read:chat","future:scope"]"#)
        XCTAssertEqual(try JSONDecoder().decode([TwitchScope].self, from: data), scopes)
    }
}
