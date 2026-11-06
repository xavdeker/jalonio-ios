// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI

@main
struct JalonioApp: App {
    @State private var model = AppModel.forLaunch()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Brand.green)
        }
    }
}

extension AppModel {
    /// Tests d'interface : `-ui-testing`, session et espace vides à chaque lancement ;
    /// `-ui-demo`, en plus, faux serveur aux réponses enregistrées (DEBUG seulement).
    static func forLaunch() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") || arguments.contains("-ui-demo") {
            // Adresse saisie au lancement précédent (@AppStorage de LoginView) : effacée
            UserDefaults.standard.removeObject(forKey: "jalonio.lastWorkspace")
        }
        #if DEBUG
        if arguments.contains("-ui-demo") {
            return AppModel(server: MemoryServerStore(), tokens: MemoryTokenStore(), transport: DemoTransport())
        }
        #endif
        if arguments.contains("-ui-testing") {
            return AppModel(server: MemoryServerStore(), tokens: MemoryTokenStore())
        }
        return AppModel()
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.phase {
            case .launching:
                ProgressView(L.tr("loading"))
            case .signedOut(let message):
                LoginView(notice: message)
            case .unreachable(let message):
                ErrorState(message: message) { Task { await model.start() } }
            case .signedIn:
                MainView()
            }
        }
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            // Retour au premier plan : notifications à jour (pas de notifications poussées, ADR-0031)
            if phase == .active, model.me != nil { Task { await model.refreshUnread() } }
        }
    }
}

/// Onglets ; sur iPad, Accueil et Projets s'affichent en colonnes (NavigationSplitView).
struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(L.tr("tab_home"), systemImage: "house") }
            ProjectsView()
                .tabItem { Label(L.tr("tab_projects"), systemImage: "folder") }
            NotificationsView()
                .tabItem { Label(L.tr("tab_notifications"), systemImage: "bell") }
                .badge(model.unread)
            AccountView()
                .tabItem { Label(L.tr("tab_account"), systemImage: "person.crop.circle") }
        }
    }
}
