// SPDX-License-Identifier: EUPL-1.2

#if DEBUG
import Foundation
import JalonioKit

/// Faux serveur des tests d'interface (`-ui-demo`) : vraies réponses enregistrées du
/// backend de test (données de démonstration) ; le tableau et le déplacement reprennent
/// les cartes de la liste des tickets (même format côté serveur). Absent de la version publiée : code sous
/// DEBUG et fichiers `demo-*.json` exclus en Release (project.yml).
struct DemoTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path.replacingOccurrences(of: "/backend/api/", with: "") ?? ""
        let method = request.httpMethod ?? "GET"
        let (status, file): (Int, String?) = switch (method, path) {
        case ("POST", "auth/login"), ("POST", "auth/two-factor"): (200, "login")
        case ("POST", "auth/mobile/refresh"): (200, "refresh")
        case ("POST", "auth/mobile/logout"): (204, nil)
        case ("GET", "me"): (200, "me")
        case ("GET", "my/tickets"): (200, "my_tickets")
        case ("GET", "projects"): (200, "projects")
        case ("GET", "notifications"): (200, "notifications_limit_50")
        case ("POST", "notifications/read"): (200, nil)
        case ("GET", let p) where p.hasPrefix("projects/") && p.hasSuffix("/board"): (200, "projects_PORTAIL_board")
        case ("POST", let p) where p.hasPrefix("tickets/") && p.hasSuffix("/move"): (200, "move")
        case (_, let p) where p.hasPrefix("projects/") && p.hasSuffix("/tickets") && method == "GET": (200, "projects_PORTAIL_tickets_perPage_300")
        case (_, let p) where p.hasPrefix("projects/") && p.hasSuffix("/tickets"): (201, "tickets_PORTAIL-1")
        case (_, let p) where p.hasPrefix("projects/"): (200, "projects_PORTAIL")
        case (_, let p) where p.hasSuffix("/activity"): (200, "activity_with_comments")
        case (_, let p) where p.hasSuffix("/comments"): (201, nil)
        case (_, let p) where p.hasPrefix("tickets/"): (200, "tickets_PORTAIL-1")
        default: (404, nil)
        }
        let data: Data
        if let file, let url = Bundle.main.url(forResource: "demo-\(file)", withExtension: "json") {
            data = try Data(contentsOf: url)
        } else {
            data = Data(status == 404 ? #"{"error":"not-found","message":"Introuvable."}"#.utf8 : #"{"unread":0}"#.utf8)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (data, response)
    }
}
#endif
