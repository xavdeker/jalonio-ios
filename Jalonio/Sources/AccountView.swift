// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI
import UIKit

/// Compte : personne et espace, langue, liens web et juridiques, déconnexion.
struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var confirmLogout = false

    private var webOrigin: URL { model.origin ?? URL(string: "https://app.jalonio.fr")! }
    private var french: Bool { (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("fr") }

    var body: some View {
        NavigationStack {
            Form {
                if let me = model.me {
                    Section {
                        HStack(spacing: 12) {
                            Avatar(initials: me.initials, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(me.displayName).font(.headline)
                                Text(me.email).font(.subheadline).foregroundStyle(Brand.muted)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        // Organisation et espace sur leur propre ligne : pleine largeur, jamais tronqués
                        Text(L.tr("account_workspace", me.organization.name, model.workspace ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(Brand.muted)
                    }
                }

                Section {
                    Button(L.tr("account_open_settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } header: {
                    Text(L.tr("account_language")).foregroundStyle(Brand.muted)
                } footer: {
                    Text(L.tr("account_language_hint")).foregroundStyle(Brand.muted)
                }

                Section {
                    Link(L.tr("account_open_web"), destination: ServerAddress.webPage("/profil/", origin: webOrigin))
                } footer: {
                    Text(L.tr("account_profile_hint")).foregroundStyle(Brand.muted)
                }

                Section(muted: L.tr("account_about")) {
                    Link(L.tr("account_help"), destination: URL(string: "https://jalonio.fr/aide/")!)
                    Link(L.tr("account_privacy"), destination: URL(string: "https://app.jalonio.fr/confidentialite/")!)
                    Link(L.tr("account_terms"), destination: URL(string: "https://app.jalonio.fr/cgu/")!)
                    Link(L.tr("account_legal"), destination: URL(string: "https://app.jalonio.fr/mentions-legales/")!)
                    // Exigence de l'App Store : la suppression du compte doit être trouvable depuis l'application
                    Link(L.tr("account_delete"), destination: URL(string: french ? "https://jalonio.fr/suppression-de-compte/" : "https://jalonio.fr/en/account-deletion/")!)
                    Text(L.tr("account_version", Self.version)).foregroundStyle(Brand.muted)
                }

                Section {
                    // Rouge conforme (celui du système est trop pâle pour du texte)
                    Button(role: .destructive) { confirmLogout = true } label: {
                        Text(L.tr("account_logout")).foregroundStyle(Brand.danger)
                    }
                    .accessibilityIdentifier("account.logout")
                }
            }
            .navigationTitle(L.tr("account_title"))
            .confirmationDialog(L.tr("account_logout"), isPresented: $confirmLogout, titleVisibility: .visible) {
                Button(L.tr("account_logout"), role: .destructive) { Task { await model.logout() } }
                Button(L.tr("cancel"), role: .cancel) {}
            } message: {
                Text(L.tr("account_logout_confirm"))
            }
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
