import Foundation

extension HelixClient {
    /// Checks whether AutoMod would flag messages for review.
    public func checkAutoModStatus(
        broadcasterID: String,
        messages: [AutoModMessage]
    ) async throws -> [AutoModStatus] {
        guard !messages.isEmpty else {
            throw HelixError.badRequest(TwitchAPIError.fallback(status: 400, message: "At least one AutoMod message is required"))
        }

        let response: HelixResponse<AutoModStatus> = try await request(
            endpoint: "moderation/enforcements/status",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)],
            body: try JSONEncoder.twitch().encode(AutoModStatusRequest(data: messages))
        )
        return response.data
    }

    /// Allows or denies a message held by AutoMod.
    public func manageHeldAutoModMessage(userID: String, messageID: String, action: HeldAutoModMessageAction) async throws {
        try await requestNoContent(
            endpoint: "moderation/automod/message",
            method: "POST",
            body: try JSONEncoder.twitch().encode(HeldAutoModMessageRequest(
                userId: userID,
                msgId: messageID,
                action: action.rawValue
            ))
        )
    }

    /// Gets a broadcaster's AutoMod settings.
    public func fetchAutoModSettings(broadcasterID: String, moderatorID: String) async throws -> AutoModSettings {
        let response: HelixResponse<AutoModSettings> = try await request(
            endpoint: "moderation/automod/settings",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ]
        )
        guard let settings = response.data.first else { throw HelixError.emptyResponse }
        return settings
    }

    /// Updates a broadcaster's AutoMod settings.
    public func updateAutoModSettings(
        broadcasterID: String,
        moderatorID: String,
        with update: AutoModSettingsUpdate
    ) async throws -> AutoModSettings {
        let response: HelixResponse<AutoModSettings> = try await request(
            endpoint: "moderation/automod/settings",
            method: "PUT",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(update)
        )
        guard let settings = response.data.first else { throw HelixError.emptyResponse }
        return settings
    }

    /// Gets one page of banned or timed-out users.
    public func fetchBannedUsersPage(
        broadcasterID: String,
        userIDs: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<BannedUser> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)
        let response: HelixResponse<BannedUser> = try await request(endpoint: "moderation/banned", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of banned or timed-out users.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - userIDs: Optional user IDs used to check specific bans.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Banned Users](https://dev.twitch.tv/docs/api/reference/#get-banned-users)
    public func bannedUsers(
        broadcasterID: String,
        userIDs: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<BannedUser> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        return pagedRequest(endpoint: "moderation/banned", queryItems: queryItems, pageSize: pageSize)
    }

    /// Bans a user or puts them in a timeout.
    public func banUser(
        broadcasterID: String,
        moderatorID: String,
        userID: String,
        duration: Int? = nil,
        reason: String? = nil
    ) async throws -> BanUserResponse {
        let response: HelixResponse<BanUserResponse> = try await request(
            endpoint: "moderation/bans",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(BanUserRequest(data: BanUserRequest.DataBody(
                userId: userID,
                duration: duration,
                reason: reason
            )))
        )
        guard let ban = response.data.first else { throw HelixError.emptyResponse }
        return ban
    }

    /// Removes a ban or timeout from a user.
    public func unbanUser(broadcasterID: String, moderatorID: String, userID: String) async throws {
        try await requestNoContent(
            endpoint: "moderation/bans",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
                URLQueryItem(name: "user_id", value: userID),
            ]
        )
    }

    /// Gets one page of unban requests.
    public func fetchUnbanRequestsPage(
        broadcasterID: String,
        moderatorID: String,
        status: UnbanRequestStatus,
        userID: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<UnbanRequest> {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
            URLQueryItem(name: "status", value: status.rawValue),
        ]
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<UnbanRequest> = try await request(
            endpoint: "moderation/unban_requests",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of unban requests.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - moderatorID: The moderator's user ID (or the broadcaster's own ID).
    ///   - status: The unban request status to filter by.
    ///   - userID: Optional user ID used to return that user's requests.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Unban Requests](https://dev.twitch.tv/docs/api/reference/#get-unban-requests)
    public func unbanRequests(
        broadcasterID: String,
        moderatorID: String,
        status: UnbanRequestStatus,
        userID: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<UnbanRequest> {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
            URLQueryItem(name: "status", value: status.rawValue),
        ]
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        return pagedRequest(endpoint: "moderation/unban_requests", queryItems: queryItems, pageSize: pageSize)
    }

    /// Resolves an unban request.
    public func resolveUnbanRequest(
        broadcasterID: String,
        moderatorID: String,
        unbanRequestID: String,
        status: UnbanRequestResolutionStatus
    ) async throws -> UnbanRequest {
        let response: HelixResponse<UnbanRequest> = try await request(
            endpoint: "moderation/unban_requests",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
                URLQueryItem(name: "unban_request_id", value: unbanRequestID),
                URLQueryItem(name: "status", value: status.rawValue),
            ]
        )
        guard let request = response.data.first else { throw HelixError.emptyResponse }
        return request
    }

    /// Gets one page of blocked terms.
    public func fetchBlockedTermsPage(
        broadcasterID: String,
        moderatorID: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<BlockedTerm> {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
        ]
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)
        let response: HelixResponse<BlockedTerm> = try await request(
            endpoint: "moderation/blocked_terms",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of blocked terms.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - moderatorID: The moderator's user ID (or the broadcaster's own ID).
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Blocked Terms](https://dev.twitch.tv/docs/api/reference/#get-blocked-terms)
    public func blockedTerms(
        broadcasterID: String,
        moderatorID: String,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<BlockedTerm> {
        pagedRequest(
            endpoint: "moderation/blocked_terms",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            pageSize: pageSize
        )
    }

    /// Adds a blocked term.
    public func addBlockedTerm(broadcasterID: String, moderatorID: String, text: String) async throws -> BlockedTerm {
        let response: HelixResponse<BlockedTerm> = try await request(
            endpoint: "moderation/blocked_terms",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(BlockedTermRequest(text: text))
        )
        guard let term = response.data.first else { throw HelixError.emptyResponse }
        return term
    }

    /// Removes a blocked term.
    public func removeBlockedTerm(broadcasterID: String, moderatorID: String, id: String) async throws {
        try await requestNoContent(
            endpoint: "moderation/blocked_terms",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
                URLQueryItem(name: "id", value: id),
            ]
        )
    }

    /// Deletes one chat message, or all chat messages when `messageID` is omitted.
    public func deleteChatMessages(broadcasterID: String, moderatorID: String, messageID: String? = nil) async throws {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
        ]
        HelixQuery.append(HelixQuery.item("message_id", messageID), to: &queryItems)
        try await requestNoContent(endpoint: "moderation/chat", method: "DELETE", queryItems: queryItems)
    }

    /// Gets one page of channels moderated by a user.
    public func fetchModeratedChannelsPage(
        userID: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<ModeratedChannel> {
        var queryItems = [URLQueryItem(name: "user_id", value: userID)]
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)
        let response: HelixResponse<ModeratedChannel> = try await request(
            endpoint: "moderation/channels",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of channels moderated by a user.
    ///
    /// - Parameters:
    ///   - userID: The user whose moderated channels are returned.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Moderated Channels](https://dev.twitch.tv/docs/api/reference/#get-moderated-channels)
    public func moderatedChannels(
        userID: String,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<ModeratedChannel> {
        pagedRequest(
            endpoint: "moderation/channels",
            queryItems: [URLQueryItem(name: "user_id", value: userID)],
            pageSize: pageSize
        )
    }

    /// Gets one page of moderators for a broadcaster.
    public func fetchModeratorsPage(
        broadcasterID: String,
        userIDs: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<ModeratorUser> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)
        let response: HelixResponse<ModeratorUser> = try await request(endpoint: "moderation/moderators", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of moderators for a broadcaster.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - userIDs: Optional user IDs used to check specific moderators.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Moderators](https://dev.twitch.tv/docs/api/reference/#get-moderators)
    public func moderators(
        broadcasterID: String,
        userIDs: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<ModeratorUser> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        return pagedRequest(endpoint: "moderation/moderators", queryItems: queryItems, pageSize: pageSize)
    }

    /// Adds a channel moderator.
    public func addChannelModerator(broadcasterID: String, userID: String) async throws {
        try await requestNoContent(
            endpoint: "moderation/moderators",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "user_id", value: userID),
            ]
        )
    }

    /// Removes a channel moderator.
    public func removeChannelModerator(broadcasterID: String, userID: String) async throws {
        try await requestNoContent(
            endpoint: "moderation/moderators",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "user_id", value: userID),
            ]
        )
    }

    /// Gets one page of VIPs for a broadcaster.
    public func fetchVIPsPage(
        broadcasterID: String,
        userIDs: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<VIPUser> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)
        let response: HelixResponse<VIPUser> = try await request(endpoint: "channels/vips", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of VIPs for a broadcaster.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - userIDs: Optional user IDs used to check specific VIPs.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get VIPs](https://dev.twitch.tv/docs/api/reference/#get-vips)
    public func vips(
        broadcasterID: String,
        userIDs: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<VIPUser> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        return pagedRequest(endpoint: "channels/vips", queryItems: queryItems, pageSize: pageSize)
    }

    /// Adds a channel VIP.
    public func addChannelVIP(broadcasterID: String, userID: String) async throws {
        try await requestNoContent(
            endpoint: "channels/vips",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "user_id", value: userID),
            ]
        )
    }

    /// Removes a channel VIP.
    public func removeChannelVIP(broadcasterID: String, userID: String) async throws {
        try await requestNoContent(
            endpoint: "channels/vips",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "user_id", value: userID),
            ]
        )
    }

    /// Gets Shield Mode status for a broadcaster.
    public func fetchShieldModeStatus(broadcasterID: String, moderatorID: String) async throws -> ShieldModeStatus {
        let response: HelixResponse<ShieldModeStatus> = try await request(
            endpoint: "moderation/shield_mode",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ]
        )
        guard let status = response.data.first else { throw HelixError.emptyResponse }
        return status
    }

    /// Updates Shield Mode status for a broadcaster.
    public func updateShieldModeStatus(
        broadcasterID: String,
        moderatorID: String,
        isActive: Bool
    ) async throws -> ShieldModeStatus {
        let response: HelixResponse<ShieldModeStatus> = try await request(
            endpoint: "moderation/shield_mode",
            method: "PUT",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(ShieldModeStatusRequest(isActive: isActive))
        )
        guard let status = response.data.first else { throw HelixError.emptyResponse }
        return status
    }

    /// Warns a chat user.
    public func warnChatUser(
        broadcasterID: String,
        moderatorID: String,
        userID: String,
        reason: String
    ) async throws -> ChatWarning {
        let response: HelixResponse<ChatWarning> = try await request(
            endpoint: "moderation/warnings",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(ChatWarningRequest(data: ChatWarningRequest.DataBody(
                userId: userID,
                reason: reason
            )))
        )
        guard let warning = response.data.first else { throw HelixError.emptyResponse }
        return warning
    }

    /// Adds suspicious-user status to a chat user.
    public func addSuspiciousUserStatus(
        broadcasterID: String,
        moderatorID: String,
        userID: String,
        status: SuspiciousUserStatus
    ) async throws -> SuspiciousUserAction {
        let response: HelixResponse<SuspiciousUserAction> = try await request(
            endpoint: "moderation/suspicious_users",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(SuspiciousUserStatusRequest(userId: userID, status: status.rawValue))
        )
        guard let action = response.data.first else { throw HelixError.emptyResponse }
        return action
    }

    /// Removes suspicious-user status from a chat user.
    public func removeSuspiciousUserStatus(
        broadcasterID: String,
        moderatorID: String,
        userID: String
    ) async throws -> SuspiciousUserAction {
        let response: HelixResponse<SuspiciousUserAction> = try await request(
            endpoint: "moderation/suspicious_users",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
                URLQueryItem(name: "user_id", value: userID),
            ]
        )
        guard let action = response.data.first else { throw HelixError.emptyResponse }
        return action
    }
}

private struct AutoModStatusRequest: Encodable {
    let data: [AutoModMessage]
}

private struct HeldAutoModMessageRequest: Encodable {
    let userId: String
    let msgId: String
    let action: String
}

private struct BanUserRequest: Encodable {
    let data: DataBody

    struct DataBody: Encodable {
        let userId: String
        let duration: Int?
        let reason: String?
    }
}

private struct BlockedTermRequest: Encodable {
    let text: String
}

private struct ShieldModeStatusRequest: Encodable {
    let isActive: Bool
}

private struct ChatWarningRequest: Encodable {
    let data: DataBody

    struct DataBody: Encodable {
        let userId: String
        let reason: String
    }
}

private struct SuspiciousUserStatusRequest: Encodable {
    let userId: String
    let status: String
}

/// A message to check with AutoMod.
public struct AutoModMessage: Encodable, Sendable, Equatable {
    public let msgId: String
    public let msgText: String

    public init(msgID msgId: String, msgText: String) {
        self.msgId = msgId
        self.msgText = msgText
    }
}

/// AutoMod's decision for a checked message.
public struct AutoModStatus: Decodable, Sendable, Equatable {
    public let msgId: String
    public let isPermitted: Bool

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        msgId: String,
        isPermitted: Bool
    ) {
        self.msgId = msgId
        self.isPermitted = isPermitted
    }
}

/// Action to apply to a held AutoMod message.
public enum HeldAutoModMessageAction: String, Sendable, Equatable {
    case allow = "ALLOW"
    case deny = "DENY"
}

/// A broadcaster's AutoMod settings.
public struct AutoModSettings: Codable, Sendable, Equatable {
    public let broadcasterId: String
    public let moderatorId: String
    public let overallLevel: Int?
    public let disability: Int
    public let aggression: Int
    public let sexualitySexOrGender: Int
    public let misogyny: Int
    public let bullying: Int
    public let swearing: Int
    public let raceEthnicityOrReligion: Int
    public let sexBasedTerms: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        moderatorId: String,
        overallLevel: Int? = nil,
        disability: Int,
        aggression: Int,
        sexualitySexOrGender: Int,
        misogyny: Int,
        bullying: Int,
        swearing: Int,
        raceEthnicityOrReligion: Int,
        sexBasedTerms: Int
    ) {
        self.broadcasterId = broadcasterId
        self.moderatorId = moderatorId
        self.overallLevel = overallLevel
        self.disability = disability
        self.aggression = aggression
        self.sexualitySexOrGender = sexualitySexOrGender
        self.misogyny = misogyny
        self.bullying = bullying
        self.swearing = swearing
        self.raceEthnicityOrReligion = raceEthnicityOrReligion
        self.sexBasedTerms = sexBasedTerms
    }
}

/// Request body for updating AutoMod settings.
public struct AutoModSettingsUpdate: Encodable, Sendable, Equatable {
    public let overallLevel: Int?
    public let disability: Int?
    public let aggression: Int?
    public let sexualitySexOrGender: Int?
    public let misogyny: Int?
    public let bullying: Int?
    public let swearing: Int?
    public let raceEthnicityOrReligion: Int?
    public let sexBasedTerms: Int?

    public init(
        overallLevel: Int? = nil,
        disability: Int? = nil,
        aggression: Int? = nil,
        sexualitySexOrGender: Int? = nil,
        misogyny: Int? = nil,
        bullying: Int? = nil,
        swearing: Int? = nil,
        raceEthnicityOrReligion: Int? = nil,
        sexBasedTerms: Int? = nil
    ) {
        self.overallLevel = overallLevel
        self.disability = disability
        self.aggression = aggression
        self.sexualitySexOrGender = sexualitySexOrGender
        self.misogyny = misogyny
        self.bullying = bullying
        self.swearing = swearing
        self.raceEthnicityOrReligion = raceEthnicityOrReligion
        self.sexBasedTerms = sexBasedTerms
    }
}

/// A banned or timed-out user.
public struct BannedUser: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let expiresAt: String?
    public let createdAt: Date
    public let reason: String
    public let moderatorId: String
    public let moderatorLogin: String
    public let moderatorName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        expiresAt: String? = nil,
        createdAt: Date,
        reason: String,
        moderatorId: String,
        moderatorLogin: String,
        moderatorName: String
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.reason = reason
        self.moderatorId = moderatorId
        self.moderatorLogin = moderatorLogin
        self.moderatorName = moderatorName
    }
}

/// The ban or timeout applied by Ban User.
///
/// Twitch's Ban User response carries only IDs and timestamps; use
/// Get Banned Users when you need login names, display names, or the reason.
public struct BanUserResponse: Decodable, Sendable, Equatable {
    /// The broadcaster whose chat the user was banned from.
    public let broadcasterId: String

    /// The moderator that applied the ban or timeout.
    public let moderatorId: String

    /// The user that was banned or timed out.
    public let userId: String

    /// When the ban or timeout was applied.
    public let createdAt: Date

    /// When the timeout ends, or `nil` for a permanent ban.
    public let endTime: Date?

    /// Whether this is a timeout rather than a permanent ban.
    public var isTimeout: Bool { endTime != nil }

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        moderatorId: String,
        userId: String,
        createdAt: Date,
        endTime: Date? = nil,
        isTimeout: Bool { endTime ! = nil }
    ) {
        self.broadcasterId = broadcasterId
        self.moderatorId = moderatorId
        self.userId = userId
        self.createdAt = createdAt
        self.endTime = endTime
        self.isTimeout = isTimeout
    }

    private enum CodingKeys: String, CodingKey {
        case broadcasterId, moderatorId, userId, createdAt, endTime
    }

    /// Custom decoding solely for `endTime`: Twitch sends `null` for a
    /// permanent ban. Decoding the raw string also tolerates an empty string.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        broadcasterId = try container.decode(String.self, forKey: .broadcasterId)
        moderatorId = try container.decode(String.self, forKey: .moderatorId)
        userId = try container.decode(String.self, forKey: .userId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
            .flatMap(TwitchDateParser.date(from:))
    }
}

/// Filter status for unban requests.
@available(*, deprecated, renamed: "UnbanRequestStatus")
public typealias UnbanRequestStatusFilter = UnbanRequestStatus

/// Resolution status for an unban request.
public enum UnbanRequestResolutionStatus: String, Sendable, Equatable {
    case approved
    case denied
}

/// An unban request.
public struct UnbanRequest: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let text: String
    public let status: UnbanRequestStatus
    public let createdAt: Date
    public let resolvedAt: Date?
    public let resolutionText: String?
    public let moderatorId: String?
    public let moderatorLogin: String?
    public let moderatorName: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterId: String,
        broadcasterLogin: String,
        broadcasterName: String,
        userId: String,
        userLogin: String,
        userName: String,
        text: String,
        status: UnbanRequestStatus,
        createdAt: Date,
        resolvedAt: Date? = nil,
        resolutionText: String? = nil,
        moderatorId: String? = nil,
        moderatorLogin: String? = nil,
        moderatorName: String? = nil
    ) {
        self.id = id
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.text = text
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.resolutionText = resolutionText
        self.moderatorId = moderatorId
        self.moderatorLogin = moderatorLogin
        self.moderatorName = moderatorName
    }
}

/// A blocked term.
public struct BlockedTerm: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let moderatorId: String
    public let id: String
    public let text: String
    public let createdAt: Date
    public let updatedAt: Date
    public let expiresAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        moderatorId: String,
        id: String,
        text: String,
        createdAt: Date,
        updatedAt: Date,
        expiresAt: Date? = nil
    ) {
        self.broadcasterId = broadcasterId
        self.moderatorId = moderatorId
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
}

/// A channel moderated by a user.
public struct ModeratedChannel: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        broadcasterLogin: String,
        broadcasterName: String
    ) {
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
    }
}

/// A moderator user.
public struct ModeratorUser: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
    }
}

/// A VIP user.
public struct VIPUser: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
    }
}

/// Shield Mode status for a broadcaster.
public struct ShieldModeStatus: Decodable, Sendable, Equatable {
    public let isActive: Bool
    public let moderatorId: String
    public let moderatorName: String
    public let moderatorLogin: String

    /// When Shield Mode was last activated, or `nil` if the broadcaster has
    /// never activated it.
    public let lastActivatedAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        isActive: Bool,
        moderatorId: String,
        moderatorName: String,
        moderatorLogin: String,
        lastActivatedAt: Date? = nil
    ) {
        self.isActive = isActive
        self.moderatorId = moderatorId
        self.moderatorName = moderatorName
        self.moderatorLogin = moderatorLogin
        self.lastActivatedAt = lastActivatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case isActive, moderatorId, moderatorName, moderatorLogin, lastActivatedAt
    }

    /// Custom decoding solely for `lastActivatedAt`: Twitch sends
    /// `"last_activated_at": ""` — an empty string, not null — when Shield
    /// Mode has never been activated. The key is present, so `Date?` + the
    /// date strategy would try to parse "" and throw. Decode the raw string
    /// and map non-parsing values (incl. empty) to nil instead.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        moderatorId = try container.decode(String.self, forKey: .moderatorId)
        moderatorName = try container.decode(String.self, forKey: .moderatorName)
        moderatorLogin = try container.decode(String.self, forKey: .moderatorLogin)
        let rawLastActivatedAt = try container.decodeIfPresent(String.self, forKey: .lastActivatedAt)
        lastActivatedAt = rawLastActivatedAt.flatMap(TwitchDateParser.date(from:))
    }
}

/// A warning applied to a chat user.
public struct ChatWarning: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let userId: String
    public let moderatorId: String
    public let reason: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        userId: String,
        moderatorId: String,
        reason: String
    ) {
        self.broadcasterId = broadcasterId
        self.userId = userId
        self.moderatorId = moderatorId
        self.reason = reason
    }
}

/// Result of applying or removing suspicious-user status.
public struct SuspiciousUserAction: Decodable, Sendable, Equatable {
    public let userId: String
    public let broadcasterId: String
    public let moderatorId: String
    public let updatedAt: Date
    public let status: SuspiciousUserStatus
    public let types: [String]

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        broadcasterId: String,
        moderatorId: String,
        updatedAt: Date,
        status: SuspiciousUserStatus,
        types: [String]
    ) {
        self.userId = userId
        self.broadcasterId = broadcasterId
        self.moderatorId = moderatorId
        self.updatedAt = updatedAt
        self.status = status
        self.types = types
    }
}
