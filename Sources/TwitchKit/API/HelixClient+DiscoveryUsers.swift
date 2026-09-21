import Foundation

extension HelixClient {
    /// Gets all stream tags or a subset by tag ID.
    @available(*, deprecated, message: "Twitch deprecated stream tags in 2023; the endpoint returns empty data and is scheduled for removal.")
    public func fetchAllStreamTags(tagIDs: [String] = [], first: Int? = nil, after cursor: String? = nil) async throws -> HelixPage<StreamTag> {
        var queryItems = HelixQuery.items("tag_id", values: tagIDs)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)
        let response: HelixResponse<StreamTag> = try await request(
            endpoint: "tags/streams",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.page
    }

    /// Gets stream tags set on a broadcaster's channel.
    @available(*, deprecated, message: "Twitch deprecated stream tags in 2023; the endpoint returns empty data and is scheduled for removal.")
    public func fetchStreamTags(broadcasterID: String) async throws -> [StreamTag] {
        let response: HelixResponse<StreamTag> = try await request(
            endpoint: "streams/tags",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        return response.data
    }

    /// Gets teams that a broadcaster belongs to.
    public func fetchChannelTeams(broadcasterID: String) async throws -> [ChannelTeam] {
        let response: HelixResponse<ChannelTeam> = try await request(
            endpoint: "teams/channel",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        return response.data
    }

    /// Gets Twitch team information by name or ID.
    ///
    /// Exactly one of `name` or `id` must be specified.
    public func fetchTeams(name: String? = nil, id: String? = nil) async throws -> [TwitchTeam] {
        guard (name != nil) != (id != nil) else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Exactly one of team name or team ID must be specified")
            )
        }

        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("name", name), to: &queryItems)
        HelixQuery.append(HelixQuery.item("id", id), to: &queryItems)
        let response: HelixResponse<TwitchTeam> = try await request(endpoint: "teams", queryItems: queryItems)
        return response.data
    }

    /// Updates the authenticated user's description.
    public func updateUser(description: String) async throws -> TwitchUser {
        let response: HelixResponse<TwitchUser> = try await request(
            endpoint: "users",
            method: "PUT",
            queryItems: [URLQueryItem(name: "description", value: description)]
        )
        guard let user = response.data.first else { throw HelixError.notFound }
        return user
    }

    /// Gets authorization scopes granted by a user to the authenticated application.
    /// Requires an app access token.
    public func fetchAuthorization(userID: String) async throws -> UserAuthorization {
        guard let authorization = try await fetchAuthorizations(userIDs: [userID]).first else {
            throw HelixError.notFound
        }
        return authorization
    }

    /// The authenticated app token determines the client; `clientID` is not sent to Twitch.
    @available(*, deprecated, message: "Use fetchAuthorization(userID:); Twitch determines the application from its app access token")
    public func fetchAuthorization(userID: String, clientID: String?) async throws -> UserAuthorization {
        try await fetchAuthorization(userID: userID)
    }

    /// Gets granted scopes for up to ten users using an app access token.
    public func fetchAuthorizations(userIDs: [String]) async throws -> [UserAuthorization] {
        guard (1...10).contains(userIDs.count), userIDs.allSatisfy({ !$0.isEmpty }) else {
            throw HelixError.badRequest(.fallback(status: 400, message: "Between 1 and 10 nonempty user IDs are required"))
        }
        let response: HelixResponse<UserAuthorization> = try await request(
            endpoint: "authorization/users",
            queryItems: HelixQuery.items("user_id", values: userIDs)
        )
        return response.data
    }

    /// Gets one page of users blocked by a broadcaster.
    public func fetchUserBlockListPage(
        broadcasterID: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<BlockedUser> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)
        let response: HelixResponse<BlockedUser> = try await request(endpoint: "users/blocks", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of users blocked by a broadcaster.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get User Block List](https://dev.twitch.tv/docs/api/reference/#get-user-block-list)
    public func userBlockList(
        broadcasterID: String,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<BlockedUser> {
        pagedRequest(
            endpoint: "users/blocks",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)],
            pageSize: pageSize
        )
    }

    /// Blocks a user.
    public func blockUser(targetUserID: String, sourceContext: UserBlockSourceContext? = nil, reason: UserBlockReason? = nil) async throws {
        var queryItems = [URLQueryItem(name: "target_user_id", value: targetUserID)]
        HelixQuery.append(HelixQuery.item("source_context", sourceContext?.rawValue), to: &queryItems)
        HelixQuery.append(HelixQuery.item("reason", reason?.rawValue), to: &queryItems)
        try await requestNoContent(endpoint: "users/blocks", method: "PUT", queryItems: queryItems)
    }

    /// Unblocks a user.
    public func unblockUser(targetUserID: String) async throws {
        try await requestNoContent(
            endpoint: "users/blocks",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "target_user_id", value: targetUserID)]
        )
    }

    /// Sends a whisper message.
    public func sendWhisper(fromUserID: String, toUserID: String, message: String) async throws {
        try await requestNoContent(
            endpoint: "whispers",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "from_user_id", value: fromUserID),
                URLQueryItem(name: "to_user_id", value: toUserID),
            ],
            body: try JSONEncoder.twitch().encode(WhisperRequest(message: message))
        )
    }

    /// Gets extensions installed by the authenticated user.
    public func fetchUserExtensions() async throws -> [UserExtension] {
        let response: HelixResponse<UserExtension> = try await request(endpoint: "users/extensions/list")
        return response.data
    }

    /// Gets active extensions for a broadcaster.
    public func fetchUserActiveExtensions(userID: String? = nil) async throws -> UserActiveExtensions {
        let queryItems = userID.map { [URLQueryItem(name: "user_id", value: $0)] }
        let data = try await requestRawData(endpoint: "users/extensions", queryItems: queryItems)
        return try JSONDecoder.twitch().decode(UserActiveExtensions.self, from: data)
    }

    /// Updates active extensions for the authenticated user.
    public func updateUserExtensions(_ extensions: UserActiveExtensionsData) async throws -> UserActiveExtensions {
        let data = try await requestRawData(
            endpoint: "users/extensions",
            method: "PUT",
            body: try JSONEncoder.twitch().encode(UserActiveExtensions(data: extensions))
        )
        return try JSONDecoder.twitch().decode(UserActiveExtensions.self, from: data)
    }
}

private struct WhisperRequest: Encodable {
    let message: String
}

public struct StreamTag: Decodable, Sendable, Equatable {
    public let tagId: String
    public let isAuto: Bool
    public let localizationNames: [String: String]
    public let localizationDescriptions: [String: String]
}

public struct ChannelTeam: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let broadcasterName: String
    public let broadcasterLogin: String
    public let backgroundImageUrl: String?
    public let banner: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let info: String
    public let thumbnailUrl: String
    public let teamName: String
    public let teamDisplayName: String
    public let id: String
}

public struct TwitchTeam: Decodable, Sendable, Equatable {
    public let users: [User]
    public let backgroundImageUrl: String?
    public let banner: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let info: String
    public let thumbnailUrl: String
    public let teamName: String
    public let teamDisplayName: String
    public let id: String

    public struct User: Decodable, Sendable, Equatable {
        public let userId: String
        public let userName: String
        public let userLogin: String
    }
}

public struct UserAuthorization: Decodable, Sendable, Equatable {
    public let hasAuthorized: Bool
    @available(*, deprecated, message: "Twitch does not return client_id for this endpoint")
    public let clientId: String?
    public let userId: String
    public let userLogin: String?
    public let userName: String?
    public let scopes: [String]
}

public struct BlockedUser: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let displayName: String
}

public enum UserBlockSourceContext: String, Sendable, Equatable {
    case chat
    case whisper
}

public enum UserBlockReason: String, Sendable, Equatable {
    case harassment
    case spam
    case other
}

public struct UserExtension: Decodable, Sendable, Equatable {
    public let id: String
    public let version: String
    public let name: String
    public let canActivate: Bool
    public let type: [String]
}

public struct UserActiveExtensions: Codable, Sendable, Equatable {
    public let data: UserActiveExtensionsData
}

public struct UserActiveExtensionsData: Codable, Sendable, Equatable {
    public let panel: [String: UserActiveExtension]
    public let overlay: [String: UserActiveExtension]
    public let component: [String: UserActiveExtension]

    public init(
        panel: [String: UserActiveExtension] = [:],
        overlay: [String: UserActiveExtension] = [:],
        component: [String: UserActiveExtension] = [:]
    ) {
        self.panel = panel
        self.overlay = overlay
        self.component = component
    }
}

public struct UserActiveExtension: Codable, Sendable, Equatable {
    public let active: Bool
    public let id: String?
    public let version: String?
    public let name: String?
    public let x: Int?
    public let y: Int?

    public init(active: Bool, id: String? = nil, version: String? = nil, name: String? = nil, x: Int? = nil, y: Int? = nil) {
        self.active = active
        self.id = id
        self.version = version
        self.name = name
        self.x = x
        self.y = y
    }
}
