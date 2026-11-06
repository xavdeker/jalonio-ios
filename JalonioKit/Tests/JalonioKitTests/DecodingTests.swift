// SPDX-License-Identifier: EUPL-1.2

import XCTest
@testable import JalonioKit

/// Décodage de vraies réponses du backend de test (mêmes jeux d'essai que l'application
/// Android) : un champ renommé côté serveur casse ce test, pas l'application.
final class DecodingTests: XCTestCase {
    static func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"), "jeu d'essai \(name) introuvable")
        return try Data(contentsOf: url)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Self.fixture(name))
    }

    func testLoginAndMe() throws {
        let login = try decode(LoginResponse.self, "login")
        XCTAssertFalse(login.twoFactorRequired)
        XCTAssertEqual(login.user?.displayName, "Camille Martin")
        XCTAssertEqual(login.user?.organization.slug, "communaute-de-communes-du-val-fictif")

        let me = try decode(Me.self, "me")
        XCTAssertEqual(me.initials, "CM")
        XCTAssertEqual(me.locale, "fr")
        XCTAssertEqual(me.orgRole, "admin")
    }

    func testRefreshAndError() throws {
        let refresh = try decode(RefreshResponse.self, "refresh")
        XCTAssertEqual(refresh.tokens.accessToken, "jalm_exemple")
        XCTAssertEqual(refresh.tokens.expiresIn, 3600)

        let error = try decode(APIErrorBody.self, "error_refresh_replay")
        XCTAssertEqual(error.error, "invalid-refresh")
        XCTAssertNotNil(error.message)
    }

    func testProjectsAndTickets() throws {
        let projects = try decode([ProjectSummary].self, "projects")
        XCTAssertFalse(projects.isEmpty)
        XCTAssertTrue(projects.contains { $0.key == "PORTAIL" })

        let project = try decode(ProjectDetail.self, "projects_PORTAIL")
        XCTAssertEqual(project.key, "PORTAIL")
        XCTAssertFalse(project.statuses.isEmpty)
        XCTAssertEqual(project.orderedStatuses.map(\.position), project.statuses.map(\.position).sorted())
        XCTAssertTrue(project.creatableTypes.allSatisfy { $0.level != "subtask" })

        let page = try decode(TicketPage.self, "projects_PORTAIL_tickets_perPage_300")
        XCTAssertFalse(page.items.isEmpty)
        XCTAssertGreaterThanOrEqual(page.total, page.items.count)
        XCTAssertTrue(page.items.allSatisfy { $0.key.hasPrefix("PORTAIL-") })
    }

    func testTicketDetailAndActivity() throws {
        let ticket = try decode(TicketDetail.self, "tickets_PORTAIL-1")
        XCTAssertEqual(ticket.key, "PORTAIL-1")
        XCTAssertEqual(ticket.project.key, "PORTAIL")
        XCTAssertEqual(ticket.children.count, 8)
        XCTAssertTrue(ticket.permissions.comment)
        XCTAssertNil(ticket.description)

        let activity = try decode([ActivityItem].self, "activity_with_comments")
        XCTAssertEqual(activity.count, 4)
        XCTAssertEqual(activity.first?.kind, "comment")
        let change = try XCTUnwrap(activity.first { $0.kind == "change" && $0.to != nil })
        XCTAssertEqual(change.field, "sprint")
        XCTAssertEqual(change.to, "Sprint 2")
        XCTAssertEqual(Set(activity.map(\.id)).count, activity.count, "identifiants uniques entre commentaires et changements")
    }

    func testMyTicketsAndNotifications() throws {
        let mine = try decode([MyTicket].self, "my_tickets")
        XCTAssertEqual(mine.first?.project.key, "SDD")

        let notifications = try decode(NotificationList.self, "notifications_limit_50")
        XCTAssertEqual(notifications.unread, 3)
        let first = try XCTUnwrap(notifications.items.first)
        XCTAssertEqual(first.type, "import_done")
        XCTAssertEqual(first.message, .importDone(project: "Reprise Jira"))
        XCTAssertEqual(first.value("created"), "12")
    }
}
