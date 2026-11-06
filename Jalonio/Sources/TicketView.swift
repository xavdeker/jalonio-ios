// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI
import UIKit

/// Fiche ticket : statut, « M'assigner », champs, description, sous-tâches, activité,
/// commentaire. Les autres modifications se font dans l'application web.
struct TicketView: View {
    let key: String

    @Environment(AppModel.self) private var model
    @State private var ticket: TicketDetail?
    @State private var project: ProjectDetail?
    @State private var activity: [ActivityItem] = []
    @State private var loadError: String?
    @State private var actionError: String?
    @State private var busy = false
    @State private var comment = ""
    @State private var announcement: String?
    @FocusState private var commentFocused: Bool

    var body: some View {
        Group {
            if let ticket {
                content(ticket)
            } else if let loadError {
                ErrorState(message: loadError) { Task { await load() } }
            } else {
                ProgressView(L.tr("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(key)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func content(_ ticket: TicketDetail) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ticket.project.name).font(.subheadline).foregroundStyle(Brand.muted)
                    Text(ticket.title)
                        .font(.title2.weight(.semibold))
                        .strikethrough(ticket.resolved)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.vertical, 4)
                if let actionError {
                    Label(actionError, systemImage: "exclamationmark.circle").foregroundStyle(Brand.danger)
                }
            }

            Section {
                statusRow(ticket)
                assigneeRow(ticket)
                if let type = project?.types.first(where: { $0.id == ticket.typeId }) {
                    LabeledContent(L.tr("ticket_type")) { TypeLabel(type: type) }
                }
                LabeledContent(L.tr("ticket_priority")) { PriorityLabel(priority: ticket.priority) }
                if ticket.dueDate != nil {
                    LabeledContent(L.tr("ticket_due")) { DueLabel(dueDate: ticket.dueDate, resolved: ticket.resolved) }
                }
                if let reporter = ticket.reporter {
                    LabeledContent(L.tr("ticket_reporter"), value: reporter.displayName)
                }
            }

            Section(muted: L.tr("ticket_description")) {
                if let description = ticket.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(markdown(description)).textSelection(.enabled)
                } else {
                    Text(L.tr("ticket_no_description")).foregroundStyle(Brand.muted)
                }
            }

            if !ticket.children.isEmpty {
                Section(muted: L.tr("ticket_subtasks")) {
                    ForEach(ticket.children) { child in
                        NavigationLink(value: child.key) {
                            HStack {
                                Image(systemName: child.resolved ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(child.resolved ? Brand.green : Brand.muted)
                                    .accessibilityLabel(child.resolved ? L.tr("ticket_resolved") : "")
                                VStack(alignment: .leading) {
                                    Text(child.title).strikethrough(child.resolved)
                                    Text(child.key).font(.caption.monospaced()).foregroundStyle(Brand.muted)
                                }
                            }
                        }
                    }
                }
            }

            Section(muted: L.tr("ticket_activity")) {
                if ticket.permissions.comment {
                    commentComposer(ticket)
                }
                ForEach(activity.reversed()) { item in
                    ActivityRow(item: item)
                }
            }
        }
        .refreshable { await load() }
        .disabled(busy)
        .onChange(of: announcement) { _, text in
            if let text { UIAccessibility.post(notification: .announcement, argument: text) }
        }
    }

    @ViewBuilder
    private func statusRow(_ ticket: TicketDetail) -> some View {
        let statuses = project?.orderedStatuses ?? []
        let current = statuses.first { $0.id == ticket.statusId }
        if ticket.permissions.edit, !statuses.isEmpty {
            Picker(L.tr("ticket_status"), selection: Binding(get: { ticket.statusId }, set: { id in Task { await setStatus(id) } })) {
                ForEach(statuses) { status in Text(status.name).tag(status.id) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("ticket.status")
        } else {
            LabeledContent(L.tr("ticket_status"), value: current?.name ?? "—")
        }
    }

    @ViewBuilder
    private func assigneeRow(_ ticket: TicketDetail) -> some View {
        LabeledContent(L.tr("ticket_assignee")) {
            if let assignee = ticket.assignee {
                HStack(spacing: 6) {
                    Avatar(initials: assignee.initials, size: 22)
                    Text(assignee.displayName)
                }
            } else {
                Text(L.tr("ticket_unassigned")).foregroundStyle(Brand.muted)
            }
        }
        if ticket.permissions.edit, let me = model.me, ticket.assignee?.id != me.id {
            Button {
                Task { await assignMe(me.id) }
            } label: {
                Label {
                    Text(L.tr("ticket_assign_me")).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "person.badge.plus")
                }
            }
            .accessibilityIdentifier("ticket.assignMe")
        }
    }

    private func commentComposer(_ ticket: TicketDetail) -> some View {
        HStack(alignment: .bottom) {
            TextField(L.tr("ticket_comment_placeholder"), text: $comment, axis: .vertical)
                .lineLimit(1...6)
                .focused($commentFocused)
                .accessibilityIdentifier("ticket.comment")
            Button {
                Task { await sendComment() }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderless)
            .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(L.tr("ticket_comment_send"))
        }
    }

    // MARK: Actions

    private func load() async {
        do {
            let detail = try await model.api.ticket(key)
            ticket = detail
            loadError = nil
            let api = model.api, key = self.key
            async let projectDetail = api.project(detail.project.key)
            async let items = api.activity(key)
            project = try? await projectDetail
            activity = (try? await items) ?? activity
        } catch is CancellationError {
        } catch {
            if ticket == nil { loadError = L.message(for: error) } else { actionError = L.message(for: error) }
        }
    }

    private func setStatus(_ statusId: Int) async {
        guard let ticket, ticket.statusId != statusId else { return }
        await act {
            self.ticket = try await model.api.setStatus(ticket, statusId: statusId)
            if let name = project?.statuses.first(where: { $0.id == statusId })?.name {
                announcement = L.tr("ticket_status_changed", name)
            }
        }
    }

    private func assignMe(_ userId: String) async {
        guard let ticket else { return }
        await act { self.ticket = try await model.api.assign(ticket, userId: userId) }
    }

    private func sendComment() async {
        let body = comment
        await act {
            try await model.api.comment(key, body: body)
            comment = ""
            commentFocused = false
            announcement = L.tr("ticket_comment_sent")
        }
    }

    /// Modification : erreur affichée sur la fiche (conflit de version compris), puis relecture.
    private func act(_ change: () async throws -> Void) async {
        busy = true
        actionError = nil
        announcement = nil
        defer { busy = false }
        do {
            try await change()
            model.changed()
        } catch {
            actionError = L.message(for: error)
        }
        await load()
    }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(initials: item.author?.initials ?? "J", size: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(authorName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let when = L.relative(item.createdAt) {
                        Text(when).font(.caption).foregroundStyle(Brand.muted)
                    }
                }
                if item.kind == "comment" {
                    if item.deleted {
                        Text(L.tr("ticket_comment_deleted")).italic().foregroundStyle(Brand.muted)
                    } else {
                        Text(item.body ?? "").textSelection(.enabled)
                    }
                } else {
                    Text(L.tr("ticket_change", item.fieldLabel ?? item.field ?? "", item.from ?? "—", item.to ?? "—"))
                        .font(.callout)
                        .foregroundStyle(Brand.muted)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// Auteur, « Jalonio » pour une automatisation, sinon « Quelqu'un ».
    private var authorName: String {
        if let name = item.author?.displayName { return name }
        return item.automation != nil ? "Jalonio" : L.tr("someone")
    }
}

extension View {
    /// Liens vers un ticket (sous-tâche, notification) : à poser une fois par pile de navigation.
    func ticketDestinations() -> some View {
        navigationDestination(for: String.self) { TicketView(key: $0).id($0) }
    }
}
