// SPDX-License-Identifier: EUPL-1.2

import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import JalonioKit

/// Faux serveur : répond selon la route et le jeton, et note chaque requête.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    typealias Handler = (URLRequest) -> (Int, String)
    private let lock = NSLock()
    private var handler: Handler
    private(set) var requests: [URLRequest] = []

    init(_ handler: @escaping Handler) { self.handler = handler }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, body) = lock.withLock { () -> (Int, String) in
            requests.append(request)
            return handler(request)
        }
        // Laisse les autres requêtes avancer : les appels concurrents se chevauchent vraiment
        try await Task.sleep(nanoseconds: 20_000_000)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (Data(body.utf8), response)
    }

    var paths: [String] { lock.withLock { requests.map { $0.url!.path } } }
    func count(_ suffix: String) -> Int { paths.filter { $0.hasSuffix(suffix) }.count }
}

final class APIClientTests: XCTestCase {
    private let origin = URL(string: "https://mairie-x.jalonio.fr")!
    private let pair = TokenPair(accessToken: "jalm_ancien", refreshToken: "jalr_ancien", expiresIn: 3600, deviceId: "appareil")
    private let fresh = #"{"tokens":{"accessToken":"jalm_neuf","refreshToken":"jalr_neuf","expiresIn":3600,"deviceId":"appareil"}}"#

    private func fixture(_ name: String) -> String {
        String(decoding: (try? DecodingTests.fixture(name)) ?? Data(), as: UTF8.self)
    }

    func testHeadersAddressAndLanguage() async throws {
        let transport = FakeTransport { _ in (200, self.fixture("me")) }
        let client = APIClient(server: MemoryServerStore(origin), tokens: MemoryTokenStore(pair), transport: transport, languages: { "de-DE,fr;q=0.9" })
        let me = try await client.me()
        XCTAssertEqual(me.displayName, "Camille Martin")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://mairie-x.jalonio.fr/backend/api/me")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jalm_ancien")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Jalonio-Requested"), "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "de-DE,fr;q=0.9")
    }

    func testLoginSendsNoTokenAndAnnouncesIosDevice() async throws {
        let transport = FakeTransport { _ in (200, self.fixture("login")) }
        let client = APIClient(server: MemoryServerStore(origin), tokens: MemoryTokenStore(pair), transport: transport)
        _ = try await client.login(email: " camille@val-fictif.fr ", password: "secret", device: DeviceInfo(name: "iPhone de Camille"))

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try XCTUnwrap(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual(body["email"] as? String, "camille@val-fictif.fr")
        let device = try XCTUnwrap(body["device"] as? [String: Any])
        XCTAssertEqual(device["platform"] as? String, "ios")
        XCTAssertEqual(device["name"] as? String, "iPhone de Camille")
    }

    func testExpiredTokenIsRefreshedOnceForConcurrentRequests() async throws {
        let tokens = MemoryTokenStore(pair)
        let transport = FakeTransport { request in
            if request.url!.path.hasSuffix("auth/mobile/refresh") { return (200, self.fresh) }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer jalm_neuf" { return (200, self.fixture("me")) }
            return (401, #"{"error":"unauthorized","message":"Session expirée."}"#)
        }
        let client = APIClient(server: MemoryServerStore(origin), tokens: tokens, transport: transport)

        try await withThrowingTaskGroup(of: Me.self) { group in
            for _ in 0..<5 { group.addTask { try await client.me() } }
            for try await me in group { XCTAssertEqual(me.initials, "CM") }
        }
        XCTAssertEqual(transport.count("auth/mobile/refresh"), 1, "un seul rafraîchissement : un second serait vu comme un rejeu")
        XCTAssertEqual(tokens.tokens?.refreshToken, "jalr_neuf")
        let refreshBody = try XCTUnwrap(transport.requests.first { $0.url!.path.hasSuffix("refresh") }?.httpBody)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: refreshBody) as? [String: String], ["refreshToken": "jalr_ancien"])
    }

    func testRefusedRefreshSignsOut() async throws {
        let tokens = MemoryTokenStore(pair)
        let signedOut = expectation(description: "retour à la connexion")
        let transport = FakeTransport { request in
            request.url!.path.hasSuffix("auth/mobile/refresh") ? (401, self.fixture("error_refresh_replay")) : (401, "{}")
        }
        let client = APIClient(server: MemoryServerStore(origin), tokens: tokens, transport: transport, onSignedOut: { signedOut.fulfill() })
        do {
            _ = try await client.me()
            XCTFail("la session aurait dû expirer")
        } catch let failure as APIFailure {
            XCTAssertEqual(failure, .signedOut)
        }
        await fulfillment(of: [signedOut], timeout: 1)
        XCTAssertNil(tokens.tokens)
    }

    func testServerErrorCarriesTranslatedMessage() async throws {
        let transport = FakeTransport { _ in (409, #"{"error":"conflict","message":"Ce ticket a été modifié entre-temps."}"#) }
        let client = APIClient(server: MemoryServerStore(origin), tokens: MemoryTokenStore(pair), transport: transport)
        do {
            _ = try await client.ticket("PORTAIL-1")
            XCTFail("erreur attendue")
        } catch let failure as APIFailure {
            XCTAssertEqual(failure, .server(status: 409, code: "conflict", message: "Ce ticket a été modifié entre-temps."))
        }
    }

    func testWithoutWorkspaceNothingIsSent() async throws {
        let transport = FakeTransport { _ in (200, "{}") }
        let client = APIClient(server: MemoryServerStore(nil), tokens: MemoryTokenStore(), transport: transport)
        do {
            _ = try await client.projects()
            XCTFail("erreur attendue")
        } catch let failure as APIFailure {
            XCTAssertEqual(failure, .signedOut)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testTicketUpdatesSendIntegersAndExplicitNull() async throws {
        let transport = FakeTransport { _ in (200, self.fixture("tickets_PORTAIL-1")) }
        let client = APIClient(server: MemoryServerStore(origin), tokens: MemoryTokenStore(pair), transport: transport)
        let ticket = try await client.ticket("PORTAIL-1")
        _ = try await client.setStatus(ticket, statusId: 81)
        _ = try await client.assign(ticket, userId: nil)

        let bodies = transport.requests.dropFirst().map { String(decoding: $0.httpBody ?? Data(), as: UTF8.self) }
        XCTAssertTrue(bodies[0].contains(#""statusId":81"#), bodies[0])
        XCTAssertTrue(bodies[0].contains(#""version":\#(ticket.version)"#), bodies[0])
        XCTAssertTrue(bodies[1].contains(#""assigneeId":null"#), bodies[1])
        XCTAssertEqual(transport.requests.last?.httpMethod, "PATCH")
        XCTAssertEqual(transport.requests.last?.url?.path, "/backend/api/tickets/PORTAIL-1")
    }
}
