// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI
import UIKit

/// Tableau Kanban du projet (iPad, plein écran) : une colonne par statut, les mêmes cartes et
/// le même ordre que le tableau du web. Une carte se déplace en la faisant glisser, ou par
/// « Déplacer vers… » (appui long, menu contextuel au pointeur, actions de VoiceOver).
struct BoardView: View {
    let project: ProjectDetail

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var data: BoardData?
    @State private var columns: BoardColumns?
    @State private var loadError: String?
    @State private var moveError: String?
    @State private var target: Int?
    @State private var path: [String] = []
    /// Largeur des colonnes : suit la taille de texte choisie
    @ScaledMetric private var columnWidth: CGFloat = 300

    private var canMove: Bool { project.permissions.contribute || project.permissions.manage }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let data, let columns {
                    if data.waitingForSprint {
                        ContentUnavailableView {
                            Label(L.tr("board_no_sprint_title"), systemImage: "flag")
                        } description: {
                            Text(L.tr("board_no_sprint_text")).foregroundStyle(Brand.muted)
                        }
                    } else {
                        board(data, columns)
                    }
                } else if let loadError {
                    ErrorState(message: loadError) { Task { await load() } }
                } else {
                    ProgressView(L.tr("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.tr("close")) { dismiss() }
                        .accessibilityIdentifier("board.close")
                }
            }
            .ticketDestinations()
        }
        // Relu à l'ouverture et après chaque modification (déplacement, fiche ticket)
        .task(id: model.revision) { await load() }
    }

    private func board(_ data: BoardData, _ columns: BoardColumns) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sprint = data.sprint {
                Text(L.tr("board_sprint_until", sprint.name, L.day(sprint.endDate) ?? "—"))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)
            }
            if let moveError {
                Label(moveError, systemImage: "exclamationmark.circle")
                    .foregroundStyle(Brand.danger)
                    .padding(.horizontal)
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(columns.statuses) { status in
                        column(status, cards: columns.cards(in: status.id), all: columns.statuses)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .padding(.top, 8)
    }

    private func column(_ status: StatusInfo, cards: [TicketCard], all statuses: [StatusInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: status.color)).frame(width: 10, height: 10).accessibilityHidden(true)
                Text(status.name).font(.headline)
                Text("\(cards.count)").font(.subheadline).foregroundStyle(Brand.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ScrollView(.vertical) {
                LazyVStack(spacing: 8) {
                    if cards.isEmpty {
                        Text(L.tr("board_column_empty"))
                            .foregroundStyle(Brand.muted)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    }
                    ForEach(cards) { card in
                        cardView(card, in: status, statuses: statuses)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(10)
        .frame(width: columnWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            // Colonne visée pendant le glisser-déposer
            RoundedRectangle(cornerRadius: 12).strokeBorder(target == status.id ? Brand.green : .clear, lineWidth: 2)
        }
        // Lâchée sur la colonne (hors d'une carte) : en bas
        .dropDestination(for: String.self) { keys, _ in
            drop(keys.first, to: status.id, at: .bottom)
        } isTargeted: { over in
            if over { target = status.id } else if target == status.id { target = nil }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(status.name)
    }

    private func cardView(_ card: TicketCard, in status: StatusInfo, statuses: [StatusInfo]) -> some View {
        NavigationLink(value: card.key) {
            TicketCardRow(ticket: card, project: project)
                .foregroundStyle(.primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(.separator)))
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board.card.\(card.key)")
        .movable(card.key, enabled: canMove)
        // Lâchée sur une carte : juste avant elle
        .dropDestination(for: String.self) { keys, _ in
            drop(keys.first, to: status.id, at: .before(card.key))
        }
        .contextMenu {
            if canMove {
                Section(L.tr("board_move_to")) {
                    ForEach(statuses.filter { $0.id != status.id }) { other in
                        Button(other.name) { move(card.key, to: other.id, at: .top) }
                    }
                    Button(L.tr("board_move_top")) { move(card.key, to: status.id, at: .top) }
                    Button(L.tr("board_move_bottom")) { move(card.key, to: status.id, at: .bottom) }
                }
            }
        }
        .accessibilityActions {
            if canMove {
                ForEach(statuses.filter { $0.id != status.id }) { other in
                    Button(L.tr("board_move_to_status", other.name)) { move(card.key, to: other.id, at: .top) }
                }
            }
        }
    }

    // MARK: Actions

    private func load() async {
        do {
            let board = try await model.api.board(project: project.key)
            data = board
            columns = BoardColumns(statuses: project.statuses, tickets: board.tickets)
            loadError = nil
        } catch is CancellationError {
        } catch {
            if data == nil { loadError = L.message(for: error) } else { moveError = L.message(for: error) }
        }
    }

    private func drop(_ key: String?, to statusId: Int, at position: BoardColumns.Position) -> Bool {
        target = nil
        guard let key, canMove, columns?.card(key) != nil else { return false }
        move(key, to: statusId, at: position)
        return true
    }

    /// Déplacement affiché tout de suite, puis envoyé ; en cas de refus, la carte revient
    /// à sa place et le message du serveur s'affiche.
    private func move(_ key: String, to statusId: Int, at position: BoardColumns.Position) {
        guard let previous = columns else { return }
        var updated = previous
        guard let change = updated.move(key, to: statusId, at: position) else { return }
        withAnimation(.snappy) { columns = updated }
        moveError = nil
        Task {
            do {
                _ = try await model.api.move(change.key, statusId: change.statusId, after: change.afterKey, before: change.beforeKey)
                if let name = previous.statuses.first(where: { $0.id == statusId })?.name {
                    UIAccessibility.post(notification: .announcement, argument: L.tr("board_moved", key, name))
                }
                model.changed()
            } catch {
                withAnimation(.snappy) { columns = previous }
                moveError = L.message(for: error)
            }
        }
    }
}

private extension View {
    /// Carte qu'on peut faire glisser (seulement si l'on peut modifier le projet).
    @ViewBuilder
    func movable(_ key: String, enabled: Bool) -> some View {
        if enabled {
            draggable(key)
        } else {
            self
        }
    }
}
