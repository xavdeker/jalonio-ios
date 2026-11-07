// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI
import UIKit

/// Projets → tickets du projet → fiche ticket. Trois colonnes sur iPad, une pile sur iPhone.
struct ProjectsView: View {
    @Environment(AppModel.self) private var model
    @State private var project: String?
    @State private var ticket: String?
    /// Sur iPad, les trois colonnes restent visibles (par défaut, iOS masque celle des projets)
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Loadable(load: { try await model.api.projects() }, id: model.revision) { projects, reload in
                // Favoris d'abord, puis par nom
                let visible = projects.filter { !$0.archived }.sorted { a, b in
                    a.favorite != b.favorite ? a.favorite : a.name < b.name
                }
                List(selection: $project) {
                    if visible.isEmpty {
                        EmptyState(title: L.tr("projects_empty_title"), text: L.tr("projects_empty_text"), systemImage: "folder")
                            .listRowBackground(Color.clear)
                    }
                    ForEach(visible) { item in
                        ProjectRow(project: item).tag(item.key).selectedRow(project == item.key)
                    }
                }
                .refreshable { await reload() }
            }
            .navigationTitle(L.tr("projects_title"))
        } content: {
            if let project {
                ProjectTicketsView(key: project, selection: $ticket).id(project)
            } else {
                EmptyState(title: L.tr("project_select"), text: L.tr("projects_empty_text"), systemImage: "folder")
            }
        } detail: {
            NavigationStack {
                if let ticket {
                    TicketView(key: ticket).id(ticket)
                        .ticketDestinations()
                } else {
                    EmptyState(title: L.tr("ticket_select"), text: L.tr("ticket_select_text"), systemImage: "doc.text")
                }
            }
        }
        // Colonnes côte à côte, sans voile sur le détail (en portrait, iOS les superpose sinon)
        .navigationSplitViewStyle(.balanced)
        .onChange(of: project) { _, _ in ticket = nil }
    }
}

struct ProjectRow: View {
    let project: ProjectSummary

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: project.color))
                .frame(width: 8, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(project.name).font(.body.weight(.medium))
                    if project.favorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Brand.warning)
                            .accessibilityLabel(L.tr("project_favorite"))
                    }
                }
                Text("\(project.key) · \(L.plural("projects_open_tickets", project.openTickets))")
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Tickets d'un projet, colonne par colonne (statuts du tableau), avec recherche et création rapide.
struct ProjectTicketsView: View {
    let key: String
    @Binding var selection: String?

    @Environment(AppModel.self) private var model
    @State private var status: Int?
    @State private var search = ""
    @State private var creating = false
    /// Projet dont le tableau est ouvert (plein écran, posé hors de la liste : jamais en
    /// concurrence avec la feuille de création)
    @State private var boardProject: ProjectDetail?

    private struct Snapshot {
        let project: ProjectDetail
        let tickets: [TicketCard]
    }

    var body: some View {
        Loadable(load: { () async throws -> Snapshot in
            let api = model.api, key = self.key
            async let project = api.project(key)
            async let page = api.tickets(project: key)
            return Snapshot(project: try await project, tickets: try await page.items)
        }, id: model.revision) { data, reload in
            let statuses = data.project.orderedStatuses
            let current = status ?? statuses.first?.id
            let query = search.trimmingCharacters(in: .whitespaces).lowercased()
            let tickets = data.tickets.filter { ticket in
                query.isEmpty ? ticket.statusId == current : (ticket.title.lowercased().contains(query) || ticket.key.lowercased().contains(query))
            }
            List(selection: $selection) {
                if query.isEmpty, !statuses.isEmpty {
                    Picker(L.tr("ticket_status"), selection: Binding(get: { current ?? 0 }, set: { status = $0 })) {
                        ForEach(statuses) { item in
                            Text("\(item.name) (\(data.tickets.filter { $0.statusId == item.id }.count))").tag(item.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if tickets.isEmpty {
                    EmptyState(title: L.tr("project_status_empty_title"), text: L.tr("project_status_empty_text"), systemImage: "tray")
                        .listRowBackground(Color.clear)
                }
                ForEach(tickets) { ticket in
                    TicketCardRow(ticket: ticket, project: data.project).tag(ticket.key).selectedRow(selection == ticket.key)
                }
            }
            .searchable(text: $search, prompt: L.tr("ticket_search"))
            .refreshable { await reload() }
            .navigationTitle(data.project.name)
            .toolbar {
                // Tableau Kanban sur iPad, en plein écran pour voir les colonnes. Type d'appareil et
                // non largeur : dans une colonne de NavigationSplitView, iOS annonce une largeur « compacte ».
                if UIDevice.current.userInterfaceIdiom == .pad {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            boardProject = data.project
                        } label: {
                            Label(L.tr("board_open"), systemImage: "rectangle.split.3x1")
                        }
                        .accessibilityIdentifier("board.open")
                    }
                }
                if data.project.permissions.contribute || data.project.permissions.manage {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            creating = true
                        } label: {
                            Label(L.tr("ticket_create"), systemImage: "plus")
                        }
                        .accessibilityIdentifier("ticket.create")
                    }
                }
            }
            .sheet(isPresented: $creating) {
                CreateTicketView(project: data.project) { created in
                    model.changed()
                    selection = created.key
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { boardProject != nil }, set: { if !$0 { boardProject = nil } })) {
            if let boardProject {
                BoardView(project: boardProject)
            }
        }
    }
}

struct TicketCardRow: View {
    let ticket: TicketCard
    let project: ProjectDetail

    var body: some View {
        let type = project.types.first { $0.id == ticket.typeId }
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.title)
                .font(.body.weight(.medium))
                .strikethrough(ticket.resolved)
            HStack(spacing: 8) {
                // Clé jamais coupée (cartes étroites du tableau) : c'est le nom de la personne qui se tronque
                Text(ticket.key).font(.caption.monospaced()).fixedSize()
                if let type {
                    TypeLabel(type: type)
                }
                Spacer(minLength: 0)
                if let assignee = ticket.assignee {
                    Avatar(initials: assignee.initials, size: 22)
                    Text(assignee.displayName).lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(Brand.muted)
            HStack(spacing: 12) {
                PriorityLabel(priority: ticket.priority)
                DueLabel(dueDate: ticket.dueDate, resolved: ticket.resolved)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Création rapide : titre et type ; le reste se complète ensuite (web ou fiche).
struct CreateTicketView: View {
    let project: ProjectDetail
    let onCreated: (TicketDetail) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var typeId: Int?
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Brand.danger)
                }
                Text(L.tr("ticket_create_title", project.name))
                    .font(.subheadline)
                    .foregroundStyle(Brand.muted)
                TextField(L.tr("ticket_title"), text: $title, axis: .vertical)
                    .focused($focused)
                    .accessibilityIdentifier("ticket.create.title")
                if !project.creatableTypes.isEmpty {
                    // Liste plutôt que menu : les noms longs reviennent à la ligne. En-tête à part :
                    // iOS impose son gris (trop pâle) au libellé d'un sélecteur en liste.
                    Section(muted: L.tr("ticket_type")) {
                        Picker(L.tr("ticket_type"), selection: Binding(get: { typeId ?? project.creatableTypes[0].id }, set: { typeId = $0 })) {
                            ForEach(project.creatableTypes) { type in Text(type.name).tag(type.id) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            // Titre court (barre de navigation) ; le projet est rappelé dans le formulaire
            .navigationTitle(L.tr("ticket_create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.tr("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.tr("ticket_create_submit")) { Task { await create() } }
                        .disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("ticket.create.submit")
                }
            }
            .disabled(busy)
            .onAppear { focused = true }
        }
    }

    private func create() async {
        busy = true
        defer { busy = false }
        do {
            let ticket = try await model.api.createTicket(project: project.key, title: title, typeId: typeId ?? project.creatableTypes.first?.id)
            dismiss()
            onCreated(ticket)
        } catch {
            self.error = L.message(for: error)
        }
    }
}
