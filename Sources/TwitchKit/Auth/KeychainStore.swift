import Foundation
import os
import Security

private let logger = Logger(subsystem: "com.twitchkit", category: "keychain")

/// A Keychain operation behind ``KeychainTokenStore`` failed.
public enum KeychainError: Error, Sendable, Equatable {
    /// Saving the token failed with this `OSStatus`.
    case saveFailed(OSStatus)
    /// Reading the token failed with this `OSStatus`.
    case loadFailed(OSStatus)

    /// The Security framework status code.
    public var status: OSStatus {
        switch self {
        case .saveFailed(let status), .loadFailed(let status): status
        }
    }

    /// Whether the Keychain refused because the device is locked and hasn't
    /// been unlocked since boot (`errSecInteractionNotAllowed`), for example
    /// in a background launch before first unlock. The token isn't lost:
    /// try again after the user unlocks the device.
    public var isInteractionNotAllowed: Bool {
        status == errSecInteractionNotAllowed
    }
}

enum KeychainStore {
    /// Service attribute scoping TwitchKit's keychain items. Without it,
    /// items are only distinguished by account, so any other code writing
    /// generic passwords with the same account string would collide.
    private static let service = "com.twitchkit.oauth-tokens"

    /// Accessibility class for every item TwitchKit writes: readable after
    /// the first unlock (so background refreshes work), never synced or
    /// restored to another device.
    static var accessibility: CFString { kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly }

    /// Base query matching TwitchKit's item for `key`. `scopedToService`
    /// false yields the legacy shape (no `kSecAttrService`) used by items
    /// written before the service attribute was introduced.
    static func query(key: String, accessGroup: String? = nil, scopedToService: Bool = true) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        if scopedToService {
            query[kSecAttrService as String] = service
        }
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    /// Attributes written by `SecItemUpdate` on save. Re-applying the
    /// accessibility class moves items written by older versions (or other
    /// code) onto the device-only class.
    static func updateAttributes(data: Data) -> [String: Any] {
        [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
        ]
    }

    /// Attributes applied when migrating a legacy (no-service) item.
    static func migrationAttributes() -> [String: Any] {
        [
            kSecAttrService as String: service,
            kSecAttrAccessible as String: accessibility,
        ]
    }

    static func save(key: String, data: Data, accessGroup: String? = nil) throws {
        // Update-then-add, service-scoped. A legacy (no-service) item is
        // deliberately NOT updated here: load(key:) migrates it on first
        // read, and a fresh save while an unmigrated legacy item still
        // exists just creates the service-scoped item alongside it — the
        // legacy copy becomes unreachable garbage that delete(key:)'s
        // legacy pass removes.
        let query = Self.query(key: key, accessGroup: accessGroup)

        let status = SecItemUpdate(query as CFDictionary, updateAttributes(data: data) as CFDictionary)
        if status == errSecSuccess {
            return
        }

        guard status == errSecItemNotFound else {
            logger.error("Keychain save failed: OSStatus \(status, privacy: .public)")
            throw KeychainError.saveFailed(status)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            logger.error("Keychain add failed: OSStatus \(addStatus, privacy: .public)")
            throw KeychainError.saveFailed(addStatus)
        }
    }

    static func load(key: String, accessGroup: String? = nil) throws -> Data? {
        if let data = try copyData(matching: query(key: key, accessGroup: accessGroup)) {
            return data
        }

        // Legacy fallback: items written before the service attribute
        // existed carry no kSecAttrService, so the scoped query above
        // misses them. A query without kSecAttrService also matches items
        // that HAVE a service — harmless here, because this path only runs
        // when the service-scoped query already found nothing.
        let legacyQuery = query(key: key, accessGroup: accessGroup, scopedToService: false)
        guard let legacyData = try copyData(matching: legacyQuery) else {
            return nil
        }

        // Migrate the legacy item in place so future loads hit the
        // service-scoped query directly. A failed migration is only logged:
        // the data was read successfully and the fallback keeps working.
        let migrationStatus = SecItemUpdate(legacyQuery as CFDictionary, migrationAttributes() as CFDictionary)
        if migrationStatus != errSecSuccess {
            logger.warning("Keychain service migration returned OSStatus \(migrationStatus, privacy: .public)")
        }
        return legacyData
    }

    static func delete(key: String, accessGroup: String? = nil) {
        // Delete both the service-scoped item and any legacy no-service
        // item, so logout can never leave a stale legacy token behind.
        delete(query: query(key: key, accessGroup: accessGroup))
        delete(query: query(key: key, accessGroup: accessGroup, scopedToService: false))
    }

    private static func copyData(matching query: [String: Any]) throws -> Data? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            logger.error("Keychain load failed: OSStatus \(status, privacy: .public)")
            throw KeychainError.loadFailed(status)
        }
        return result as? Data
    }

    private static func delete(query: [String: Any]) {
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.warning("Keychain delete returned OSStatus \(status, privacy: .public)")
        }
    }
}
