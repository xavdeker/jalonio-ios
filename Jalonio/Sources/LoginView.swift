// SPDX-License-Identifier: EUPL-1.2

import JalonioKit
import SwiftUI

/// Connexion : adresse de l'espace, e-mail, mot de passe, puis double authentification.
/// Pas de création de compte dans l'application : invitation ou inscription web (ADR-0029).
struct LoginView: View {
    var notice: String?

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @AppStorage("jalonio.lastWorkspace") private var workspace = ""
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var challenge: String?
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Field?

    private enum Field { case workspace, email, password, code }

    private var origin: URL? { ServerAddress.parse(workspace) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .accessibilityHidden(true)
                        Text(L.tr("login_intro"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if let message = error ?? notice {
                    Section {
                        Label(message, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Brand.danger)
                    }
                }

                if let challenge {
                    twoFactorSection(challenge)
                } else {
                    credentialsSection
                }

                Section {
                    // Jamais grisé (contraste et lecteurs d'écran) : sans espace, on dit quoi corriger
                    if challenge == nil {
                        Button {
                            if let origin {
                                openURL(ServerAddress.webPage("/mot-de-passe/oubli/", origin: origin))
                            } else {
                                error = L.tr("login_workspace_invalid")
                                focus = .workspace
                            }
                        } label: {
                            Text(L.tr("login_forgot")).font(.body)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Link(destination: URL(string: "https://app.jalonio.fr/inscription/")!) {
                            Text(L.tr("login_create_workspace")).font(.body)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Button(L.tr("login_back")) {
                            challenge = nil
                            code = ""
                            error = nil
                        }
                    }
                }
            }
            .navigationTitle("Jalonio")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(busy)
            // Formulaire lisible sur iPad : largeur d'une colonne
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var credentialsSection: some View {
        Section {
            TextField(L.tr("login_workspace"), text: $workspace)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .workspace)
                .submitLabel(.next)
                .onSubmit { focus = .email }
                .accessibilityIdentifier("login.workspace")
            TextField(L.tr("login_email"), text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }
                .accessibilityIdentifier("login.email")
            SecureField(L.tr("login_password"), text: $password)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await submit() } }
                .accessibilityIdentifier("login.password")
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    Spacer()
                    if busy { ProgressView() } else { Text(L.tr("login_submit")).bold() }
                    Spacer()
                }
            }
            .accessibilityIdentifier("login.submit")
        } footer: {
            // Gris secondaire trop pâle pour ce texte utile : couleur du texte principal
            Group {
                if let origin {
                    Text(L.tr("login_workspace_resolved", ServerAddress.displayName(for: origin)))
                } else if workspace.isEmpty {
                    Text(L.tr("login_workspace_hint", ServerAddress.saasDomain))
                } else {
                    Text(L.tr("login_workspace_invalid")).foregroundStyle(Brand.danger)
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private func twoFactorSection(_ challenge: String) -> some View {
        Section {
            TextField(L.tr("login_code"), text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .code)
                .onSubmit { Task { await submitCode(challenge) } }
                .accessibilityIdentifier("login.code")
            Button {
                Task { await submitCode(challenge) }
            } label: {
                HStack {
                    Spacer()
                    if busy { ProgressView() } else { Text(L.tr("login_submit")).bold() }
                    Spacer()
                }
            }
        } header: {
            Text(L.tr("login_two_factor_intro"))
                .textCase(nil)
        } footer: {
            Text(L.tr("login_code_hint"))
        }
        .onAppear { focus = .code }
    }

    private func submit() async {
        guard !workspace.isEmpty, !email.isEmpty, !password.isEmpty else {
            error = L.tr("login_fields_missing")
            focus = workspace.isEmpty ? .workspace : email.isEmpty ? .email : .password
            return
        }
        guard let origin else {
            error = L.tr("login_workspace_invalid")
            focus = .workspace
            return
        }
        busy = true
        defer { busy = false }
        do {
            if let next = try await model.login(origin: origin, email: email, password: password) {
                challenge = next
                error = nil
            }
            password = ""
        } catch {
            self.error = L.message(for: error)
        }
    }

    private func submitCode(_ challenge: String) async {
        guard code.trimmingCharacters(in: .whitespaces).count >= 6 else {
            error = L.tr("login_code_missing")
            focus = .code
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await model.twoFactor(challenge: challenge, code: code)
        } catch {
            self.error = L.message(for: error)
            code = ""
        }
    }
}
