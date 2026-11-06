// SPDX-License-Identifier: EUPL-1.2

import XCTest
@testable import JalonioKit

final class ServerAddressTests: XCTestCase {
    func testWorkspaceNameBecomesSaasAddress() {
        XCTAssertEqual(ServerAddress.parse("mairie-x")?.absoluteString, "https://mairie-x.jalonio.fr")
        XCTAssertEqual(ServerAddress.parse("  Mairie-X  ")?.absoluteString, "https://mairie-x.jalonio.fr")
    }

    func testDomainsAndFullAddressesAreKept() {
        XCTAssertEqual(ServerAddress.parse("mairie-x.jalonio.fr")?.absoluteString, "https://mairie-x.jalonio.fr")
        XCTAssertEqual(ServerAddress.parse("https://projets.mairie.fr/")?.absoluteString, "https://projets.mairie.fr")
        XCTAssertEqual(ServerAddress.parse("https://projets.mairie.fr/connexion/?suite=x")?.absoluteString, "https://projets.mairie.fr")
        XCTAssertEqual(ServerAddress.parse("projets.mairie.fr:8443")?.absoluteString, "https://projets.mairie.fr:8443")
    }

    func testInvalidAddressesAreRejected() {
        XCTAssertNil(ServerAddress.parse(""))
        XCTAssertNil(ServerAddress.parse("   "))
        XCTAssertNil(ServerAddress.parse("mon espace"))
        XCTAssertNil(ServerAddress.parse("https://intranet"))
        XCTAssertNil(ServerAddress.parse("ftp://projets.mairie.fr"))
        XCTAssertNil(ServerAddress.parse("projets..mairie.fr"))
    }

    func testClearTextOnlyTowardsLocalServer() {
        XCTAssertNil(ServerAddress.parse("http://projets.mairie.fr"))
        XCTAssertEqual(ServerAddress.parse("http://localhost:3000")?.absoluteString, "http://localhost:3000")
    }

    func testApiBaseAndPages() throws {
        let origin = try XCTUnwrap(ServerAddress.parse("mairie-x"))
        XCTAssertEqual(ServerAddress.apiBase(for: origin).absoluteString, "https://mairie-x.jalonio.fr/backend/api/")
        XCTAssertEqual(ServerAddress.displayName(for: origin), "mairie-x.jalonio.fr")
        XCTAssertEqual(ServerAddress.webPage("/mot-de-passe/oubli/", origin: origin).absoluteString, "https://mairie-x.jalonio.fr/mot-de-passe/oubli/")
    }
}
