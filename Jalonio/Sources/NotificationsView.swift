// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI

/// Notifications de l'application web (pas de notifications poussées : ADR-0031).
struct NotificationsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Loadable(load: { try await model.api.notifications() }, id: model.revision) { list, reload in
                List {
                    if list.items.isEmpty {
                        EmptyState(title: L.tr("notifications_empty_title"), text: L.tr("notifications_empty_text"), systemImage: "bell.slash")
                            .listRowBackground(Color.clear)
                    }
                    ForEach(list.items) { item in
                        if let key = item.ticketKey {
                            NavigationLink(value: key) { NotificationRow(item: item) }
                        } else {
                            NotificationRow(item: item)
                        }
                    }
                }
                .refreshable {
                    await reload()
                    await model.refreshUnread()
                }
                .toolbar {
                    if list.unread > 0 {
                        ToolbarItem(placement: .primaryAction) {
                            Button(L.tr("notifications_mark_all")) {
                                Task {
                                    _ = try? await model.api.markAllRead()
                                    model.unread = 0
                                    await reload()
                                }
                            }
                        }
                    }
                }
                .onAppear { model.unread = list.unread }
            }
            .navigationTitle(L.tr("notifications_title"))
            .ticketDestinations()
        }
    }
}

struct NotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(item.read ? Color.clear : Brand.green)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(item.read ? .body : .body.weight(.semibold))
                if let when = L.relative(item.createdAt) {
                    Text(when).font(.caption).foregroundStyle(Brand.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.read ? "" : L.tr("notifications_unread"))
    }

    /// Texte rédigé dans l'application : les types du serveur ne s'affichent jamais tels quels.
    private var text: String {
        let someone = L.tr("someone")
        switch item.message {
        case let .assigned(actor, key, title): return L.tr("notif_assigned", actor ?? someone, key, title)
        case let .mentioned(actor, key, title): return L.tr("notif_mentioned", actor ?? someone, key, title)
        case let .mentionedInNote(actor, note, project): return L.tr("notif_mentioned_note", actor ?? someone, note, project)
        case let .commented(actor, key, title): return L.tr("notif_commented", actor ?? someone, key, title)
        case let .statusChanged(actor, key, status): return L.tr("notif_status_changed", actor ?? someone, key, status)
        case let .dueSoon(key, title): return L.tr("notif_due_soon", key, title)
        case let .overdue(key, title): return L.tr("notif_overdue", key, title)
        case let .sprintStarted(sprint, project): return L.tr("notif_sprint_started", sprint, project)
        case let .sprintClosed(sprint, project): return L.tr("notif_sprint_closed", sprint, project)
        case let .importDone(project): return L.tr("notif_import_done", project)
        case let .addedToProject(actor, project): return L.tr("notif_added_to_project", actor ?? someone, project)
        case let .other(summary): return summary ?? L.tr("notif_other")
        }
    }
}
