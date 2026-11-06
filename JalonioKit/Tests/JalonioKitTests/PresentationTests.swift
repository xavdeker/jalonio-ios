// SPDX-License-Identifier: EUPL-1.2

import XCTest
@testable import JalonioKit

final class PresentationTests: XCTestCase {
    private func notification(_ type: String, _ data: String, actor: String? = nil) throws -> NotificationItem {
        let actorJSON = actor.map { #"{"id":"u1","displayName":"\#($0)","initials":"X"}"# } ?? "null"
        let json = #"{"id":1,"type":"\#(type)","data":\#(data),"actor":\#(actorJSON),"read":false,"createdAt":"2026-11-05T10:00:00+00:00"}"#
        return try JSONDecoder().decode(NotificationItem.self, from: Data(json.utf8))
    }

    func testNotificationMessages() throws {
        XCTAssertEqual(try notification("assigned", #"{"key":"TP2-12","title":"Formulaire"}"#, actor: "Olivia").message, .assigned(actor: "Olivia", key: "TP2-12", title: "Formulaire"))
        XCTAssertEqual(try notification("mentioned", #"{"note":"n1","title":"Compte rendu","project":"Portail"}"#, actor: "Karim").message, .mentionedInNote(actor: "Karim", note: "Compte rendu", project: "Portail"))
        XCTAssertEqual(try notification("sprint", #"{"sprint":"Sprint 3","event":"closed","project":"Portail"}"#).message, .sprintClosed(sprint: "Sprint 3", project: "Portail"))
        XCTAssertEqual(try notification("status_changed", #"{"key":"TP2-1","status":"Terminé"}"#).message, .statusChanged(actor: nil, key: "TP2-1", status: "Terminé"))
        XCTAssertEqual(try notification("nouveau_type", #"{"key":"TP2-4","title":"Titre"}"#).message, .other(summary: "TP2-4 · Titre"))
        XCTAssertEqual(try notification("nouveau_type", "{}").message, .other(summary: nil))
    }

    func testNotificationOpensTicketButNotNote() throws {
        XCTAssertEqual(try notification("commented", #"{"key":"TP2-12","title":"x"}"#).ticketKey, "TP2-12")
        XCTAssertNil(try notification("mentioned", #"{"key":"TP2-12","note":"n1"}"#).ticketKey)
        XCTAssertNil(try notification("import_done", #"{"project":"Orbite"}"#).ticketKey)
    }

    func testHomeOrderOpenFirstThenByDueDate() throws {
        func ticket(_ key: String, due: String?, resolved: Bool = false) throws -> MyTicket {
            let dueJSON = due.map { "\"\($0)\"" } ?? "null"
            let json = #"{"key":"\#(key)","title":"t","dueDate":\#(dueJSON),"resolved":\#(resolved),"project":{"key":"P","name":"P"}}"#
            return try JSONDecoder().decode(MyTicket.self, from: Data(json.utf8))
        }
        let sorted = try [
            ticket("P-10", due: nil),
            ticket("P-2", due: nil),
            ticket("P-3", due: "2026-12-01"),
            ticket("P-4", due: "2026-11-10", resolved: true),
            ticket("P-5", due: "2026-11-20"),
        ].sortedForHome()
        XCTAssertEqual(sorted.map(\.key), ["P-5", "P-3", "P-2", "P-10", "P-4"])
    }

    func testDates() throws {
        let day = try XCTUnwrap(JalonioDates.day("2026-10-28"))
        XCTAssertEqual(Calendar.current.component(.day, from: day), 28)
        XCTAssertNotNil(JalonioDates.instant("2026-10-21T00:36:34+00:00"))
        XCTAssertNotNil(JalonioDates.instant("2026-10-21T00:36:34.123+00:00"))
        let now = try XCTUnwrap(JalonioDates.day("2026-11-06"))
        XCTAssertTrue(JalonioDates.isOverdue("2026-11-05", now: now))
        XCTAssertFalse(JalonioDates.isOverdue("2026-11-06", now: now))
        XCTAssertFalse(JalonioDates.isOverdue(nil, now: now))
    }
}
