// SPDX-License-Identifier: EUPL-1.2

import Foundation

/// Adresse de l'espace Jalonio : chaque organisation a la sienne (`<espace>.jalonio.fr`),
/// et une installation sur site a son propre domaine.
public enum ServerAddress {
    public static let saasDomain = "jalonio.fr"

    /// Adresse saisie → origine du serveur (`https://hôte[:port]`).
    ///
    /// - « mairie-x » devient `https://mairie-x.jalonio.fr` ;
    /// - un domaine (« projets.mairie.fr ») ou une adresse complète sont gardés ;
    /// - le clair (`http://`) n'est permis que vers un serveur local (développement).
    ///
    /// Renvoie `nil` si l'adresse est invalide.
    public static func parse(_ input: String) -> URL? {
        var raw = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while raw.hasSuffix("/") { raw.removeLast() }
        guard !raw.isEmpty, !raw.contains(" ") else { return nil }
        let withScheme: String
        if raw.hasPrefix("https://") || raw.hasPrefix("http://") {
            withScheme = raw
        } else if !raw.contains(".") && !raw.contains(":") {
            withScheme = "https://\(raw).\(saasDomain)"
        } else {
            withScheme = "https://\(raw)"
        }
        guard let components = URLComponents(string: withScheme),
              let scheme = components.scheme, let host = components.host, !host.isEmpty
        else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard host.unicodeScalars.allSatisfy({ allowed.contains($0) }), !host.hasPrefix("."), !host.hasSuffix("."), !host.contains("..") else { return nil }
        let local = host == "localhost" || host == "127.0.0.1"
        // Un nom de domaine complet, ou un serveur local
        if !local && !host.contains(".") { return nil }
        if scheme == "http" && !local { return nil }
        guard scheme == "https" || scheme == "http" else { return nil }
        var origin = URLComponents()
        origin.scheme = scheme
        origin.host = host
        origin.port = components.port
        return origin.url
    }

    /// Adresse de l'API de l'espace : `<origine>/backend/api/` (ADR-0003 du dépôt `jalonio`).
    public static func apiBase(for origin: URL) -> URL {
        origin.appendingPathComponent("backend", isDirectory: true).appendingPathComponent("api", isDirectory: true)
    }

    /// Nom affiché de l'espace (« mairie-x.jalonio.fr »).
    public static func displayName(for origin: URL) -> String {
        guard let host = origin.host else { return origin.absoluteString }
        if let port = origin.port { return "\(host):\(port)" }
        return host
    }

    /// Page de l'application web de l'espace (« /profil/ », « /mot-de-passe/oubli/ »…).
    public static func webPage(_ path: String, origin: URL) -> URL {
        URL(string: path, relativeTo: origin)?.absoluteURL ?? origin
    }
}
