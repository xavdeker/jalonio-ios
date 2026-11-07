// SPDX-License-Identifier: EUPL-1.2

import Foundation

/// Routes de l'API utilisées par l'application (mêmes routes que l'application Android).
extension APIClient {
    // MARK: Session

    public func login(email: String, password: String, device: DeviceInfo) async throws -> LoginResponse {
        try await send("POST", "auth/login", body: LoginRequest(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, device: device))
    }

    public func twoFactor(challenge: String, code: String, device: DeviceInfo) async throws -> LoginResponse {
        let compact = code.filter { !$0.isWhitespace }
        return try await send("POST", "auth/two-factor", body: TwoFactorRequest(challenge: challenge, code: compact, device: device))
    }

    /// Révoque l'appareil côté serveur.
    public func logout() async throws {
        _ = try await send("POST", "auth/mobile/logout", as: EmptyResponse.self)
    }

    public func me() async throws -> Me {
        try await send("GET", "me")
    }

    // MARK: Tickets et projets

    public func myTickets() async throws -> [MyTicket] {
        try await send("GET", "my/tickets")
    }

    public func projects() async throws -> [ProjectSummary] {
        try await send("GET", "projects")
    }

    public func project(_ key: String) async throws -> ProjectDetail {
        try await send("GET", "projects/\(key)")
    }

    public func tickets(project key: String, search: String? = nil) async throws -> TicketPage {
        var query = [URLQueryItem(name: "perPage", value: "300")]
        if let search, !search.trimmingCharacters(in: .whitespaces).isEmpty {
            query.append(URLQueryItem(name: "q", value: search.trimmingCharacters(in: .whitespaces)))
        }
        return try await send("GET", "projects/\(key)/tickets", query: query)
    }

    public func createTicket(project key: String, title: String, typeId: Int?) async throws -> TicketDetail {
        try await send("POST", "projects/\(key)/tickets", body: CreateTicketRequest(title: title.trimmingCharacters(in: .whitespacesAndNewlines), typeId: typeId))
    }

    public func ticket(_ key: String) async throws -> TicketDetail {
        try await send("GET", "tickets/\(key)")
    }

    /// Changement de statut ; `version` protège d'une modification concurrente (409).
    public func setStatus(_ ticket: TicketDetail, statusId: Int) async throws -> TicketDetail {
        try await send("PATCH", "tickets/\(ticket.key)", body: TicketUpdate(field: .status(statusId), version: ticket.version))
    }

    /// Assignation (`nil` : retirer l'assignation).
    public func assign(_ ticket: TicketDetail, userId: String?) async throws -> TicketDetail {
        try await send("PATCH", "tickets/\(ticket.key)", body: TicketUpdate(field: .assignee(userId), version: ticket.version))
    }

    /// Tableau du projet, dans l'ordre des colonnes (comme sur le web).
    public func board(project key: String) async throws -> BoardData {
        try await send("GET", "projects/\(key)/board")
    }

    /// Déplacement sur le tableau : statut et place entre deux voisins (`nil` : bord de colonne).
    public func move(_ key: String, statusId: Int, after afterKey: String?, before beforeKey: String?) async throws -> TicketCard {
        try await send("POST", "tickets/\(key)/move", body: MoveRequest(statusId: statusId, afterKey: afterKey, beforeKey: beforeKey))
    }

    public func activity(_ key: String) async throws -> [ActivityItem] {
        try await send("GET", "tickets/\(key)/activity")
    }

    public func comment(_ key: String, body: String) async throws {
        _ = try await send("POST", "tickets/\(key)/comments", body: CommentRequest(body: body.trimmingCharacters(in: .whitespacesAndNewlines)), as: EmptyResponse.self)
    }

    // MARK: Notifications

    public func notifications() async throws -> NotificationList {
        try await send("GET", "notifications", query: [URLQueryItem(name: "limit", value: "50")])
    }

    @discardableResult
    public func markAllRead() async throws -> UnreadCount {
        try await send("POST", "notifications/read", body: ["all": true])
    }
}

struct MoveRequest: Encodable {
    let statusId: Int
    let afterKey: String?
    let beforeKey: String?
}

/// Modification d'un ticket : un champ et la version lue (verrou optimiste du serveur).
/// `assigneeId` nul est envoyé explicitement (`null`), pas omis.
struct TicketUpdate: Encodable {
    enum Field {
        case status(Int)
        case assignee(String?)
    }

    let field: Field
    let version: Int

    enum CodingKeys: String, CodingKey { case statusId, assigneeId, version }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch field {
        case .status(let id): try c.encode(id, forKey: .statusId)
        case .assignee(let id): try c.encode(id, forKey: .assigneeId)
        }
        try c.encode(version, forKey: .version)
    }
}
