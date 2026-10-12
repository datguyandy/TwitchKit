import Foundation
import XCTest
@testable import TwitchKit

final class StatusEnumTests: XCTestCase {
    func testHelixAndEventSubCasingDecodeToTheSameCase() throws {
        let polls = try JSONDecoder().decode([TwitchPollStatus].self, from: Data(#"["ACTIVE","completed","Terminated"]"#.utf8))
        let predictions = try JSONDecoder().decode([TwitchPredictionStatus].self, from: Data(#"["RESOLVED","canceled"]"#.utf8))
        let guests = try JSONDecoder().decode([GuestStarGuestState].self, from: Data(#"["INVITED","backstage"]"#.utf8))
        let automod = try JSONDecoder().decode([AutoModMessageStatus].self, from: Data(#"["Approved","denied"]"#.utf8))

        XCTAssertEqual(polls, [.active, .completed, .terminated])
        XCTAssertEqual(predictions, [.resolved, .canceled])
        XCTAssertEqual(guests, [.invited, .backstage])
        XCTAssertEqual(automod, [.approved, .denied])
    }

    func testSuspiciousUserNoTreatmentAcceptsBothSpellings() throws {
        let statuses = try JSONDecoder().decode([SuspiciousUserStatus].self, from: Data(#"["NO_TREATMENT","none","active_monitoring"]"#.utf8))

        XCTAssertEqual(statuses, [.noTreatment, .noTreatment, .activeMonitoring])
        XCTAssertEqual(SuspiciousUserStatus.noTreatment.rawValue, "NO_TREATMENT")
    }

    func testUnknownValuesAreKeptVerbatim() throws {
        let status = try JSONDecoder().decode(ConduitShardStatus.self, from: Data(#""websocket_something_new""#.utf8))

        XCTAssertEqual(status, .unknown("websocket_something_new"))
        XCTAssertEqual(status.rawValue, "websocket_something_new")
        let encoded = try JSONEncoder().encode(status)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), #""websocket_something_new""#)
    }

    func testStringLiteralComparisonsStillCompile() {
        let poll: TwitchPollStatus = .active
        let extensionState: ExtensionState = .inReview

        XCTAssertTrue(poll == "ACTIVE")
        XCTAssertTrue(poll == "active")
        XCTAssertTrue(extensionState == "InReview")
    }

    func testRequestParametersKeepSendingTwitchValues() {
        XCTAssertEqual(UnbanRequestStatus.pending.rawValue, "pending")
        XCTAssertEqual(DropsEntitlementFulfillmentStatus.fulfilled.rawValue, "FULFILLED")
        XCTAssertEqual(SuspiciousUserStatus.restricted.rawValue, "RESTRICTED")
        XCTAssertEqual(ConduitShardStatus.websocketFailedToReconnect.rawValue, "websocket_failed_to_reconnect")
    }

    func testModelDecodesTypedStatus() throws {
        let json = #"{"data":[{"status":"UPDATE_FAILED","ids":["a","b"]}]}"#
        let response = try JSONDecoder.twitch().decode(HelixResponse<DropsEntitlementUpdateResult>.self, from: Data(json.utf8))

        XCTAssertEqual(response.data.first?.status, .updateFailed)
    }
}
