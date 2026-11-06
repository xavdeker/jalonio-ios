// SPDX-License-Identifier: EUPL-1.2

import Foundation
#if canImport(Security)
import Security
#endif

/// Jetons mobiles de l'appareil (accès 1 h, rafraîchissement 90 jours, ADR-0029).
public protocol TokenStore: AnyObject, Sendable {
    var tokens: TokenPair? { get }
    func save(_ tokens: TokenPair)
    func clear()
}

/// Origine de l'espace enregistré (rien de secret).
public protocol ServerStore: AnyObject, Sendable {
    var origin: URL? { get }
    func save(origin: URL)
}

/// Jetons en mémoire (tests, aperçus).
public final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: TokenPair?

    public init(_ tokens: TokenPair? = nil) { value = tokens }

    public var tokens: TokenPair? { lock.withLock { value } }
    public func save(_ tokens: TokenPair) { lock.withLock { value = tokens } }
    public func clear() { lock.withLock { value = nil } }
}

/// Origine en mémoire (tests, aperçus).
public final class MemoryServerStore: ServerStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: URL?

    public init(_ origin: URL? = nil) { value = origin }

    public var origin: URL? { lock.withLock { value } }
    public func save(origin: URL) { lock.withLock { value = origin } }
}

/// Origine dans les préférences de l'application.
public final class DefaultsServerStore: ServerStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "jalonio.origin"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var origin: URL? { defaults.string(forKey: key).flatMap(URL.init(string:)) }
    public func save(origin: URL) { defaults.set(origin.absoluteString, forKey: key) }
}

#if canImport(Security)
/// Jetons dans le trousseau, liés à cet appareil : ni sauvegarde iCloud, ni transfert
/// vers un autre iPhone (équivalent du Keystore Android, base KersAI [46]). Lisibles
/// après le premier déverrouillage, pour qu'une actualisation en arrière-plan reste possible.
public final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private let service: String
    private let account = "mobile-tokens"
    private var cache: TokenPair??

    public init(service: String = "fr.jalonio.app.tokens") { self.service = service }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    public var tokens: TokenPair? {
        lock.withLock {
            if let cached = cache { return cached }
            var request = query
            request[kSecReturnData as String] = true
            request[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            let found = SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess
            let value = found ? (item as? Data).flatMap { try? JSONDecoder().decode(TokenPair.self, from: $0) } : nil
            cache = .some(value)
            return value
        }
    }

    public func save(_ tokens: TokenPair) {
        lock.withLock {
            guard let data = try? JSONEncoder().encode(tokens) else { return }
            SecItemDelete(query as CFDictionary)
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
            cache = .some(tokens)
        }
    }

    public func clear() {
        lock.withLock {
            SecItemDelete(query as CFDictionary)
            cache = .some(nil)
        }
    }
}
#endif
