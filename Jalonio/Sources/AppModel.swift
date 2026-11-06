// SPDX-License-Identifier: EUPL-1.2

import Foundation
import JalonioKit
import Observation
import UIKit

/// État de la session : espace enregistré, jetons, personne connectée. Seul point de
/// contact des écrans avec l'API.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case signedOut(message: String?)
        case signedIn(Me)
        /// Session présente mais serveur injoignable au lancement.
        case unreachable(String)
    }

    private(set) var phase: Phase = .launching
    /// Augmente après chaque modification : les listes visibles se rechargent.
    private(set) var revision = 0
    var unread = 0

    let api: APIClient
    private let server: ServerStore
    private let tokens: TokenStore

    init(server: ServerStore = DefaultsServerStore(), tokens: TokenStore = KeychainTokenStore(), transport: HTTPTransport = URLSessionTransport()) {
        self.server = server
        self.tokens = tokens
        // Le rappel vient de l'acteur du client : retour sur le fil principal.
        let relay = SignOutRelay()
        api = APIClient(server: server, tokens: tokens, transport: transport, languages: { AppModel.acceptLanguage() }, onSignedOut: { relay.fire() })
        relay.model = self
    }

    var origin: URL? { server.origin }
    var workspace: String? { origin.map(ServerAddress.displayName(for:)) }
    var me: Me? { if case .signedIn(let me) = phase { return me } else { return nil } }

    // MARK: Session

    func start() async {
        guard server.origin != nil, tokens.tokens != nil else {
            phase = .signedOut(message: nil)
            return
        }
        do {
            phase = .signedIn(try await api.me())
            await refreshUnread()
        } catch APIFailure.signedOut {
            phase = .signedOut(message: L.tr("error_session_expired"))
        } catch {
            phase = .unreachable(L.message(for: error))
        }
    }

    /// Connexion : renvoie le défi de double authentification s'il y en a un.
    func login(origin: URL, email: String, password: String) async throws -> String? {
        server.save(origin: origin)
        let response = try await api.login(email: email, password: password, device: Self.device)
        return try await finish(response)
    }

    func twoFactor(challenge: String, code: String) async throws {
        _ = try await finish(try await api.twoFactor(challenge: challenge, code: code, device: Self.device))
    }

    private func finish(_ response: LoginResponse) async throws -> String? {
        if response.twoFactorRequired, let challenge = response.challenge { return challenge }
        guard let pair = response.tokens else { throw APIFailure.unexpected }
        tokens.save(pair)
        let me: Me
        if let user = response.user { me = user } else { me = try await api.me() }
        phase = .signedIn(me)
        await refreshUnread()
        return nil
    }

    /// Déconnexion : le serveur révoque l'appareil ; la session locale s'efface dans tous les cas.
    func logout() async {
        try? await api.logout()
        tokens.clear()
        unread = 0
        phase = .signedOut(message: nil)
    }

    fileprivate func sessionExpired() {
        guard case .signedIn = phase else { return }
        unread = 0
        phase = .signedOut(message: L.tr("error_session_expired"))
    }

    // MARK: Données partagées

    func changed() { revision += 1 }

    func refreshUnread() async {
        if let list = try? await api.notifications() { unread = list.unread }
    }

    // MARK: Appareil et langue

    /// Nom de l'appareil dans « Appareils connectés » du profil web. Depuis iOS 16, le nom
    /// donné par la personne n'est plus lisible sans autorisation : modèle et identifiant.
    static var device: DeviceInfo {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return DeviceInfo(name: "\(UIDevice.current.model) (\(machine))")
    }

    /// Langue de l'interface d'abord (choisie dans les Réglages), puis celles de l'appareil :
    /// les messages d'erreur du serveur arrivent dans la langue affichée.
    nonisolated static func acceptLanguage() -> String {
        let ui = Bundle.main.preferredLocalizations.first ?? "en"
        var tags = [ui]
        for language in Locale.preferredLanguages where !tags.contains(language) && tags.count < 5 { tags.append(language) }
        return tags.enumerated().map { index, tag in
            index == 0 ? tag : String(format: "%@;q=%.1f", tag, 1.0 - Double(index) / 10)
        }.joined(separator: ",")
    }
}

/// Relais du client vers le modèle : la session expirée ramène à l'écran de connexion.
private final class SignOutRelay: @unchecked Sendable {
    weak var model: AppModel?

    func fire() {
        Task { @MainActor [weak self] in self?.model?.sessionExpired() }
    }
}
