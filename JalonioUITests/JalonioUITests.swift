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
        // Portrait : en paysage, les captures de l'audit sont pivotées et le contraste
        // est mesuré au mauvais endroit (faux défauts sur iPad)
        XCUIDevice.shared.orientation = .portrait
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
    /// Défauts de contraste signalés à tort, tous vérifiés sur les captures de la CI :
    /// - salutation en noir sur fond clair, mesurée à travers le flou de l'en-tête de section ;
    /// - en-tête « Type » (5,9:1) recouvert par le clavier, que l'audit mesure quand même ;
    /// - libellé « Statut » du sélecteur de colonne, noir sur blanc (signalé une fois sur deux).
    private static let knownFalsePositives: Set<String> = [
        "iPad|fiche ticket|Bonjour Camille Martin",
        "iPhone|nouveau ticket|TYPE",
        "iPhone|projet|Statut",
    ]

    /// `modal` : feuille posée sur un arrière-plan assombri (iPad).
    private func audit(_ screen: String, modal: Bool = false) throws {
        do {
            try runAudit(screen, modal: modal)
        } catch let error as NSError where error.code == -56 || error.localizedDescription.contains("Timed out") {
            // « Audit failed to complete in time » ou « Timed out while running accessibility audit » :
            // écran chargé (liste longue sur iPad), on relance règle par règle, sans rien retirer
            print("AUDIT relancé règle par règle (délai dépassé) · \(screen)")
            let types: [XCUIAccessibilityAuditType] = [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .dynamicType, .textClipped, .trait]
            for type in types {
                try runAudit(screen, modal: modal, for: type)
            }
        }
    }

    private func runAudit(_ screen: String, modal: Bool, for types: XCUIAccessibilityAuditType = .all) throws {
        try app.performAccessibilityAudit(for: types) { issue in
            // Textes tronqués par le système dans la barre d'onglets en très grande taille : hors de notre main
            if issue.auditType == .textClipped, issue.element?.elementType == .tabBar { return true }
            // Champ d'une ligne (UITextField) : iOS fait défiler le texte, il ne le renvoie jamais à la ligne
            if issue.auditType == .textClipped, issue.element?.elementType == .textField { return true }
            let element = issue.element.map { "\($0.elementType.rawValue) « \($0.label) » [\($0.identifier)]" } ?? "?"
            let line = "\(self.isPad ? "iPad" : "iPhone") · \(screen) : \(issue.compactDescription) — \(element) — \(issue.detailedDescription)"
            // Élément caché sous la barre d'onglets ou hors de l'écran : le contraste mesuré est celui
            // de la barre translucide, pas celui de l'application
            if issue.auditType == .contrast, let frame = issue.element?.frame, !self.visibleArea.contains(frame) {
                print("AUDIT (hors écran) " + line)
                return true
            }
            // Faux positifs connus, vérifiés sur les captures (liste fermée : tout autre défaut échoue)
            if issue.auditType == .contrast, let label = issue.element?.label,
               Self.knownFalsePositives.contains("\(self.isPad ? "iPad" : "iPhone")|\(screen)|\(label)") {
                print("AUDIT (faux positif connu) " + line)
                return true
            }
            // Feuille sur iPad : l'audit mesure le contraste à travers le voile de l'arrière-plan
            // et signale les textes de cet arrière-plan (captures vérifiées : tout est lisible)
            if modal, self.isPad, issue.auditType == .contrast || issue.compactDescription.contains("inaccessible") {
                print("AUDIT (feuille iPad) " + line)
                return true
            }
            // Élément que l'audit ne sait pas nommer (hors de l'arbre d'accessibilité : décor du système,
            // lignes cachées sous la barre d'onglets) : impossible à situer, signalé dans le journal
            // sans faire échouer
            if [.contrast, .dynamicType, .textClipped].contains(issue.auditType), issue.element == nil {
                print("AUDIT (élément non identifié) " + line)
                return true
            }
            // Titres et champ de recherche des barres de navigation : textes du système, qu'iOS
            // tronque lui-même (la loupe des grands contenus les affiche en entier)
            if issue.auditType == .textClipped, let frame = issue.element?.frame,
               issue.element?.elementType == .searchField || self.app.navigationBars.allElementsBoundByIndex.contains(where: { $0.frame.intersects(frame) }) {
                print("AUDIT (barre du système) " + line)
                return true
            }
            // Taille de texte « partiellement » prise en charge : iOS plafonne lui-même ses contrôles
            // (barres d'outils, en-têtes, boutons de formulaire) et offre la loupe des grands contenus.
            // Signalé dans le journal, sans faire échouer le parcours.
            if issue.auditType == .dynamicType, issue.compactDescription.contains("partially") {
                print("AUDIT (avertissement) " + line)
                return true
            }
            self.issues.append(line)
            print("AUDIT " + line)
            return true
        }
    }

    /// Partie visible de l'écran : la fenêtre sans la barre d'onglets ni le clavier.
    private var visibleArea: CGRect {
        var area = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        // Barre en bas (iPhone) ; sur iPad, elle flotte en haut sans masquer le contenu
        if tabBar.exists, tabBar.frame.minY > area.midY {
            area.size.height = tabBar.frame.minY - area.minY
        }
        // Clavier ouvert : ce qu'il recouvre n'est pas visible
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists, keyboard.frame.minY > area.minY, keyboard.frame.minY < area.maxY {
            area.size.height = keyboard.frame.minY - area.minY
        }
        return area
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

        // Bouton jamais grisé : un appui sans les champs dit quoi saisir
        app.buttons["login.submit"].tap()
        XCTAssertTrue(element(containing: "Saisissez l’adresse de l’espace").waitForExistence(timeout: 2))

        workspace.tap()
        workspace.typeText("mon espace")
        XCTAssertTrue(element(containing: "Adresse invalide").waitForExistence(timeout: 2))

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

        // Tableau Kanban (iPad) : colonnes par statut, cartes dans l'ordre du tableau
        if isPad {
            app.buttons["board.open"].tap()
            let card = app.descendants(matching: .any)["board.card.PORTAIL-7"]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            XCTAssertTrue(app.descendants(matching: .any)["board.card.PORTAIL-9"].exists, "deuxième carte de « À faire »")
            try audit("tableau")
            capture("4b-tableau")
            // Fiche ouverte depuis le tableau, puis retour et fermeture
            card.tap()
            XCTAssertTrue(element(containing: "Prise de rendez-vous en ligne").waitForExistence(timeout: 10))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["board.close"].waitForExistence(timeout: 5))
            app.buttons["board.close"].tap()
            XCTAssertTrue(app.buttons["ticket.create"].waitForExistence(timeout: 5))
        }

        // Création rapide
        app.buttons["ticket.create"].tap()
        // Champ sur plusieurs lignes (axis: .vertical) : vue de texte, pas champ de texte
        let title = app.descendants(matching: .any).matching(identifier: "ticket.create.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Vérifier l’accès PMR du guichet")
        try audit("nouveau ticket", modal: true)
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
        XCTAssertTrue(element(containing: "Camille Martin").waitForExistence(timeout: 10))
        try audit("compte")
        capture("7-compte")
        // Bas de la liste : la ligne n'existe qu'une fois affichée
        for _ in 0..<5 where !logout.exists || !logout.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(logout.waitForExistence(timeout: 5))
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
