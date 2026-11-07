// SPDX-License-Identifier: EUPL-1.2

import Foundation

/// Colonnes du tableau Kanban : une par statut, cartes dans l'ordre du serveur.
/// Le déplacement est appliqué tout de suite (affichage) et donne les voisins à envoyer
/// au serveur (`POST /tickets/{clé}/move`), comme le glisser-déposer du web.
public struct BoardColumns: Equatable, Sendable {
    public enum Position: Equatable, Sendable {
        case top
        case bottom
        /// Juste avant cette carte
        case before(String)
    }

    public struct Move: Equatable, Sendable {
        public let key: String
        public let statusId: Int
        public let afterKey: String?
        public let beforeKey: String?
    }

    public let statuses: [StatusInfo]
    private var cards: [Int: [TicketCard]]

    public init(statuses: [StatusInfo], tickets: [TicketCard]) {
        self.statuses = statuses.sorted { $0.position < $1.position }
        var cards = Dictionary(uniqueKeysWithValues: self.statuses.map { ($0.id, [TicketCard]()) })
        for ticket in tickets where cards[ticket.statusId] != nil {
            cards[ticket.statusId]?.append(ticket)
        }
        self.cards = cards
    }

    public func cards(in statusId: Int) -> [TicketCard] { cards[statusId] ?? [] }

    public func card(_ key: String) -> TicketCard? {
        cards.values.lazy.flatMap { $0 }.first { $0.key == key }
    }

    /// Déplace la carte ; `nil` si elle n'existe pas ou ne change pas de place.
    public mutating func move(_ key: String, to statusId: Int, at position: Position) -> Move? {
        guard var card = card(key), cards[statusId] != nil else { return nil }
        if case .before(let other) = position, other == key { return nil }
        let before = cards
        cards[card.statusId]?.removeAll { $0.key == key }
        card.statusId = statusId
        var column = cards[statusId] ?? []
        let index: Int
        switch position {
        case .top: index = 0
        case .bottom: index = column.count
        case .before(let other): index = column.firstIndex { $0.key == other } ?? column.count
        }
        column.insert(card, at: index)
        cards[statusId] = column
        guard cards != before else { return nil }
        return Move(
            key: key,
            statusId: statusId,
            afterKey: index > 0 ? column[index - 1].key : nil,
            beforeKey: index + 1 < column.count ? column[index + 1].key : nil
        )
    }
}
