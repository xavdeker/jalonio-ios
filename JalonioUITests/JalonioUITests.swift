// SPDX-License-Identifier: EUPL-1.2

import UIKit
import XCTest

/// Parcours de l'application sur iPhone et sur iPad, en français, avec le faux serveur
/// (`-ui-demo`) : connexion, accueil, projet, fiche ticket, notifications, compte.
/// Chaque écran passe l'audit d'accessibilité d'Xcode et laisse une capture.
final class JalonioUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(isPad ? "ipad" : "iphone")-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Défauts d'accessibilité relevés pendant le parcours, signalés ensemble à la fin
    /// (un seul passage de CI suffit à les voir tous).
    private var issues: [String] = []

    override func tearDown() {
        if !issues.isEmpty {
            XCTFail("Audit d'accessibilité (\(issues.count)) :\n" + issues.joined(separator: "\n"))
        }
        super.tearDown()
    }

    /// Audit d'accessibilité d'Xcode (contraste, taille des cibles, textes, Dynamic Type).
    private func audit(_ screen: String) throws {
        try app.performAccessibilityAudit { issue in
            // Textes tronqués par le système dans la barre d'onglets en très grande taille : hors de notre main
            if issue.auditType == .textClipped, issue.element?.elementType == .tabBar { return true }
            let element = issue.element.map { "\($0.elementType.rawValue) « \($0.label) » [\($0.identifier)]" } ?? "?"
            let line = "\(isPad ? "iPad" : "iPhone") · \(screen) : \(issue.compactDescription) — \(element) — \(issue.detailedDescription)"
            issues.append(line)
            print("AUDIT " + line)
            return true
        }
    }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testLoginValidatesWorkspaceAddress() throws {
        app.launchArguments.append("-ui-testing")
        app.launch()

        let workspace = app.textFields["login.workspace"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 10))
        XCTAssertTrue(element(containing: "jalonio.fr").exists, "aide sur le nom de l'espace")
        try audit("connexion")
        capture("1-connexion")

        workspace.tap()
        workspace.typeText("mon espace")
        XCTAssertTrue(element(containing: "Adresse invalide").waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["login.submit"].isEnabled)

        workspace.clearText()
        workspace.typeText("mairie-x")
        XCTAssertTrue(element(containing: "mairie-x.jalonio.fr").waitForExistence(timeout: 2))
    }

    func testTourOfTheApp() throws {
        app.launchArguments.append("-ui-demo")
        app.launch()

        // Connexion
        let workspace = app.textFields["login.workspace"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 10))
        workspace.tap()
        workspace.typeText("val-fictif")
        app.textFields["login.email"].tap()
        app.textFields["login.email"].typeText("admin@val-fictif.fr")
        app.secureTextFields["login.password"].tap()
        app.secureTextFields["login.password"].typeText("demo")
        app.buttons["login.submit"].tap()

        // Accueil : mes tickets
        let myTicket = element(containing: "Nouveau poste pour l")
        XCTAssertTrue(myTicket.waitForExistence(timeout: 10))
        XCTAssertTrue(element(containing: "Camille Martin").exists, "salutation")
        try audit("accueil")
        capture("2-accueil")

        // Fiche ticket depuis l'accueil
        myTicket.tap()
        XCTAssertTrue(element(containing: "Prise de rendez-vous en ligne").waitForExistence(timeout: 10) || app.staticTexts["PORTAIL-1"].exists)
        XCTAssertTrue(app.buttons["ticket.assignMe"].waitForExistence(timeout: 5) || app.staticTexts["Camille Martin"].exists)
        try audit("fiche ticket")
        capture("3-ticket")

        // Projets → PORTAIL → tickets
        app.buttons["Projets"].firstMatch.tap()
        let portail = element(containing: "PORTAIL ·")
        XCTAssertTrue(portail.waitForExistence(timeout: 10))
        portail.tap()
        XCTAssertTrue(app.buttons["ticket.create"].waitForExistence(timeout: 10))
        try audit("projet")
        capture("4-projet")

        // Création rapide
        app.buttons["ticket.create"].tap()
        // Champ sur plusieurs lignes (axis: .vertical) : vue de texte, pas champ de texte
        let title = app.descendants(matching: .any).matching(identifier: "ticket.create.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Vérifier l’accès PMR du guichet")
        try audit("nouveau ticket")
        capture("5-nouveau-ticket")
        app.buttons["ticket.create.submit"].tap()
        XCTAssertTrue(title.waitUntilGone(timeout: 5))

        // Notifications
        app.buttons["Alertes"].firstMatch.tap()
        XCTAssertTrue(element(containing: "Reprise Jira").waitForExistence(timeout: 10))
        try audit("notifications")
        capture("6-alertes")

        // Compte et déconnexion
        app.buttons["Compte"].firstMatch.tap()
        let logout = app.buttons["account.logout"]
        XCTAssertTrue(logout.waitForExistence(timeout: 10))
        try audit("compte")
        capture("7-compte")
        logout.tap()
        // Bouton de confirmation (feuille d'actions sur iPhone, bulle sur iPad)
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Se déconnecter", "account.logout")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.textFields["login.workspace"].waitForExistence(timeout: 10))
    }
}

private extension XCUIElement {
    func clearText() {
        guard let value = value as? String, !value.isEmpty else { return }
        // Curseur en fin de texte : toucher le bord droit du champ
        coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
    }

    /// (Nom distinct de `waitForNonExistence(timeout:)` d'Xcode 16 : pas d'ambiguïté.)
    func waitUntilGone(timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
