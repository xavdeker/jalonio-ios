// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI

/// Textes de l'application (Resources/<langue>.lproj, produits par scripts/strings.py).
enum L {
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return args.isEmpty ? format : String(format: format, locale: Locale.current, arguments: args)
    }

    /// Pluriel (Localizable.stringsdict).
    static func plural(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), count)
    }

    /// Message d'un échec : celui du serveur (déjà traduit) s'il existe.
    static func message(for error: Error) -> String {
        switch error as? APIFailure {
        case .server(_, _, let message?) where !message.isEmpty: return message
        case .server: return tr("error_server")
        case .network: return tr("error_network")
        case .signedOut: return tr("error_session_expired")
        case .unexpected, .none: return tr("error_unexpected")
        }
    }

    static func priority(_ value: String) -> String {
        switch value {
        case "critical": return tr("priority_critical")
        case "high": return tr("priority_high")
        case "low": return tr("priority_low")
        default: return tr("priority_normal")
        }
    }

    static func day(_ value: String?) -> String? {
        JalonioDates.day(value).map { $0.formatted(date: .abbreviated, time: .omitted) }
    }

    static func instant(_ value: String?) -> String? {
        JalonioDates.instant(value).map { $0.formatted(date: .abbreviated, time: .shortened) }
    }

    static func relative(_ value: String?) -> String? {
        JalonioDates.instant(value).map { $0.formatted(.relative(presentation: .named)) }
    }
}

/// Couleurs de la charte (frontend/app/globals.css du dépôt `jalonio`).
enum Brand {
    static let green = Color("AccentColor")
    static let mint = Color(hex: "#5ff2c8")
    static let pink = Color(hex: "#ff4f8b")
    /// Rouge et orange lisibles en petit texte (contraste ≥ 4,5:1 en clair et en sombre) ;
    /// ceux du système sont trop pâles sur fond blanc.
    static let danger = Color("Danger")
    static let warning = Color("Warning")
    /// Texte atténué (≥ 4,5:1) : le gris secondaire d'iOS ne fait que 3,4:1 sur fond blanc.
    static let muted = Color("Muted")
}

extension Color {
    /// « #00735c » → couleur ; gris si la valeur est illisible.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).prefix(6)
        let value = UInt32(digits, radix: 16) ?? 0x7a8496
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

/// Chargement d'une valeur : attente, erreur avec « Réessayer », ou contenu.
struct Loadable<Value, Content: View>: View {
    let load: () async throws -> Value
    var id: AnyHashable = 0
    @ViewBuilder let content: (Value, _ reload: @escaping () async -> Void) -> Content

    @State private var value: Value?
    @State private var error: String?

    var body: some View {
        Group {
            if let value {
                content(value, reload)
            } else if let error {
                ErrorState(message: error) { Task { await reload() } }
            } else {
                ProgressView(L.tr("loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: id) { await reload() }
    }

    private func reload() async {
        do {
            value = try await load()
            error = nil
        } catch is CancellationError {
            // Vue quittée ou rechargée : rien à afficher
        } catch {
            if value == nil { self.error = L.message(for: error) }
        }
    }
}

struct ErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L.tr("error_server"), systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(L.tr("retry"), action: retry).buttonStyle(.borderedProminent)
        }
    }
}

struct EmptyState: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(text).foregroundStyle(Brand.muted))
    }
}

/// Initiales d'une personne dans une pastille (avatar du web).
struct Avatar: View {
    let initials: String
    var size: CGFloat = 28
    /// Suit la taille de texte choisie dans les réglages (Dynamic Type)
    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        let size = self.size * scale
        return Text(initials)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(Color(hex: "#00382d"))
            .frame(width: size, height: size)
            .background(Brand.mint.opacity(0.55), in: Circle())
            .accessibilityHidden(true)
    }
}

struct PriorityLabel: View {
    let priority: String

    // Icône et texte côte à côte (un Label laisse une colonne d'icône vide dans les listes)
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: style.symbol).accessibilityHidden(true)
            Text(L.priority(priority))
        }
        .foregroundStyle(style.color)
    }

    private var style: (symbol: String, color: Color) {
        switch priority {
        case "critical": return ("exclamationmark.2", Brand.danger)
        case "high": return ("arrow.up", Brand.warning)
        case "low": return ("arrow.down", Brand.muted)
        default: return ("equal", Brand.muted)
        }
    }
}

/// Échéance, en rouge si elle est dépassée (et le ticket ouvert).
struct DueLabel: View {
    let dueDate: String?
    var resolved = false

    var body: some View {
        if let text = L.day(dueDate) {
            let overdue = !resolved && JalonioDates.isOverdue(dueDate)
            HStack(spacing: 4) {
                Image(systemName: "calendar").accessibilityHidden(true)
                Text(overdue ? "\(text) · \(L.tr("ticket_overdue"))" : text)
            }
            .foregroundStyle(overdue ? Brand.danger : Brand.muted)
        }
    }
}

/// Type de ticket : pastille de sa couleur et nom en couleur atténuée (la couleur choisie
/// pour le type peut être trop claire pour du texte).
struct TypeLabel: View {
    let type: TicketTypeInfo

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: type.color)).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(type.name).foregroundStyle(Brand.muted)
        }
    }
}

/// En-tête de section en couleur atténuée conforme (celle du système est trop pâle).
extension Section where Parent == Text, Footer == EmptyView, Content: View {
    init(muted title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { Text(title).foregroundStyle(Brand.muted) })
    }
}
