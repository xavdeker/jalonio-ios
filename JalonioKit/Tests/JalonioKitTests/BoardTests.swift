// SPDX-License-Identifier: EUPL-1.2

import XCTest
@testable import JalonioKit

final class BoardTests: XCTestCase {
    private func board() throws -> (BoardData, ProjectDetail) {
        // Cartes du tableau : même format que la liste des tickets (TicketPresenter::card), plus epicKey
        let data = try JSONDecoder().decode(BoardData.self, from: DecodingTests.fixture("projects_PORTAIL_board"))
        let project = try JSONDecoder().decode(ProjectDetail.self, from: DecodingTests.fixture("projects_PORTAIL"))
        return (data, project)
    }

    func testDecodingAndColumns() throws {
        let (data, project) = try board()
        XCTAssertFalse(data.waitingForSprint)
        XCTAssertNil(data.sprint)
        let columns = BoardColumns(statuses: project.statuses, tickets: data.tickets)
        XCTAssertEqual(columns.statuses.map(\.name), ["À faire", "En cours", "En revue", "Terminé"])
        XCTAssertEqual(columns.statuses.map { columns.cards(in: $0.id).count }.reduce(0, +), data.tickets.count)
        // Ordre du serveur conservé dans chaque colonne
        let first = columns.statuses[0].id
        XCTAssertEqual(columns.cards(in: first).map(\.key), data.tickets.filter { $0.statusId == first }.map(\.key))
    }

    func testWaitingForSprint() throws {
        let json = #"{"sprint":null,"sprintsEnabled":true,"tickets":[],"epics":[]}"#
        XCTAssertTrue(try JSONDecoder().decode(BoardData.self, from: Data(json.utf8)).waitingForSprint)
    }

    func testMoveGivesNeighbours() throws {
        let (data, project) = try board()
        var columns = BoardColumns(statuses: project.statuses, tickets: data.tickets)
        let todo = columns.statuses[0].id, doing = columns.statuses[1].id
        let card = columns.cards(in: todo)[0].key
        let target = columns.cards(in: doing)

        // Haut de colonne : aucun voisin avant, l'ancienne première carte après
        let top = try XCTUnwrap(columns.move(card, to: doing, at: .top))
        XCTAssertEqual(top, .init(key: card, statusId: doing, afterKey: nil, beforeKey: target.first?.key))
        XCTAssertEqual(columns.cards(in: doing).first?.statusId, doing)
        XCTAssertFalse(columns.cards(in: todo).contains { $0.key == card })

        // Avant la deuxième carte : entre la première et la deuxième
        let second = target[1].key
        let middle = try XCTUnwrap(columns.move(card, to: doing, at: .before(second)))
        XCTAssertEqual(middle.afterKey, target[0].key)
        XCTAssertEqual(middle.beforeKey, second)

        // Bas de colonne
        let bottom = try XCTUnwrap(columns.move(card, to: doing, at: .bottom))
        XCTAssertEqual(bottom.afterKey, target.last?.key)
        XCTAssertNil(bottom.beforeKey)
    }

    func testMoveWithoutChange() throws {
        let (data, project) = try board()
        var columns = BoardColumns(statuses: project.statuses, tickets: data.tickets)
        let todo = columns.statuses[0].id
        let cards = columns.cards(in: todo)
        XCTAssertNil(columns.move(cards[0].key, to: todo, at: .top))
        XCTAssertNil(columns.move(cards[0].key, to: todo, at: .before(cards[1].key)))
        XCTAssertNil(columns.move(cards[0].key, to: todo, at: .before(cards[0].key)))
        XCTAssertNil(columns.move("INCONNU-1", to: todo, at: .top))
        XCTAssertNil(columns.move(cards[0].key, to: 999_999, at: .top))
        XCTAssertEqual(columns.cards(in: todo), cards)
    }

    func testMoveRequestBody() throws {
        let body = try JSONEncoder().encode(MoveRequest(statusId: 81, afterKey: "PORTAIL-2", beforeKey: nil))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["statusId"] as? Int, 81)
        XCTAssertEqual(json["afterKey"] as? String, "PORTAIL-2")
        XCTAssertNil(json["beforeKey"])
    }
}
