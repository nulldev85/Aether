import SwiftUI

/// Sign-in screen supporting Xtream Codes credentials and M3U playlist import.
/// Includes the authorization notice required by the app's terms of use.
struct LoginView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var auth: AuthViewModel

    @State private var mode: SettingsStore.AuthMode = .xtream
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var playlistURL = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    HStack(spacing: 8) {
                        ForEach(SettingsStore.AuthMode.allCases) { option in
                            Button { mode = option } label: {
                                Text(option == .xtream ? "Xtream Codes" : "M3U Playlist")
                                    .font(.radio(.subheadline, .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .foregroundStyle(mode == option ? AetherTheme.onAccent : AetherTheme.secondaryText)
                                    .background(mode == option ? AetherTheme.accent : AetherTheme.surface,
                                                in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(mode == option ? [.isSelected] : [])
                        }
                    }
                    .accessibilityIdentifier("login.methodPicker")

                    if mode == .xtream {
                        xtreamForm
                    } else {
                        m3uForm
                    }

                    if let warning = auth.insecureEndpointWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.radio(.footnote))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("login.insecureWarning")
                    }

                    if let error = errorMessage {
                        Label(error, systemImage: "xmark.octagon.fill")
                            .font(.radio(.footnote))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("login.error")
                    }

                    signInButton

                    authorizationNotice
                }
                .padding(.horizontal, AetherTheme.margin)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(AetherTheme.background.ignoresSafeArea())
            .navigationTitle("Sign In")
            .onAppear {
                mode = environment.settings.authMode
            }
        }
    }

    private var header: some View {
        RadioPageHeading(title: "Good sound.\nYour station.", subtitle: "Welcome to Aether. Connect your provider and make yourself at home.", eyebrow: "AETHER / TUNE IN")
    }

    private var xtreamForm: some View {
        VStack(spacing: 12) {
            TextField("Server / portal URL (e.g. https://host:port)", text: $server)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .radioField()
                .accessibilityIdentifier("login.server")
                .accessibilityLabel(Text("Server or portal URL"))
            TextField("Username", text: $username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .radioField()
                .accessibilityIdentifier("login.username")
            SecureField("Password", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit(signIn)
                .radioField()
                .accessibilityIdentifier("login.password")
        }
    }

    private var m3uForm: some View {
        VStack(spacing: 12) {
            TextField("M3U / M3U8 playlist URL", text: $playlistURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .radioField()
                .accessibilityIdentifier("login.playlistURL")
            Text("The playlist is downloaded from your own provider. URLs containing embedded credentials are stored only in the Keychain and never logged.")
                .font(.radio(.footnote))
                .foregroundStyle(AetherTheme.secondaryText)
        }
    }

    private var signInButton: some View {
        Button {
            signIn()
        } label: {
            Group {
                if isSigningIn {
                    ProgressView().tint(AetherTheme.onAccent)
                } else {
                    Text("Sign In").font(.radio(.headline))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(AetherButtonStyle(prominent: true))
        .disabled(isSigningIn)
        .accessibilityIdentifier("login.submit")
    }

    private var authorizationNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Authorization notice", systemImage: "checkmark.shield")
                .font(.radio(.footnote, .semibold))
            Text("You must have valid authorization to access provider streams. Aether does not bundle or redistribute their audio and does not bypass DRM or access restrictions. Public stations in Aether Dial are operated by third parties.")
                .font(.radio(.caption2))
                .foregroundStyle(AetherTheme.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AetherTheme.raisedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AetherTheme.panelRadius, style: .continuous))
    }

    private func signIn() {
        errorMessage = nil
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            switch mode {
            case .xtream:
                let credentials = XtreamCredentials(
                    serverInput: server,
                    username: username,
                    password: password
                )
                let result = await auth.signIn(xtream: credentials, httpClient: environment.httpClient)
                if case let .failure(error) = result {
                    errorMessage = error.errorDescription
                }
            case .m3u:
                guard let url = URL(string: playlistURL.trimmingCharacters(in: .whitespaces)),
                      url.scheme != nil, url.host != nil else {
                    errorMessage = ProviderError.invalidServerURL.errorDescription
                    return
                }
                _ = await auth.signIn(m3u: url)
            }
        }
    }
}
