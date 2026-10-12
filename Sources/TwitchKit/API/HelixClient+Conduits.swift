import Foundation

extension HelixClient {
    /// Gets EventSub conduits for the authenticated client.
    public func fetchConduits() async throws -> [EventSubConduit] {
        let response: HelixResponse<EventSubConduit> = try await request(endpoint: "eventsub/conduits")
        return response.data
    }

    /// Creates an EventSub conduit.
    public func createConduit(shardCount: Int) async throws -> EventSubConduit {
        let response: HelixResponse<EventSubConduit> = try await request(
            endpoint: "eventsub/conduits",
            method: "POST",
            body: try JSONEncoder.twitch().encode(ConduitCreateRequest(shardCount: shardCount))
        )
        guard let conduit = response.data.first else { throw HelixError.emptyResponse }
        return conduit
    }

    /// Updates an EventSub conduit's shard count.
    public func updateConduit(id: String, shardCount: Int) async throws -> EventSubConduit {
        let response: HelixResponse<EventSubConduit> = try await request(
            endpoint: "eventsub/conduits",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(ConduitUpdateRequest(id: id, shardCount: shardCount))
        )
        guard let conduit = response.data.first else { throw HelixError.emptyResponse }
        return conduit
    }

    /// Deletes an EventSub conduit.
    public func deleteConduit(id: String) async throws {
        try await requestNoContent(
            endpoint: "eventsub/conduits",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
    }

    /// Gets one page of EventSub conduit shards.
    public func fetchConduitShardsPage(
        conduitID: String,
        status: ConduitShardStatus? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<EventSubConduitShard> {
        var queryItems = [URLQueryItem(name: "conduit_id", value: conduitID)]
        HelixQuery.append(HelixQuery.item("status", status?.rawValue), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<EventSubConduitShard> = try await request(
            endpoint: "eventsub/conduits/shards",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of EventSub conduit shards.
    ///
    /// - Parameters:
    ///   - conduitID: The conduit whose shards are returned.
    ///   - status: Optional shard status filter.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Conduit Shards](https://dev.twitch.tv/docs/api/reference/#get-conduit-shards)
    public func conduitShards(
        conduitID: String,
        status: ConduitShardStatus? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<EventSubConduitShard> {
        var queryItems = [URLQueryItem(name: "conduit_id", value: conduitID)]
        HelixQuery.append(HelixQuery.item("status", status?.rawValue), to: &queryItems)
        return pagedRequest(endpoint: "eventsub/conduits/shards", queryItems: queryItems, pageSize: pageSize)
    }

    /// Updates one or more EventSub conduit shards.
    ///
    /// Twitch responds with HTTP 202 and reports per-shard outcomes: shards it accepted in
    /// `data` and shards it rejected in `errors`. The request can succeed while individual
    /// shards fail, so check ``ConduitShardUpdateResult/errors`` for partial failures.
    ///
    /// - Parameters:
    ///   - conduitID: The conduit whose shards are updated.
    ///   - shards: The shard transport updates to apply.
    /// - Returns: The per-shard successes and failures reported by Twitch.
    /// - SeeAlso: [Update Conduit Shards](https://dev.twitch.tv/docs/api/reference/#update-conduit-shards)
    public func updateConduitShards(
        conduitID: String,
        shards: [EventSubConduitShardUpdate]
    ) async throws -> ConduitShardUpdateResult {
        guard (1...100).contains(shards.count) else {
            throw HelixError.badRequest(.fallback(status: 400, message: "Between 1 and 100 conduit shards are required"))
        }
        let data = try await requestRawData(
            endpoint: "eventsub/conduits/shards",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(ConduitShardsUpdateRequest(
                conduitId: conduitID,
                shards: shards
            )),
            acceptedStatusCodes: [200, 202],
            fallbackMessage: "Conduit shard update response expected"
        )
        do {
            let envelope = try JSONDecoder.twitch().decode(ConduitShardsUpdateResponse.self, from: data)
            return ConduitShardUpdateResult(updated: envelope.data, errors: envelope.errors ?? [])
        } catch {
            throw HelixError.decodingFailed(error.localizedDescription)
        }
    }
}

private struct ConduitCreateRequest: Encodable {
    let shardCount: Int
}

private struct ConduitUpdateRequest: Encodable {
    let id: String
    let shardCount: Int
}

private struct ConduitShardsUpdateRequest: Encodable {
    let conduitId: String
    let shards: [EventSubConduitShardUpdate]
}

private struct ConduitShardsUpdateResponse: Decodable {
    let data: [EventSubConduitShard]
    let errors: [ConduitShardUpdateError]?
}

public struct EventSubConduit: Decodable, Sendable, Equatable {
    public let id: String
    public let shardCount: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        shardCount: Int
    ) {
        self.id = id
        self.shardCount = shardCount
    }
}

public struct EventSubConduitShard: Decodable, Sendable, Equatable {
    public let id: String
    public let status: ConduitShardStatus
    public let transport: EventSubConduitShardTransport

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        status: ConduitShardStatus,
        transport: EventSubConduitShardTransport
    ) {
        self.id = id
        self.status = status
        self.transport = transport
    }
}

public struct EventSubConduitShardUpdate: Encodable, Sendable, Equatable {
    public let id: String
    public let transport: EventSubConduitShardTransport

    public init(id: String, transport: EventSubConduitShardTransport) {
        self.id = id
        self.transport = transport
    }
}

/// The outcome of an Update Conduit Shards request, including per-shard failures.
public struct ConduitShardUpdateResult: Sendable, Equatable {
    /// Shards Twitch updated successfully.
    public let updated: [EventSubConduitShard]

    /// Shards Twitch failed to update.
    public let errors: [ConduitShardUpdateError]

    /// Creates an update result.
    ///
    /// - Parameters:
    ///   - updated: Shards Twitch updated successfully.
    ///   - errors: Shards Twitch failed to update.
    public init(updated: [EventSubConduitShard], errors: [ConduitShardUpdateError]) {
        self.updated = updated
        self.errors = errors
    }
}

/// A per-shard failure reported by Update Conduit Shards.
public struct ConduitShardUpdateError: Decodable, Sendable, Equatable {
    /// The ID of the shard that failed to update.
    public let id: String

    /// The reason the shard update failed.
    public let message: String

    /// An error code describing the failure, when Twitch includes one.
    public let code: String?

    /// Creates a per-shard failure.
    ///
    /// - Parameters:
    ///   - id: The ID of the shard that failed to update.
    ///   - message: The reason the shard update failed.
    ///   - code: An error code describing the failure, if any.
    public init(id: String, message: String, code: String? = nil) {
        self.id = id
        self.message = message
        self.code = code
    }
}

public struct EventSubConduitShardTransport: Codable, Sendable, Equatable {
    public let method: EventSubTransportMethod
    public let callback: URL?
    public let secret: String?
    public let sessionId: String?

    public init(
        method: EventSubTransportMethod,
        callback: URL? = nil,
        secret: String? = nil,
        sessionID: String? = nil
    ) {
        self.method = method
        self.callback = callback
        self.secret = secret
        self.sessionId = sessionID
    }
}
