import Foundation

extension HelixClient {
    /// Gets an extension configuration segment.
    public func fetchExtensionConfiguration(
        extensionID: String,
        segment: ExtensionConfigurationSegment,
        broadcasterID: String? = nil
    ) async throws -> [ExtensionConfiguration] {
        var queryItems = [
            URLQueryItem(name: "extension_id", value: extensionID),
            URLQueryItem(name: "segment", value: segment.rawValue),
        ]
        HelixQuery.append(HelixQuery.item("broadcaster_id", broadcasterID), to: &queryItems)
        let response: HelixResponse<ExtensionConfiguration> = try await request(
            endpoint: "extensions/configurations",
            queryItems: queryItems
        )
        return response.data
    }

    /// Sets an extension configuration segment.
    public func setExtensionConfiguration(_ configuration: ExtensionConfigurationUpdate) async throws {
        try await requestNoContent(
            endpoint: "extensions/configurations",
            method: "PUT",
            body: try JSONEncoder.twitch().encode(configuration)
        )
    }

    /// Sets an extension's required configuration string for a broadcaster.
    public func setExtensionRequiredConfiguration(
        broadcasterID: String,
        extensionID: String,
        extensionVersion: String,
        requiredConfiguration: String
    ) async throws {
        try await requestNoContent(
            endpoint: "extensions/required_configuration",
            method: "PUT",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)],
            body: try JSONEncoder.twitch().encode(ExtensionRequiredConfigurationRequest(
                extensionId: extensionID,
                extensionVersion: extensionVersion,
                requiredConfiguration: requiredConfiguration
            ))
        )
    }

    /// Sends an extension PubSub message.
    public func sendExtensionPubSubMessage(_ message: ExtensionPubSubMessage) async throws {
        try await requestNoContent(
            endpoint: "extensions/pubsub",
            method: "POST",
            body: try JSONEncoder.twitch().encode(message)
        )
    }

    /// Gets live channels that have installed or activated an extension.
    public func fetchExtensionLiveChannelsPage(
        extensionID: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> ExtensionLiveChannelsPage {
        var queryItems = [URLQueryItem(name: "extension_id", value: extensionID)]
        HelixQuery.append(HelixQuery.item("first", first.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("after", cursor), to: &queryItems)
        let data = try await requestRawData(endpoint: "extensions/live", queryItems: queryItems)
        return try JSONDecoder.twitch().decode(ExtensionLiveChannelsPage.self, from: data)
    }

    /// Gets an extension's shared JWT secrets.
    public func fetchExtensionSecrets(extensionID: String) async throws -> [ExtensionSecretSet] {
        let response: HelixResponse<ExtensionSecretSet> = try await request(
            endpoint: "extensions/jwt/secrets",
            queryItems: [URLQueryItem(name: "extension_id", value: extensionID)]
        )
        return response.data
    }

    /// Creates a new extension shared JWT secret.
    public func createExtensionSecret(extensionID: String, delay: Int? = nil) async throws -> [ExtensionSecretSet] {
        var queryItems = [URLQueryItem(name: "extension_id", value: extensionID)]
        HelixQuery.append(HelixQuery.item("delay", delay.map(String.init)), to: &queryItems)
        let response: HelixResponse<ExtensionSecretSet> = try await request(
            endpoint: "extensions/jwt/secrets",
            method: "POST",
            queryItems: queryItems
        )
        return response.data
    }

    /// Sends a message to chat from an extension.
    public func sendExtensionChatMessage(broadcasterID: String, text: String, extensionID: String, extensionVersion: String) async throws {
        try await requestNoContent(
            endpoint: "extensions/chat",
            method: "POST",
            body: try JSONEncoder.twitch().encode(ExtensionChatMessageRequest(
                broadcasterId: broadcasterID,
                text: text,
                extensionId: extensionID,
                extensionVersion: extensionVersion
            ))
        )
    }

    /// Gets extension metadata by extension ID.
    public func fetchExtensions(extensionID: String, extensionVersion: String? = nil) async throws -> [TwitchExtension] {
        var queryItems = [URLQueryItem(name: "extension_id", value: extensionID)]
        HelixQuery.append(HelixQuery.item("extension_version", extensionVersion), to: &queryItems)
        let response: HelixResponse<TwitchExtension> = try await request(endpoint: "extensions", queryItems: queryItems)
        return response.data
    }

    /// Gets released extensions owned by the authenticated organization.
    public func fetchReleasedExtensions(extensionID: String? = nil, extensionVersion: String? = nil) async throws -> [TwitchExtension] {
        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("extension_id", extensionID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("extension_version", extensionVersion), to: &queryItems)
        let response: HelixResponse<TwitchExtension> = try await request(
            endpoint: "extensions/released",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.data
    }

    /// Gets Bits products that belong to an extension.
    public func fetchExtensionBitsProducts(
        shouldIncludeAll: Bool? = nil
    ) async throws -> [ExtensionBitsProduct] {
        let queryItems = shouldIncludeAll.map { [URLQueryItem(name: "should_include_all", value: String($0))] }
        let response: HelixResponse<ExtensionBitsProduct> = try await request(
            endpoint: "bits/extensions",
            queryItems: queryItems
        )
        return response.data
    }

    /// Creates or updates an extension Bits product.
    public func updateExtensionBitsProduct(_ product: ExtensionBitsProductUpdate) async throws -> ExtensionBitsProduct {
        let response: HelixResponse<ExtensionBitsProduct> = try await request(
            endpoint: "bits/extensions",
            method: "PUT",
            body: try JSONEncoder.twitch().encode(product)
        )
        guard let product = response.data.first else { throw HelixError.emptyResponse }
        return product
    }
}

private struct ExtensionRequiredConfigurationRequest: Encodable {
    let extensionId: String
    let extensionVersion: String
    let requiredConfiguration: String
}

private struct ExtensionChatMessageRequest: Encodable {
    let broadcasterId: String
    let text: String
    let extensionId: String
    let extensionVersion: String
}

public enum ExtensionConfigurationSegment: String, Sendable, Equatable {
    case broadcaster
    case developer
    case global
}

public struct ExtensionConfiguration: Decodable, Sendable, Equatable {
    public let segment: String
    public let broadcasterId: String?
    public let content: String
    public let version: String
}

public struct ExtensionConfigurationUpdate: Encodable, Sendable, Equatable {
    public let extensionId: String
    public let segment: String
    public let broadcasterId: String?
    public let content: String?
    public let version: String?

    public init(
        extensionID: String,
        segment: ExtensionConfigurationSegment,
        broadcasterID: String? = nil,
        content: String? = nil,
        version: String? = nil
    ) {
        self.extensionId = extensionID
        self.segment = segment.rawValue
        self.broadcasterId = broadcasterID
        self.content = content
        self.version = version
    }
}

public struct ExtensionPubSubMessage: Encodable, Sendable, Equatable {
    public let target: [String]
    public let broadcasterId: String
    public let isGlobalBroadcast: Bool?
    public let message: String

    public init(target: [String], broadcasterID: String, isGlobalBroadcast: Bool? = nil, message: String) {
        self.target = target
        self.broadcasterId = broadcasterID
        self.isGlobalBroadcast = isGlobalBroadcast
        self.message = message
    }
}

public struct ExtensionLiveChannelsPage: Decodable, Sendable, Equatable {
    public let data: [ExtensionLiveChannel]
    public let pagination: Pagination?

    /// Creates a page of live channels.
    ///
    /// - Parameters:
    ///   - data: Live channels on this page.
    ///   - pagination: Cursor pagination, when more pages are available.
    public init(data: [ExtensionLiveChannel], pagination: Pagination? = nil) {
        self.data = data
        self.pagination = pagination
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case pagination
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode([ExtensionLiveChannel].self, forKey: .data)

        // Get Extension Live Channels deviates from the standard Helix envelope: `pagination`
        // is a plain string cursor rather than a `{"cursor": ...}` object. Decode the string
        // form first (an empty string means no further pages), and fall back to the object
        // form in case Twitch ever aligns this endpoint with the rest of the API.
        let pagination: Pagination?
        if container.contains(.pagination) {
            if let cursor = try? container.decode(String.self, forKey: .pagination) {
                pagination = cursor.isEmpty ? nil : Pagination(cursor: cursor)
            } else {
                pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination)
            }
        } else {
            pagination = nil
        }

        self.init(data: data, pagination: pagination)
    }
}

public struct ExtensionLiveChannel: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let broadcasterName: String
    public let gameName: String
    public let gameId: String
    public let title: String
}

public struct ExtensionSecretSet: Decodable, Sendable, Equatable {
    public let formatVersion: Int
    public let secrets: [ExtensionSecret]
}

public struct ExtensionSecret: Decodable, Sendable, Equatable {
    public let content: String
    public let activeAt: Date
    public let expiresAt: Date
}

public struct TwitchExtension: Decodable, Sendable, Equatable {
    public let authorName: String?
    public let bitsEnabled: Bool?
    public let canInstall: Bool?
    public let configurationLocation: String?
    public let description: String?
    public let eulaTosUrl: String?
    public let hasChatSupport: Bool?
    public let iconUrl: String?
    public let iconUrls: [String: String]?
    public let id: String
    public let name: String
    public let privacyPolicyUrl: String?
    public let requestIdentityLink: Bool?
    public let screenshotUrls: [String]?
    public let state: String?
    public let subscriptionsSupportLevel: String?
    public let summary: String?
    public let supportEmail: String?
    public let version: String?
    public let viewerSummary: String?
}

public struct ExtensionBitsProduct: Decodable, Sendable, Equatable {
    public let sku: String
    public let cost: Cost
    public let displayName: String
    public let inDevelopment: Bool
    public let expiration: String?
    public let isBroadcast: Bool?

    public struct Cost: Codable, Sendable, Equatable {
        public let amount: Int
        public let type: String
    }
}

public struct ExtensionBitsProductUpdate: Encodable, Sendable, Equatable {
    public let sku: String
    public let cost: ExtensionBitsProduct.Cost
    public let displayName: String
    public let inDevelopment: Bool
    public let expiration: String?
    public let isBroadcast: Bool?

    public init(
        sku: String,
        cost: ExtensionBitsProduct.Cost,
        displayName: String,
        inDevelopment: Bool,
        expiration: String? = nil,
        isBroadcast: Bool? = nil
    ) {
        self.sku = sku
        self.cost = cost
        self.displayName = displayName
        self.inDevelopment = inDevelopment
        self.expiration = expiration
        self.isBroadcast = isBroadcast
    }
}
