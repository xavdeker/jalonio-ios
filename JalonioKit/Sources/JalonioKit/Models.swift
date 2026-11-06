// SPDX-License-Identifier: EUPL-1.2

import Foundation

// Objets échangés avec l'API Jalonio (frontend/lib/types.ts du dépôt `jalonio`).
// Les champs absents prennent une valeur par défaut : un champ ajouté ou retiré côté
// serveur ne doit pas faire échouer le décodage d'une réponse entière.

extension KeyedDecodingContainer {
    /// Valeur facultative avec repli : absente, nulle ou d'un autre type → `fallback`.
    func value<T: Decodable>(_ key: Key, or fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    func optional<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

// MARK: - Authentification

public struct DeviceInfo: Codable, Sendable, Equatable {
    public var name: String
    public var platform: String

    public init(name: String, platform: String = "ios") {
        self.name = String(name.prefix(80))
        self.platform = platform
    }
}

public struct LoginRequest: Encodable, Sendable {
    public var email: String
    public var password: String
    public var device: DeviceInfo
}

public struct TwoFactorRequest: Encodable, Sendable {
    public var challenge: String
    public var code: String
    public var device: DeviceInfo
}

public struct RefreshRequest: Encodable, Sendable {
    public var refreshToken: String
}

public struct TokenPair: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresIn: Int
    public var deviceId: String

    public init(accessToken: String, refreshToken: String, expiresIn: Int, deviceId: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.deviceId = deviceId
    }
}

public struct LoginResponse: Decodable, Sendable {
    public var twoFactorRequired: Bool
    public var challenge: String?
    public var user: Me?
    public var tokens: TokenPair?

    enum CodingKeys: String, CodingKey { case twoFactorRequired, challenge, user, tokens }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        twoFactorRequired = c.value(.twoFactorRequired, or: false)
        challenge = c.optional(.challenge)
        user = c.optional(.user)
        tokens = c.optional(.tokens)
    }
}

public struct RefreshResponse: Decodable, Sendable {
    public var tokens: TokenPair
}

/// Corps d'une erreur de l'API : `{error, message, violations?}` (App\Api\ApiError).
public struct APIErrorBody: Decodable, Sendable {
    public var error: String?
    public var message: String?
    public var violations: [String: [String]]?

    enum CodingKeys: String, CodingKey { case error, message, violations }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        error = c.optional(.error)
        message = c.optional(.message)
        violations = c.optional(.violations)
    }
}

// MARK: - Compte

public struct OrganizationInfo: Decodable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var slug: String
}

public struct MePermissions: Decodable, Sendable, Equatable {
    public var createProject: Bool

    public init(createProject: Bool = false) { self.createProject = createProject }

    enum CodingKeys: String, CodingKey { case createProject }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        createProject = c.value(.createProject, or: false)
    }
}

public struct Me: Decodable, Sendable, Equatable {
    public var id: String
    public var email: String
    public var displayName: String
    public var initials: String
    public var orgRole: String
    public var locale: String
    public var organization: OrganizationInfo
    public var permissions: MePermissions

    enum CodingKeys: String, CodingKey { case id, email, displayName, initials, orgRole, locale, organization, permissions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        displayName = try c.decode(String.self, forKey: .displayName)
        initials = c.value(.initials, or: "")
        orgRole = c.value(.orgRole, or: "member")
        locale = c.value(.locale, or: "fr")
        organization = try c.decode(OrganizationInfo.self, forKey: .organization)
        permissions = c.value(.permissions, or: MePermissions())
    }
}

public struct UserSummary: Decodable, Sendable, Equatable, Hashable {
    public var id: String
    public var displayName: String
    public var initials: String
    public var email: String?

    enum CodingKeys: String, CodingKey { case id, displayName, initials, email }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = c.value(.displayName, or: "")
        initials = c.value(.initials, or: "")
        email = c.optional(.email)
    }
}

// MARK: - Projets

public struct ProjectSummary: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var key: String
    public var name: String
    public var description: String?
    public var color: String
    public var openTickets: Int
    public var favorite: Bool
    public var archived: Bool

    public var id: String { key }

    enum CodingKeys: String, CodingKey { case key, name, description, color, openTickets, favorite, archived }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        name = try c.decode(String.self, forKey: .name)
        description = c.optional(.description)
        color = c.value(.color, or: "#00735c")
        openTickets = c.value(.openTickets, or: 0)
        favorite = c.value(.favorite, or: false)
        archived = c.value(.archived, or: false)
    }
}

public struct StatusInfo: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    /// todo, in_progress ou done
    public var category: String
    public var color: String
    public var position: Int

    enum CodingKeys: String, CodingKey { case id, name, category, color, position }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = c.value(.category, or: "todo")
        color = c.value(.color, or: "#7a8496")
        position = c.value(.position, or: 0)
    }
}

public struct TicketTypeInfo: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var id: Int
    public var key: String
    public var name: String
    public var color: String
    /// standard, epic ou subtask
    public var level: String
    public var active: Bool

    enum CodingKeys: String, CodingKey { case id, key, name, color, level, active }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        key = c.value(.key, or: "")
        name = try c.decode(String.self, forKey: .name)
        color = c.value(.color, or: "#2563eb")
        level = c.value(.level, or: "standard")
        active = c.value(.active, or: true)
    }
}

public struct ProjectPermissions: Decodable, Sendable, Equatable {
    public var manage: Bool
    public var contribute: Bool
    public var guest: Bool

    public init(manage: Bool = false, contribute: Bool = false, guest: Bool = false) {
        self.manage = manage
        self.contribute = contribute
        self.guest = guest
    }

    enum CodingKeys: String, CodingKey { case manage, contribute, guest }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        manage = c.value(.manage, or: false)
        contribute = c.value(.contribute, or: false)
        guest = c.value(.guest, or: false)
    }
}

public struct ProjectDetail: Decodable, Sendable, Equatable {
    public var key: String
    public var name: String
    public var color: String
    public var statuses: [StatusInfo]
    public var types: [TicketTypeInfo]
    public var permissions: ProjectPermissions

    enum CodingKeys: String, CodingKey { case key, name, color, statuses, types, permissions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        name = try c.decode(String.self, forKey: .name)
        color = c.value(.color, or: "#00735c")
        statuses = c.value(.statuses, or: [])
        types = c.value(.types, or: [])
        permissions = c.value(.permissions, or: ProjectPermissions())
    }

    /// Statuts dans l'ordre des colonnes du tableau.
    public var orderedStatuses: [StatusInfo] { statuses.sorted { $0.position < $1.position } }

    /// Types proposés à la création rapide : actifs, hors sous-tâches.
    public var creatableTypes: [TicketTypeInfo] { types.filter { $0.active && $0.level != "subtask" } }
}

// MARK: - Tickets

public struct ProjectRef: Decodable, Sendable, Equatable, Hashable {
    public var key: String
    public var name: String
}

public struct TicketCard: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var key: String
    public var title: String
    public var typeId: Int
    public var statusId: Int
    public var priority: String
    public var assignee: UserSummary?
    public var estimate: Double?
    public var dueDate: String?
    public var resolved: Bool
    public var version: Int

    public var id: String { key }

    enum CodingKeys: String, CodingKey { case key, title, typeId, statusId, priority, assignee, estimate, dueDate, resolved, version }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        title = try c.decode(String.self, forKey: .title)
        typeId = c.value(.typeId, or: 0)
        statusId = c.value(.statusId, or: 0)
        priority = c.value(.priority, or: "normal")
        assignee = c.optional(.assignee)
        estimate = c.optional(.estimate)
        dueDate = c.optional(.dueDate)
        resolved = c.value(.resolved, or: false)
        version = c.value(.version, or: 0)
    }
}

public struct MyTicket: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var key: String
    public var title: String
    public var priority: String
    public var dueDate: String?
    public var resolved: Bool
    public var project: ProjectRef
    public var statusName: String

    public var id: String { key }

    enum CodingKeys: String, CodingKey { case key, title, priority, dueDate, resolved, project, statusName }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        title = try c.decode(String.self, forKey: .title)
        priority = c.value(.priority, or: "normal")
        dueDate = c.optional(.dueDate)
        resolved = c.value(.resolved, or: false)
        project = try c.decode(ProjectRef.self, forKey: .project)
        statusName = c.value(.statusName, or: "")
    }
}

public struct TicketPage: Decodable, Sendable, Equatable {
    public var items: [TicketCard]
    public var total: Int

    enum CodingKeys: String, CodingKey { case items, total }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = c.value(.items, or: [])
        total = c.value(.total, or: items.count)
    }
}

public struct TicketPermissions: Decodable, Sendable, Equatable {
    public var edit: Bool
    public var delete: Bool
    public var comment: Bool

    public init(edit: Bool = false, delete: Bool = false, comment: Bool = false) {
        self.edit = edit
        self.delete = delete
        self.comment = comment
    }

    enum CodingKeys: String, CodingKey { case edit, delete, comment }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        edit = c.value(.edit, or: false)
        delete = c.value(.delete, or: false)
        comment = c.value(.comment, or: false)
    }
}

public struct TicketDetail: Decodable, Sendable, Equatable {
    public var key: String
    public var title: String
    public var typeId: Int
    public var statusId: Int
    public var priority: String
    public var assignee: UserSummary?
    public var reporter: UserSummary?
    public var dueDate: String?
    public var estimate: Double?
    public var description: String?
    public var project: ProjectRef
    public var children: [TicketCard]
    public var resolved: Bool
    public var version: Int
    public var createdAt: String?
    public var permissions: TicketPermissions

    enum CodingKeys: String, CodingKey {
        case key, title, typeId, statusId, priority, assignee, reporter, dueDate, estimate, description, project, children, resolved, version, createdAt, permissions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        title = try c.decode(String.self, forKey: .title)
        typeId = c.value(.typeId, or: 0)
        statusId = c.value(.statusId, or: 0)
        priority = c.value(.priority, or: "normal")
        assignee = c.optional(.assignee)
        reporter = c.optional(.reporter)
        dueDate = c.optional(.dueDate)
        estimate = c.optional(.estimate)
        description = c.optional(.description)
        project = try c.decode(ProjectRef.self, forKey: .project)
        children = c.value(.children, or: [])
        resolved = c.value(.resolved, or: false)
        version = c.value(.version, or: 0)
        createdAt = c.optional(.createdAt)
        permissions = c.value(.permissions, or: TicketPermissions())
    }
}

public struct ActivityItem: Decodable, Sendable, Equatable, Identifiable {
    /// comment ou change
    public var kind: String
    public var rawId: Int64
    public var author: UserSummary?
    public var automation: String?
    public var body: String?
    public var deleted: Bool
    public var field: String?
    public var fieldLabel: String?
    public var from: String?
    public var to: String?
    public var createdAt: String

    public var id: String { "\(kind)-\(rawId)" }

    enum CodingKeys: String, CodingKey { case kind, id, author, automation, body, deleted, field, fieldLabel, from, to, createdAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = c.value(.kind, or: "change")
        rawId = try c.decode(Int64.self, forKey: .id)
        author = c.optional(.author)
        automation = c.optional(.automation)
        body = c.optional(.body)
        deleted = c.value(.deleted, or: false)
        field = c.optional(.field)
        fieldLabel = c.optional(.fieldLabel)
        // Valeurs d'un changement : texte, nombre ou null selon le champ
        from = (c.optional(.from) as JSONValue?)?.text
        to = (c.optional(.to) as JSONValue?)?.text
        createdAt = c.value(.createdAt, or: "")
    }
}

public struct CommentRequest: Encodable, Sendable {
    public var body: String
}

public struct CreateTicketRequest: Encodable, Sendable {
    public var title: String
    public var typeId: Int?
    public var priority: String = "normal"
}

// MARK: - Notifications

public struct NotificationItem: Decodable, Sendable, Equatable, Identifiable {
    public var id: Int64
    public var type: String
    public var data: [String: JSONValue]
    public var actor: UserSummary?
    public var read: Bool
    public var createdAt: String

    enum CodingKeys: String, CodingKey { case id, type, data, actor, read, createdAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        type = c.value(.type, or: "")
        data = c.value(.data, or: [:])
        actor = c.optional(.actor)
        read = c.value(.read, or: false)
        createdAt = c.value(.createdAt, or: "")
    }

    /// Valeur texte d'une donnée de la notification (« key », « title », « project »…).
    public func value(_ name: String) -> String? { data[name]?.text }
}

public struct NotificationList: Decodable, Sendable, Equatable {
    public var items: [NotificationItem]
    public var unread: Int

    enum CodingKeys: String, CodingKey { case items, unread }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = c.value(.items, or: [])
        unread = c.value(.unread, or: 0)
    }
}

public struct UnreadCount: Decodable, Sendable {
    public var unread: Int

    enum CodingKeys: String, CodingKey { case unread }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unread = c.value(.unread, or: 0)
    }
}

/// Valeur JSON quelconque (données libres d'une notification, valeurs d'un changement).
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    /// Texte affichable : chaînes telles quelles, nombres sans « .0 » inutile.
    public var text: String? {
        switch self {
        case .string(let v): return v
        case .number(let v): return v.rounded() == v && abs(v) < 1e15 ? String(Int64(v)) : String(v)
        case .bool(let v): return v ? "true" : "false"
        default: return nil
        }
    }
}
