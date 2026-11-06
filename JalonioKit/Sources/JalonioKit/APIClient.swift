// SPDX-License-Identifier: EUPL-1.2

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Échec d'un appel : message du serveur (déjà dans la langue de l'application),
/// réseau indisponible, ou erreur inattendue.
public enum APIFailure: Error, Equatable, Sendable {
    case server(status: Int, code: String?, message: String?)
    case network
    case unexpected
    /// Aucun espace enregistré, ou session expirée : retour à l'écran de connexion.
    case signedOut
}

/// Transport HTTP, remplaçable dans les tests.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = URLSession(configuration: .ephemeral)) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Réponse sans contenu utile (204, ou corps ignoré).
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}

/// Client de l'API Jalonio : adresse de l'espace, jeton d'accès, langue, rafraîchissement.
///
/// Le rafraîchissement est **sérialisé** (base KersAI [46]) : sans cela, des requêtes
/// parallèles consommeraient chacune le jeton de rafraîchissement, et le serveur, y
/// voyant un rejeu, révoquerait l'appareil.
public actor APIClient {
    private let server: ServerStore
    private let tokens: TokenStore
    private let transport: HTTPTransport
    private let languages: @Sendable () -> String
    private let onSignedOut: @Sendable () -> Void
    private var refreshTask: Task<TokenPair, Error>?

    private static let authPaths: Set<String> = ["auth/login", "auth/two-factor", "auth/mobile/refresh"]

    public init(
        server: ServerStore,
        tokens: TokenStore,
        transport: HTTPTransport = URLSessionTransport(),
        languages: @escaping @Sendable () -> String = { "en" },
        onSignedOut: @escaping @Sendable () -> Void = {}
    ) {
        self.server = server
        self.tokens = tokens
        self.transport = transport
        self.languages = languages
        self.onSignedOut = onSignedOut
    }

    // MARK: Appel générique

    public func send<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        let payload = try body.map { try JSONEncoder().encode(AnyEncodable($0)) }
        let authenticated = !Self.authPaths.contains(path)
        let accessToken = authenticated ? tokens.tokens?.accessToken : nil
        let (data, response) = try await perform(method, path, query: query, body: payload, accessToken: accessToken)

        if response.statusCode == 401, let failedToken = accessToken {
            let fresh = try await refreshedToken(after: failedToken)
            let (retryData, retryResponse) = try await perform(method, path, query: query, body: payload, accessToken: fresh.accessToken)
            return try decode(T.self, data: retryData, response: retryResponse)
        }
        return try decode(T.self, data: data, response: response)
    }

    private func perform(_ method: String, _ path: String, query: [URLQueryItem], body: Data?, accessToken: String?) async throws -> (Data, HTTPURLResponse) {
        guard let origin = server.origin else { throw APIFailure.signedOut }
        var components = URLComponents(url: ServerAddress.apiBase(for: origin).appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIFailure.unexpected }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Toute requête non GET porte cet en-tête (protection CSRF de l'API)
        request.setValue("1", forHTTPHeaderField: "X-Jalonio-Requested")
        request.setValue(languages(), forHTTPHeaderField: "Accept-Language")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        do {
            return try await transport.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIFailure.network
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, data: Data, response: HTTPURLResponse) throws -> T {
        guard (200..<300).contains(response.statusCode) else {
            let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw APIFailure.server(status: response.statusCode, code: body?.error, message: body?.message)
        }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIFailure.unexpected
        }
    }

    /// Jeton d'accès valide après l'échec de `failedToken` : déjà renouvelé par une autre
    /// requête, ou renouvelé une seule fois pour toutes les requêtes en attente.
    private func refreshedToken(after failedToken: String) async throws -> TokenPair {
        if let current = tokens.tokens, current.accessToken != failedToken { return current }
        if let running = refreshTask { return try await running.value }
        guard let refreshToken = tokens.tokens?.refreshToken else {
            signOut()
            throw APIFailure.signedOut
        }
        let task = Task { [self] in try await self.refresh(using: refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func refresh(using refreshToken: String) async throws -> TokenPair {
        let (data, response) = try await perform("POST", "auth/mobile/refresh", query: [], body: try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken)), accessToken: nil)
        guard (200..<300).contains(response.statusCode), let pair = try? JSONDecoder().decode(RefreshResponse.self, from: data).tokens else {
            // Refus du serveur (expiré, révoqué, rejoué) : reconnexion nécessaire.
            // Une panne du serveur (5xx) garde la session pour un nouvel essai.
            if (400..<500).contains(response.statusCode) {
                signOut()
                throw APIFailure.signedOut
            }
            throw APIFailure.server(status: response.statusCode, code: nil, message: nil)
        }
        tokens.save(pair)
        return pair
    }

    private func signOut() {
        tokens.clear()
        onSignedOut()
    }
}

/// Enveloppe d'un corps encodable quelconque.
struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
