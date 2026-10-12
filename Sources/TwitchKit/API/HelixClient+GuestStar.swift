import Foundation

extension HelixClient {
    /// Gets Guest Star channel settings.
    public func fetchGuestStarSettings(broadcasterID: String, moderatorID: String) async throws -> GuestStarSettings {
        let response: HelixResponse<GuestStarSettings> = try await request(
            endpoint: "guest_star/channel_settings",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ]
        )
        guard let settings = response.data.first else { throw HelixError.emptyResponse }
        return settings
    }

    /// Updates Guest Star channel settings.
    public func updateGuestStarSettings(broadcasterID: String, with update: GuestStarSettingsUpdate) async throws {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        HelixQuery.append(HelixQuery.item("is_moderator_send_live_enabled", update.isModeratorSendLiveEnabled.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("slot_count", update.slotCount.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("is_browser_source_audio_enabled", update.isBrowserSourceAudioEnabled.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("group_layout", update.groupLayout), to: &queryItems)
        HelixQuery.append(HelixQuery.item("regenerate_browser_sources", update.regenerateBrowserSources.map(String.init)), to: &queryItems)
        try await requestNoContent(endpoint: "guest_star/channel_settings", method: "PUT", queryItems: queryItems)
    }

    /// Gets the active Guest Star session.
    public func fetchGuestStarSession(broadcasterID: String, moderatorID: String) async throws -> GuestStarSession? {
        let response: HelixResponse<GuestStarSession> = try await request(
            endpoint: "guest_star/session",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ]
        )
        return response.data.first
    }

    /// Creates a Guest Star session.
    public func createGuestStarSession(broadcasterID: String) async throws -> GuestStarSession {
        let response: HelixResponse<GuestStarSession> = try await request(
            endpoint: "guest_star/session",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        guard let session = response.data.first else { throw HelixError.emptyResponse }
        return session
    }

    /// Ends a Guest Star session.
    public func endGuestStarSession(broadcasterID: String, sessionID: String) async throws -> GuestStarSession {
        let response: HelixResponse<GuestStarSession> = try await request(
            endpoint: "guest_star/session",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "session_id", value: sessionID),
            ]
        )
        guard let session = response.data.first else { throw HelixError.emptyResponse }
        return session
    }

    /// Gets pending Guest Star invites for a session.
    public func fetchGuestStarInvites(broadcasterID: String, moderatorID: String, sessionID: String) async throws -> [GuestStarInvite] {
        let response: HelixResponse<GuestStarInvite> = try await request(
            endpoint: "guest_star/invites",
            queryItems: guestStarQueryItems(broadcasterID: broadcasterID, moderatorID: moderatorID, sessionID: sessionID)
        )
        return response.data
    }

    /// Sends a Guest Star invite.
    public func sendGuestStarInvite(broadcasterID: String, moderatorID: String, sessionID: String, guestID: String) async throws {
        var queryItems = guestStarQueryItems(broadcasterID: broadcasterID, moderatorID: moderatorID, sessionID: sessionID)
        queryItems.append(URLQueryItem(name: "guest_id", value: guestID))
        try await requestNoContent(endpoint: "guest_star/invites", method: "POST", queryItems: queryItems)
    }

    /// Revokes a Guest Star invite.
    public func deleteGuestStarInvite(broadcasterID: String, moderatorID: String, sessionID: String, guestID: String) async throws {
        var queryItems = guestStarQueryItems(broadcasterID: broadcasterID, moderatorID: moderatorID, sessionID: sessionID)
        queryItems.append(URLQueryItem(name: "guest_id", value: guestID))
        try await requestNoContent(endpoint: "guest_star/invites", method: "DELETE", queryItems: queryItems)
    }

    /// Assigns a Guest Star guest to a slot.
    public func assignGuestStarSlot(
        broadcasterID: String,
        moderatorID: String,
        sessionID: String,
        guestID: String,
        slotID: String
    ) async throws {
        var queryItems = guestStarQueryItems(broadcasterID: broadcasterID, moderatorID: moderatorID, sessionID: sessionID)
        queryItems.append(URLQueryItem(name: "guest_id", value: guestID))
        queryItems.append(URLQueryItem(name: "slot_id", value: slotID))
        try await requestNoContent(endpoint: "guest_star/slot", method: "POST", queryItems: queryItems)
    }

    /// Moves or swaps a Guest Star slot assignment.
    public func updateGuestStarSlot(
        broadcasterID: String,
        moderatorID: String,
        sessionID: String,
        sourceSlotID: String,
        destinationSlotID: String? = nil
    ) async throws {
        var queryItems = guestStarQueryItems(broadcasterID: broadcasterID, moderatorID: moderatorID, sessionID: sessionID)
        queryItems.append(URLQueryItem(name: "source_slot_id", value: sourceSlotID))
        HelixQuery.append(HelixQuery.item("destination_slot_id", destinationSlotID), to: &queryItems)
        try await requestNoContent(endpoint: "guest_star/slot", method: "PATCH", queryItems: queryItems)
    }

    /// Removes a Guest Star slot assignment.
    public func deleteGuestStarSlot(
        broadcasterID: String,
        moderatorID: String,
        sessionID: String,
        guestID: String,
        slotID: String,
        shouldReinviteGuest: Bool? = nil
    ) async throws {
        var queryItems = guestStarQueryItems(broadcasterID: broadcasterID, moderatorID: moderatorID, sessionID: sessionID)
        queryItems.append(URLQueryItem(name: "guest_id", value: guestID))
        queryItems.append(URLQueryItem(name: "slot_id", value: slotID))
        HelixQuery.append(HelixQuery.item("should_reinvite_guest", shouldReinviteGuest.map(String.init)), to: &queryItems)
        try await requestNoContent(endpoint: "guest_star/slot", method: "DELETE", queryItems: queryItems)
    }

    /// Updates Guest Star slot settings.
    public func updateGuestStarSlotSettings(
        broadcasterID: String,
        moderatorID: String,
        sessionID: String,
        slotID: String,
        update: GuestStarSlotSettingsUpdate
    ) async throws {
        var queryItems = guestStarQueryItems(broadcasterID: broadcasterID, moderatorID: moderatorID, sessionID: sessionID)
        queryItems.append(URLQueryItem(name: "slot_id", value: slotID))
        HelixQuery.append(HelixQuery.item("is_audio_enabled", update.isAudioEnabled.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("is_video_enabled", update.isVideoEnabled.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("is_live", update.isLive.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("volume", update.volume.map(String.init)), to: &queryItems)
        try await requestNoContent(endpoint: "guest_star/slot_settings", method: "PATCH", queryItems: queryItems)
    }

    private func guestStarQueryItems(broadcasterID: String, moderatorID: String, sessionID: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
            URLQueryItem(name: "session_id", value: sessionID),
        ]
    }
}

public struct GuestStarSettings: Decodable, Sendable, Equatable {
    public let isModeratorSendLiveEnabled: Bool
    public let slotCount: Int
    public let isBrowserSourceAudioEnabled: Bool
    public let groupLayout: String?
    public let layout: String?
    public let browserSourceToken: String
}

public struct GuestStarSettingsUpdate: Sendable, Equatable {
    public let isModeratorSendLiveEnabled: Bool?
    public let slotCount: Int?
    public let isBrowserSourceAudioEnabled: Bool?
    public let groupLayout: String?
    public let regenerateBrowserSources: Bool?

    public init(
        isModeratorSendLiveEnabled: Bool? = nil,
        slotCount: Int? = nil,
        isBrowserSourceAudioEnabled: Bool? = nil,
        groupLayout: String? = nil,
        regenerateBrowserSources: Bool? = nil
    ) {
        self.isModeratorSendLiveEnabled = isModeratorSendLiveEnabled
        self.slotCount = slotCount
        self.isBrowserSourceAudioEnabled = isBrowserSourceAudioEnabled
        self.groupLayout = groupLayout
        self.regenerateBrowserSources = regenerateBrowserSources
    }
}

public struct GuestStarSession: Decodable, Sendable, Equatable {
    public let id: String
    public let guests: [Guest]

    public struct Guest: Decodable, Sendable, Equatable {
        public let id: String?
        public let slotId: String?
        public let userId: String
        public let userDisplayName: String
        public let userLogin: String
        public let isLive: Bool
        public let volume: Int
        public let assignedAt: Date
        public let audioSettings: MediaSettings
        public let videoSettings: MediaSettings
    }

    public struct MediaSettings: Decodable, Sendable, Equatable {
        public let isHostEnabled: Bool
        public let isGuestEnabled: Bool
        public let isAvailable: Bool
    }
}

public struct GuestStarInvite: Decodable, Sendable, Equatable {
    public let userId: String
    public let invitedAt: Date
    public let status: String
    public let isVideoEnabled: Bool
    public let isAudioEnabled: Bool
    public let isVideoAvailable: Bool
    public let isAudioAvailable: Bool
}

public struct GuestStarSlotSettingsUpdate: Sendable, Equatable {
    public let isAudioEnabled: Bool?
    public let isVideoEnabled: Bool?
    public let isLive: Bool?
    public let volume: Int?

    public init(isAudioEnabled: Bool? = nil, isVideoEnabled: Bool? = nil, isLive: Bool? = nil, volume: Int? = nil) {
        self.isAudioEnabled = isAudioEnabled
        self.isVideoEnabled = isVideoEnabled
        self.isLive = isLive
        self.volume = volume
    }
}
