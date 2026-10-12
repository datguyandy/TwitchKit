import Foundation

// Argument labels follow the Swift API Design Guidelines: acronyms are
// uniformly cased (`broadcasterID`, `clientID`, `redirectURI`), and the
// leading `for` was dropped from labels such as `forBroadcasterID:`, which
// most endpoints never used. These forwarders keep the previous spellings
// compiling, with a fix-it to the new one; they will be removed before 1.0.

extension HelixClient {
    @available(*, deprecated, renamed: "fetchChannelsInfo(broadcasterIDs:)")
    public func fetchChannelsInfo(
        forBroadcasterIDs broadcasterIds: [String]
    ) async throws -> [TwitchChannel] {
        return try await fetchChannelsInfo(broadcasterIDs: broadcasterIds)
    }

    @available(*, deprecated, renamed: "fetchChannelInfo(broadcasterID:)")
    public func fetchChannelInfo(
        forBroadcasterID broadcasterId: String
    ) async throws -> TwitchChannel {
        // Keeps this spelling's original contract: a missing channel throws.
        guard let channel = try await fetchChannelInfo(broadcasterID: broadcasterId) else {
            throw HelixError.notFound
        }
        return channel
    }

    @available(*, deprecated, renamed: "updateChannelInfo(broadcasterID:with:)")
    public func updateChannelInfo(
        forBroadcasterID broadcasterId: String,
        with update: ChannelInfoUpdate
    ) async throws {
        try await updateChannelInfo(broadcasterID: broadcasterId, with: update)
    }

    @available(*, deprecated, renamed: "fetchChannelFollowersPage(broadcasterID:userID:first:after:)")
    public func fetchChannelFollowersPage(
        forBroadcasterID broadcasterId: String,
        userID userId: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchFollow> {
        return try await fetchChannelFollowersPage(broadcasterID: broadcasterId, userID: userId, first: first, after: cursor)
    }

    @available(*, deprecated, renamed: "channelFollowers(broadcasterID:userID:pageSize:)")
    public func channelFollowers(
        forBroadcasterID broadcasterId: String,
        userID userId: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchFollow> {
        return channelFollowers(broadcasterID: broadcasterId, userID: userId, pageSize: pageSize)
    }

    @available(*, deprecated, renamed: "fetchFollowedChannelsPage(userID:broadcasterID:first:after:)")
    public func fetchFollowedChannelsPage(
        forUserID userId: String,
        broadcasterID broadcasterId: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<FollowedChannel> {
        return try await fetchFollowedChannelsPage(userID: userId, broadcasterID: broadcasterId, first: first, after: cursor)
    }

    @available(*, deprecated, renamed: "followedChannels(userID:broadcasterID:pageSize:)")
    public func followedChannels(
        forUserID userId: String,
        broadcasterID broadcasterId: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<FollowedChannel> {
        return followedChannels(userID: userId, broadcasterID: broadcasterId, pageSize: pageSize)
    }

    @available(*, deprecated, renamed: "fetchChannelEditors(broadcasterID:)")
    public func fetchChannelEditors(
        forBroadcasterID broadcasterId: String
    ) async throws -> [ChannelEditor] {
        return try await fetchChannelEditors(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "fetchCharityCampaign(broadcasterID:)")
    public func fetchCharityCampaign(
        forBroadcasterID broadcasterId: String
    ) async throws -> CharityCampaign? {
        return try await fetchCharityCampaign(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "fetchCharityCampaignDonationsPage(broadcasterID:first:after:)")
    public func fetchCharityCampaignDonationsPage(
        forBroadcasterID broadcasterId: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<CharityDonation> {
        return try await fetchCharityCampaignDonationsPage(broadcasterID: broadcasterId, first: first, after: cursor)
    }

    @available(*, deprecated, renamed: "charityCampaignDonations(broadcasterID:pageSize:)")
    public func charityCampaignDonations(
        forBroadcasterID broadcasterId: String,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<CharityDonation> {
        return charityCampaignDonations(broadcasterID: broadcasterId, pageSize: pageSize)
    }

    @available(*, deprecated, renamed: "fetchChannelEmotes(broadcasterID:)")
    public func fetchChannelEmotes(
        forBroadcasterID broadcasterId: String
    ) async throws -> [TwitchEmote] {
        return try await fetchChannelEmotes(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "fetchChannelBadges(broadcasterID:)")
    public func fetchChannelBadges(
        forBroadcasterID broadcasterId: String
    ) async throws -> [TwitchBadgeSet] {
        return try await fetchChannelBadges(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "sendChatMessage(broadcasterID:senderID:message:replyParentMessageID:forSourceOnly:pin:)")
    public func sendChatMessage(
        broadcasterId: String,
        senderId: String,
        message: String,
        replyParentMessageId: String? = nil,
        forSourceOnly: Bool? = nil,
        pin: Bool? = nil
    ) async throws -> SendChatMessageResponse {
        return try await sendChatMessage(broadcasterID: broadcasterId, senderID: senderId, message: message, replyParentMessageID: replyParentMessageId, forSourceOnly: forSourceOnly, pin: pin)
    }

    @available(*, deprecated, renamed: "fetchCreatorGoals(broadcasterID:)")
    public func fetchCreatorGoals(
        forBroadcasterID broadcasterId: String
    ) async throws -> [CreatorGoal] {
        return try await fetchCreatorGoals(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "createEventSubSubscription(type:version:condition:sessionID:isBatchingEnabled:)")
    public func createEventSubSubscription(
        type: String,
        version: String,
        condition: [String: String],
        sessionId: String,
        isBatchingEnabled: Bool? = nil
    ) async throws -> EventSubSubscriptionRecord {
        return try await createEventSubSubscription(type: type, version: version, condition: condition, sessionID: sessionId, isBatchingEnabled: isBatchingEnabled)
    }

    @available(*, deprecated, renamed: "fetchHypeTrainStatus(broadcasterID:)")
    public func fetchHypeTrainStatus(
        forBroadcasterID broadcasterId: String
    ) async throws -> HypeTrainStatus? {
        return try await fetchHypeTrainStatus(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "fetchChannelStreamSchedulePage(broadcasterID:segmentIDs:startTime:utcOffset:first:after:)")
    public func fetchChannelStreamSchedulePage(
        forBroadcasterID broadcasterId: String,
        segmentIDs: [String] = [],
        startTime: Date? = nil,
        utcOffset: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> ChannelStreamSchedulePage {
        return try await fetchChannelStreamSchedulePage(broadcasterID: broadcasterId, segmentIDs: segmentIDs, startTime: startTime, utcOffset: utcOffset, first: first, after: cursor)
    }

    @available(*, deprecated, renamed: "fetchChannelICalendar(broadcasterID:)")
    public func fetchChannelICalendar(
        forBroadcasterID broadcasterId: String
    ) async throws -> String {
        return try await fetchChannelICalendar(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "updateChannelStreamSchedule(broadcasterID:with:)")
    public func updateChannelStreamSchedule(
        forBroadcasterID broadcasterId: String,
        with settings: ChannelStreamScheduleSettingsUpdate
    ) async throws {
        try await updateChannelStreamSchedule(broadcasterID: broadcasterId, with: settings)
    }

    @available(*, deprecated, renamed: "createChannelStreamScheduleSegment(broadcasterID:segment:)")
    public func createChannelStreamScheduleSegment(
        forBroadcasterID broadcasterId: String,
        segment: ChannelStreamScheduleSegmentCreate
    ) async throws -> ChannelStreamSchedule {
        return try await createChannelStreamScheduleSegment(broadcasterID: broadcasterId, segment: segment)
    }

    @available(*, deprecated, renamed: "updateChannelStreamScheduleSegment(broadcasterID:segmentID:with:)")
    public func updateChannelStreamScheduleSegment(
        forBroadcasterID broadcasterId: String,
        segmentID segmentId: String,
        with update: ChannelStreamScheduleSegmentUpdate
    ) async throws -> ChannelStreamSchedule {
        return try await updateChannelStreamScheduleSegment(broadcasterID: broadcasterId, segmentID: segmentId, with: update)
    }

    @available(*, deprecated, renamed: "deleteChannelStreamScheduleSegment(broadcasterID:segmentID:)")
    public func deleteChannelStreamScheduleSegment(
        forBroadcasterID broadcasterId: String,
        segmentID segmentId: String
    ) async throws {
        try await deleteChannelStreamScheduleSegment(broadcasterID: broadcasterId, segmentID: segmentId)
    }

    @available(*, deprecated, renamed: "fetchStream(userID:)")
    public func fetchStream(
        forUserID userId: String
    ) async throws -> TwitchStream? {
        return try await fetchStream(userID: userId)
    }

    @available(*, deprecated, renamed: "fetchStreamKey(broadcasterID:)")
    public func fetchStreamKey(
        forBroadcasterID broadcasterId: String
    ) async throws -> String {
        return try await fetchStreamKey(broadcasterID: broadcasterId)
    }

    @available(*, deprecated, renamed: "init(tokenProvider:clientID:httpClient:requestConfiguration:retryPolicy:responseMetadataHandler:)")
    public init(
        tokenProvider: any TwitchAccessTokenProvider,
        clientId: String,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil
    ) {
        self.init(tokenProvider: tokenProvider, clientID: clientId, httpClient: httpClient, requestConfiguration: requestConfiguration, retryPolicy: retryPolicy, responseMetadataHandler: responseMetadataHandler)
    }

    @available(*, deprecated, renamed: "init(auth:clientID:httpClient:requestConfiguration:retryPolicy:responseMetadataHandler:)")
    public init(
        auth: TwitchAuth,
        clientId: String,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil
    ) {
        self.init(auth: auth, clientID: clientId, httpClient: httpClient, requestConfiguration: requestConfiguration, retryPolicy: retryPolicy, responseMetadataHandler: responseMetadataHandler)
    }
}

extension ChannelInfoUpdate {
    @available(*, deprecated, renamed: "init(title:gameID:broadcasterLanguage:delay:tags:contentClassificationLabels:isBrandedContent:)")
    public init(
        title: String? = nil,
        gameId: String?,
        broadcasterLanguage: String? = nil,
        delay: Int? = nil,
        tags: [String]? = nil,
        contentClassificationLabels: [ContentClassificationLabel]? = nil,
        isBrandedContent: Bool? = nil
    ) {
        self.init(title: title, gameID: gameId, broadcasterLanguage: broadcasterLanguage, delay: delay, tags: tags, contentClassificationLabels: contentClassificationLabels, isBrandedContent: isBrandedContent)
    }
}

extension AutoModMessage {
    @available(*, deprecated, renamed: "init(msgID:msgText:)")
    public init(
        msgId: String,
        msgText: String
    ) {
        self.init(msgID: msgId, msgText: msgText)
    }
}

extension PollCreateRequest {
    @available(*, deprecated, renamed: "init(broadcasterID:title:choices:channelPointsVotingEnabled:channelPointsPerVote:duration:)")
    public init(
        broadcasterId: String,
        title: String,
        choices: [PollChoice],
        channelPointsVotingEnabled: Bool? = nil,
        channelPointsPerVote: Int? = nil,
        duration: Int
    ) {
        self.init(broadcasterID: broadcasterId, title: title, choices: choices, channelPointsVotingEnabled: channelPointsVotingEnabled, channelPointsPerVote: channelPointsPerVote, duration: duration)
    }
}

extension PredictionCreateRequest {
    @available(*, deprecated, renamed: "init(broadcasterID:title:outcomes:predictionWindow:)")
    public init(
        broadcasterId: String,
        title: String,
        outcomes: [PredictionOutcome],
        predictionWindow: Int
    ) {
        self.init(broadcasterID: broadcasterId, title: title, outcomes: outcomes, predictionWindow: predictionWindow)
    }
}

extension ChannelStreamScheduleSegmentCreate {
    @available(*, deprecated, renamed: "init(startTime:timezone:isRecurring:duration:categoryID:title:)")
    public init(
        startTime: Date,
        timezone: String,
        isRecurring: Bool,
        duration: String? = nil,
        categoryId: String?,
        title: String? = nil
    ) {
        self.init(startTime: startTime, timezone: timezone, isRecurring: isRecurring, duration: duration, categoryID: categoryId, title: title)
    }
}

extension ChannelStreamScheduleSegmentUpdate {
    @available(*, deprecated, renamed: "init(startTime:duration:categoryID:title:isCanceled:timezone:)")
    public init(
        startTime: Date? = nil,
        duration: String? = nil,
        categoryId: String?,
        title: String? = nil,
        isCanceled: Bool? = nil,
        timezone: String? = nil
    ) {
        self.init(startTime: startTime, duration: duration, categoryID: categoryId, title: title, isCanceled: isCanceled, timezone: timezone)
    }
}

extension TwitchAuth {
    @available(*, deprecated, renamed: "redirectURI")
    public static var redirectUri: String { redirectURI }

    @available(*, deprecated, renamed: "init(clientID:clientSecret:redirectURI:tokenNamespace:httpClient:)")
    public init(
        clientId: String,
        clientSecret: String? = nil,
        redirectUri: String = TwitchAuth.redirectURI,
        tokenNamespace: String? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.init(clientID: clientId, clientSecret: clientSecret, redirectURI: redirectUri, tokenNamespace: tokenNamespace, httpClient: httpClient)
    }
}

extension TwitchOAuthClient {
    @available(*, deprecated, renamed: "init(clientID:clientSecret:redirectURI:httpClient:)")
    public init(
        clientId: String,
        clientSecret: String? = nil,
        redirectUri: String = TwitchOAuthClient.defaultRedirectURI,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.init(clientID: clientId, clientSecret: clientSecret, redirectURI: redirectUri, httpClient: httpClient)
    }
}

extension KeychainTokenStore {
    @available(*, deprecated, renamed: "init(clientID:namespace:)")
    public init(
        clientId: String,
        namespace: String? = nil
    ) {
        self.init(clientID: clientId, namespace: namespace)
    }
}

extension TwitchClient {
    @available(*, deprecated, renamed: "clientID")
    public var clientId: String { clientID }

    @available(*, deprecated, renamed: "init(clientID:clientSecret:tokenNamespace:tokenStore:httpClient:requestConfiguration:retryPolicy:responseMetadataHandler:eventBufferingPolicy:shouldKeepReconnecting:pathMonitor:eventSubSocketFactory:)")
    public convenience init(
        clientId: String,
        clientSecret: String? = nil,
        tokenNamespace: String? = nil,
        tokenStore: (any TwitchTokenStore)? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil,
        eventBufferingPolicy: AsyncStream<EventSubEvent>.Continuation.BufferingPolicy = .bufferingNewest(1_000),
        isLive: @escaping @Sendable () async -> Bool = { true },
        pathMonitor: NetworkPathMonitoring = NWPathNetworkMonitor(),
        eventSubSocketFactory: @escaping @Sendable (URL) -> any EventSubWebSocket = { URLSession.shared.webSocketTask(with: $0) }
    ) {
        self.init(clientID: clientId, clientSecret: clientSecret, tokenNamespace: tokenNamespace, tokenStore: tokenStore, httpClient: httpClient, requestConfiguration: requestConfiguration, retryPolicy: retryPolicy, responseMetadataHandler: responseMetadataHandler, eventBufferingPolicy: eventBufferingPolicy, shouldKeepReconnecting: isLive, pathMonitor: pathMonitor, eventSubSocketFactory: eventSubSocketFactory)
    }

    // `isLive` is required here (it defaults in the new initializer), so a
    // call that omits it isn't ambiguous between the two.
    @available(*, deprecated, renamed: "init(clientID:clientSecret:tokenNamespace:tokenStore:httpClient:requestConfiguration:retryPolicy:responseMetadataHandler:eventBufferingPolicy:shouldKeepReconnecting:pathMonitor:eventSubSocketFactory:)")
    public convenience init(
        clientID: String,
        clientSecret: String? = nil,
        tokenNamespace: String? = nil,
        tokenStore: (any TwitchTokenStore)? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil,
        eventBufferingPolicy: AsyncStream<EventSubEvent>.Continuation.BufferingPolicy = .bufferingNewest(1_000),
        isLive: @escaping @Sendable () async -> Bool,
        pathMonitor: NetworkPathMonitoring = NWPathNetworkMonitor(),
        eventSubSocketFactory: @escaping @Sendable (URL) -> any EventSubWebSocket = { URLSession.shared.webSocketTask(with: $0) }
    ) {
        self.init(clientID: clientID, clientSecret: clientSecret, tokenNamespace: tokenNamespace, tokenStore: tokenStore, httpClient: httpClient, requestConfiguration: requestConfiguration, retryPolicy: retryPolicy, responseMetadataHandler: responseMetadataHandler, eventBufferingPolicy: eventBufferingPolicy, shouldKeepReconnecting: isLive, pathMonitor: pathMonitor, eventSubSocketFactory: eventSubSocketFactory)
    }
}

extension EventSubClient {
    // `isLive` stays required, as before, so a call that omits it matches
    // only the new initializer.
    @available(*, deprecated, renamed: "init(api:shouldKeepReconnecting:pathMonitor:socketFactory:eventBufferingPolicy:)")
    public init(
        api: HelixClient,
        isLive: @escaping @Sendable () async -> Bool,
        pathMonitor: NetworkPathMonitoring = NWPathNetworkMonitor(),
        socketFactory: @escaping @Sendable (URL) -> any EventSubWebSocket = { URLSession.shared.webSocketTask(with: $0) },
        eventBufferingPolicy: AsyncStream<EventSubEvent>.Continuation.BufferingPolicy = .bufferingNewest(1_000)
    ) {
        self.init(
            api: api,
            shouldKeepReconnecting: isLive,
            pathMonitor: pathMonitor,
            socketFactory: socketFactory,
            eventBufferingPolicy: eventBufferingPolicy
        )
    }
}
