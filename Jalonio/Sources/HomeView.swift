// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI

/// Accueil « Mes tickets » : tickets assignés, ouverts d'abord, par échéance.
/// iPad : la fiche s'ouvre à droite ; iPhone : par-dessus la liste.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            Loadable(load: { try await model.api.myTickets().sortedForHome() }, id: model.revision) { tickets, reload in
                List(selection: $selection) {
                    Section {
                        if tickets.isEmpty {
                            EmptyState(title: L.tr("home_empty_title"), text: L.tr("home_empty_text"), systemImage: "checkmark.circle")
                                .listRowBackground(Color.clear)
                        }
                        ForEach(tickets) { ticket in
                            MyTicketRow(ticket: ticket).tag(ticket.key)
                        }
                    } header: {
                        if let me = model.me { Text(L.tr("home_hello", me.displayName)).textCase(nil) }
                    }
                }
                .refreshable { await reload() }
            }
            .navigationTitle(L.tr("home_my_tickets"))
        } detail: {
            NavigationStack {
                if let selection {
                    TicketView(key: selection).id(selection)
                        .ticketDestinations()
                } else {
                    EmptyState(title: L.tr("ticket_select"), text: L.tr("ticket_select_text"), systemImage: "doc.text")
                }
            }
        }
    }
}

struct MyTicketRow: View {
    let ticket: MyTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.title)
                .font(.body.weight(.medium))
                .strikethrough(ticket.resolved)
            // Un seul texte : il revient à la ligne au lieu d'être tronqué (grandes tailles de texte)
            Text("\(Text(ticket.key).monospaced()) · \(ticket.statusName) · \(ticket.project.name)")
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                PriorityLabel(priority: ticket.priority)
                DueLabel(dueDate: ticket.dueDate, resolved: ticket.resolved)
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
