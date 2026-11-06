// SPDX-License-Identifier: EUPL-1.2

import Foundation

/// Sens d'une notification, indépendant de la langue : l'application rédige le texte
/// (les types du serveur ne s'affichent jamais tels quels).
public enum NotificationMessage: Equatable, Sendable {
    case assigned(actor: String?, key: String, title: String)
    case mentioned(actor: String?, key: String, title: String)
    case mentionedInNote(actor: String?, note: String, project: String)
    case commented(actor: String?, key: String, title: String)
    case statusChanged(actor: String?, key: String, status: String)
    case dueSoon(key: String, title: String)
    case overdue(key: String, title: String)
    case sprintStarted(sprint: String, project: String)
    case sprintClosed(sprint: String, project: String)
    case importDone(project: String)
    case addedToProject(actor: String?, project: String)
    /// Type inconnu de cette version : clé et titre s'ils existent.
    case other(summary: String?)
}

extension NotificationItem {
    public var message: NotificationMessage {
        let actor = self.actor?.displayName ?? value("actor")
        let key = value("key") ?? ""
        let title = value("title") ?? ""
        let project = value("project") ?? ""
        switch type {
        case "assigned": return .assigned(actor: actor, key: key, title: title)
        case "mentioned":
            return value("note") != nil ? .mentionedInNote(actor: actor, note: title, project: project) : .mentioned(actor: actor, key: key, title: title)
        case "commented": return .commented(actor: actor, key: key, title: title)
        case "status_changed": return .statusChanged(actor: actor, key: key, status: value("status") ?? "")
        case "due_soon": return .dueSoon(key: key, title: title)
        case "overdue": return .overdue(key: key, title: title)
        case "sprint":
            let sprint = value("sprint") ?? ""
            return value("event") == "closed" ? .sprintClosed(sprint: sprint, project: project) : .sprintStarted(sprint: sprint, project: project)
        case "import_done": return .importDone(project: project)
        case "added_to_project": return .addedToProject(actor: actor, project: project)
        default:
            let summary = [key, title].filter { !$0.isEmpty }.joined(separator: " · ")
            return .other(summary: summary.isEmpty ? nil : summary)
        }
    }

    /// Ticket à ouvrir quand on touche la notification (s'il y en a un).
    public var ticketKey: String? {
        guard value("note") == nil, let key = value("key"), !key.isEmpty else { return nil }
        return key
    }
}

extension Array where Element == MyTicket {
    /// Tickets ouverts d'abord, triés par échéance (sans échéance à la fin), puis par clé.
    public func sortedForHome() -> [MyTicket] {
        sorted { a, b in
            if a.resolved != b.resolved { return !a.resolved }
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.key.localizedStandardCompare(b.key) == .orderedAscending
            }
        }
    }
}

public enum JalonioDates {
    /// « 2026-10-28 » (échéance) → date à midi dans le fuseau de l'appareil, sans décalage de jour.
    public static func day(_ value: String?) -> Date? {
        guard let value, value.count >= 10 else { return nil }
        let parts = value.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// Horodatage ISO 8601 du serveur (« 2026-10-21T00:36:34+00:00 »).
    public static func instant(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    /// Échéance dépassée (strictement avant aujourd'hui).
    public static func isOverdue(_ value: String?, now: Date = Date()) -> Bool {
        guard let due = day(value) else { return false }
        return Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: now)
    }
}
