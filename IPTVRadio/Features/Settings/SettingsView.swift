import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case account = "Account"
    case stations = "Stations"
    case playback = "Playback"
    case app = "App"

    var id: String { rawValue }
}

/// Settings: account, playback options, filtering rules, cache and privacy.
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var playback: PlaybackEngine

    @State private var confirmSignOut = false
    @State private var cacheCleared = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RadioPageHeading(title: "Settings", subtitle: "Your account. Your preferences.")
                    ForEach(SettingsCategory.allCases) { category in
                        NavigationLink {
                            categoryPage(category)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: categorySymbol(category)).font(.radio(20, .regular))
                                    .frame(width: 28).foregroundStyle(AetherTheme.mutedIcon)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(category.rawValue).font(.radio(.body, .semibold))
                                    Text(categoryDescription(category)).font(.radio(.caption))
                                        .foregroundStyle(AetherTheme.secondaryText)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right").font(.radio(12))
                                    .foregroundStyle(AetherTheme.mutedIcon)
                            }
                            .frame(minHeight: 88).contentShape(Rectangle())
                            .overlay(alignment: .bottom) { AetherTheme.divider.frame(height: 0.5) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.category.\(category.rawValue.lowercased())")
                    }
                    Text(versionLabel)
                        .font(.radio(.caption)).foregroundStyle(AetherTheme.mutedIcon).padding(.top, 32)
                        .accessibilityIdentifier("settings.version")
                }
                .padding(.horizontal, 24).padding(.bottom, 32)
            }
            .background(AetherTheme.canvas.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("Sign out?", isPresented: $confirmSignOut) {
            Button("Sign Out", role: .destructive) { playback.stop(); auth.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Credentials are removed from the Keychain and cached data is cleared.")
        }
    }

    private func categoryPage(_ category: SettingsCategory) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                switch category {
                case .account: accountSection
                case .stations: filteringSection
                case .playback: playbackSection
                case .app:
                    appearanceSection
                    cacheSection
                    privacySection
                }
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 32)
        }
        .background(AetherTheme.canvas.ignoresSafeArea())
        .navigationTitle(category.rawValue).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        return "Aether \(version) (\(build))"
    }

    private func categorySymbol(_ category: SettingsCategory) -> String {
        switch category {
        case .account: "person.crop.circle"
        case .stations: "antenna.radiowaves.left.and.right"
        case .playback: "waveform"
        case .app: "slider.horizontal.3"
        }
    }

    private func categoryDescription(_ category: SettingsCategory) -> String {
        switch category {
        case .account: "Subscription and sign-in"
        case .stations: "Filtering and detection"
        case .playback: "Streaming, metadata and output"
        case .app: "Appearance, storage and privacy"
        }
    }

    private var appearanceSection: some View {
        settingsGroup("Appearance", systemImage: "paintbrush.pointed") {
            AetherLabeledValue("Appearance", value: "Dark")
                .aetherSettingsRow()
            settingsDivider
            AetherSettingToggle("Translucent navigation", isOn: $settings.liquidGlassEnabled)
                .accessibilityIdentifier("settings.liquidGlass")
                .aetherSettingsRow()
            settingsFooter("Adds a subtle material to the top navigation. Turn off for a solid background.")
        }
    }

    private var accountSection: some View {
        settingsGroup("Account", systemImage: "person.crop.circle") {
            if let session = activeSessionDescription {
                AetherLabeledValue("Status", value: session.status)
                    .aetherSettingsRow()
                if let expiry = session.expiry {
                    settingsDivider
                    AetherLabeledValue("Subscription expires", value: expiry)
                        .aetherSettingsRow()
                }
            } else {
                AetherLabeledValue("Status", value: "Signed in")
                    .aetherSettingsRow()
            }
            if let warning = auth.insecureEndpointWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AetherTheme.warning)
                    .font(.radio(.footnote))
                    .aetherSettingsRow()
            }
            settingsDivider
            Button("Sign Out", role: .destructive) {
                confirmSignOut = true
            }
            .font(.radio(.body, .medium))
            .foregroundStyle(AetherTheme.destructive)
            .accessibilityIdentifier("settings.signOut")
            .aetherSettingsRow()
        }
    }

    private var playbackSection: some View {
        VStack(spacing: 24) {
            settingsGroup("Streaming", systemImage: "antenna.radiowaves.left.and.right") {
                AetherSettingToggle("Allow cellular streaming", isOn: $settings.cellularAllowed)
                    .accessibilityIdentifier("settings.cellular")
                    .aetherSettingsRow()
                settingsDivider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cellular buffer")
                            .font(.radio(.body, .medium))
                        Spacer()
                        Text("\(Int(settings.cellularBuffer)) s")
                            .font(.radio(.body))
                            .foregroundStyle(AetherTheme.secondaryText)
                    }
                    Slider(value: $settings.cellularBuffer, in: StreamBuffer.cellularRange, step: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Cellular buffer")
                .accessibilityValue("\(Int(settings.cellularBuffer)) seconds")
                .accessibilityIdentifier("settings.cellularBuffer")
                .aetherSettingsRow()
                settingsFooter("Audio kept in reserve on cellular data and Personal Hotspot, so brief signal drops don't pause the station. Raise it if playback keeps pausing: a larger buffer covers longer drops but takes longer to fill when a station starts. Changes reconnect a station playing on cellular. Wi-Fi uses \(Int(StreamBuffer.standardDuration)) s.")
                    .padding(.bottom, 12)
                settingsDivider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Stream timeout")
                            .font(.radio(.body, .medium))
                        Spacer()
                        Text("\(Int(settings.streamTimeout)) s")
                            .font(.radio(.body))
                            .foregroundStyle(AetherTheme.secondaryText)
                    }
                    Slider(value: $settings.streamTimeout, in: 5...60, step: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Stream timeout")
                .accessibilityValue("\(Int(settings.streamTimeout)) seconds")
                .aetherSettingsRow()
                settingsDivider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Auto-retry attempts")
                            .font(.radio(.body, .medium))
                        Spacer()
                        Text("\(settings.retryLimit)")
                            .font(.radio(.body))
                            .foregroundStyle(AetherTheme.secondaryText)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.retryLimit) },
                        set: { settings.retryLimit = Int($0) }
                    ), in: 0...5, step: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Auto-retry attempts")
                .accessibilityValue("\(settings.retryLimit) attempts")
                .aetherSettingsRow()
                settingsDivider
                SleepTimerStatusRow()
                    .aetherSettingsRow()
                settingsDivider
                AetherSettingToggle("Prefer audio-only stream", isOn: $settings.preferAudioOnlyRendition)
                    .accessibilityIdentifier("settings.audioOnly")
                    .aetherSettingsRow()
                settingsFooter("Uses a dedicated audio track when an HLS stream offers one.")
            }
            settingsGroup("Song information", systemImage: "music.note") {
                AetherSettingToggle("Look up song artwork online", isOn: $settings.lookupSongArtwork)
                    .accessibilityIdentifier("settings.artworkLookup")
                    .aetherSettingsRow()
                settingsDivider
                NavigationLink {
                    StreamDiagnosticsView()
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    settingsNavigationLabel("Stream diagnostics")
                }
                .accessibilityIdentifier("settings.streamDiagnostics")
                .aetherSettingsRow()
                settingsFooter("When the stream has no artwork, Aether can look up the current song in Apple's public catalog. No account or tracking is involved; turn this off for fully offline metadata.")
            }
            settingsGroup("Audio output", systemImage: "hifispeaker") {
                AetherSettingToggle("Show Sonos / AirPlay output", isOn: $settings.sonosOutputControl)
                    .accessibilityIdentifier("settings.sonosOutput")
                    .aetherSettingsRow()
                settingsDivider
                AetherSettingToggle("Show Bluetooth output", isOn: $settings.bluetoothOutputControl)
                    .accessibilityIdentifier("settings.bluetoothOutput")
                    .aetherSettingsRow()
                settingsFooter("Now Playing shows one output button. With both switches on, it shows AirPlay; paired Bluetooth audio is also available through iOS audio output controls. Sonos speakers need AirPlay support and the same Wi-Fi network.")
            }
        }
    }

    private var filteringSection: some View {
        VStack(spacing: 24) {
            settingsGroup("Station filtering", systemImage: "line.3.horizontal.decrease") {
                AetherSettingToggle("Show only SiriusXM-labelled stations", isOn: $settings.siriusOnly)
                    .accessibilityIdentifier("settings.siriusOnly")
                    .aetherSettingsRow()
                settingsDivider
                AetherSettingToggle("Show all detected radio stations", isOn: $settings.showAllStations)
                    .accessibilityIdentifier("settings.showAll")
                    .aetherSettingsRow()
            }
            settingsGroup("Detection rules", systemImage: "slider.horizontal.3") {
                NavigationLink {
                    DetectionRulesEditorView()
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    settingsNavigationLabel("Edit detection rules")
                }
                .aetherSettingsRow()
                settingsFooter("Tune the keyword rules if a provider misclassifies a station.")
            }
        }
    }

    private var cacheSection: some View {
        settingsGroup("Data", systemImage: "externaldrive") {
            AetherLabeledValue("Cached data size", value: ByteCountFormatter.string(fromByteCount: Int64(cacheSize), countStyle: .file))
                .aetherSettingsRow()
            settingsDivider
            Button("Clear station cache") {
                library.clearCacheData()
                cacheCleared = true
            }
            .font(.radio(.body, .medium))
            .alert("Cache cleared", isPresented: $cacheCleared) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Cached stations were removed. A refresh will re-download your lineup.")
            }
            .aetherSettingsRow()
        }
    }

    private var privacySection: some View {
        settingsGroup("Privacy", systemImage: "lock.shield") {
            NavigationLink {
                PrivacyNoticeView()
                    .toolbar(.visible, for: .navigationBar)
            } label: {
                settingsNavigationLabel("Privacy & authorization")
            }
            .aetherSettingsRow()
            settingsDivider
            NavigationLink {
                PlaybackLicensesView()
                    .toolbar(.visible, for: .navigationBar)
            } label: {
                settingsNavigationLabel("Playback acknowledgements")
            }
            .aetherSettingsRow()
            settingsFooter("No analytics, no tracking. Credentials are stored only in the Keychain and never logged.")
        }
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AetherPanelHeader(title: title, symbol: systemImage)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.vertical, 8)
        }
        .foregroundStyle(AetherTheme.primaryText)
        .tint(AetherTheme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsDivider: some View {
        AetherTheme.divider
            .frame(height: 1)
    }

    private func settingsFooter(_ message: String) -> some View {
        Text(message)
            .font(.radio(13))
            .foregroundStyle(AetherTheme.mutedIcon)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }

    private func settingsNavigationLabel(_ title: String) -> some View {
        HStack {
            Text(title).font(.radio(.body, .medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.radio(.subheadline, .semibold))
                .foregroundStyle(AetherTheme.mutedIcon)
        }
        .foregroundStyle(AetherTheme.primaryText)
    }

    private var cacheSize: Int {
        JSONFileStore().totalBytes
    }

    private var activeSessionDescription: (status: String, expiry: String?)? {
        guard case let .active(session) = auth.authState else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return (
            session.status ?? (session.isExpired ? "Expired" : "Active"),
            session.expiryDate.map { formatter.string(from: $0) }
        )
    }
}

private extension View {
    func aetherSettingsRow() -> some View {
        font(.radio(.body, .medium))
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }
}

/// Shows the sleep timer countdown when active.
struct SleepTimerStatusRow: View {
    @EnvironmentObject private var playback: PlaybackEngine

    var body: some View {
        if let deadline = playback.sleepTimerDeadline {
            let remaining = max(0, deadline.timeIntervalSinceNow)
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            AetherLabeledValue("Sleep timer", value: String(format: "%d:%02d", minutes, seconds))
        } else {
            AetherLabeledValue("Sleep timer", value: "Off")
        }
    }
}

/// Editor for the configurable detection rules.
struct DetectionRulesEditorView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var radioGroupText = ""
    @State private var radioNameText = ""
    @State private var siriusText = ""
    @State private var videoGroupText = ""

    var body: some View {
        Form {
            RadioPageHeading(title: "Detection rules", subtitle: "Configure which provider channels appear as radio.")
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            Section {
                TextEditor(text: $siriusText)
                    .font(.radio(.body))
                    .scrollContentBackground(.hidden)
                    .listRowBackground(AetherTheme.surface)
                    .frame(minHeight: 60)
                    .accessibilityLabel("Sirius keywords, one per line")
            } header: {
                Text("SiriusXM keywords")
                    .font(.radio(.footnote, .semibold))
            } footer: {
                Text("Case-insensitive. Matched against station names, groups and EPG ids. One keyword per line.")
                    .font(.radio(.footnote))
            }

            Section {
                TextEditor(text: $radioGroupText)
                    .font(.radio(.body))
                    .scrollContentBackground(.hidden)
                    .listRowBackground(AetherTheme.surface)
                    .frame(minHeight: 80)
                    .accessibilityLabel("Radio group keywords, one per line")
            } header: {
                Text("Radio group keywords")
                    .font(.radio(.footnote, .semibold))
            } footer: {
                Text("Group titles (categories) that indicate audio stations, one per line.")
                    .font(.radio(.footnote))
            }

            Section {
                TextEditor(text: $radioNameText)
                    .font(.radio(.body))
                    .scrollContentBackground(.hidden)
                    .listRowBackground(AetherTheme.surface)
                    .frame(minHeight: 100)
                    .accessibilityLabel("Radio name keywords, one per line")
            } header: {
                Text("Radio name keywords")
                    .font(.radio(.footnote, .semibold))
            } footer: {
                Text("Channel-name keywords that indicate audio, one per line.")
                    .font(.radio(.footnote))
            }

            Section {
                TextEditor(text: $videoGroupText)
                    .font(.radio(.body))
                    .scrollContentBackground(.hidden)
                    .listRowBackground(AetherTheme.surface)
                    .frame(minHeight: 60)
                    .accessibilityLabel("Video group keywords, one per line")
            } header: {
                Text("Video group keywords")
                    .font(.radio(.footnote, .semibold))
            } footer: {
                Text("Group titles that indicate video channels, which are excluded, one per line.")
                    .font(.radio(.footnote))
            }

            Section {
                Button("Reset to defaults") {
                    settings.resetDetectionRules()
                    loadFields()
                }
                .font(.radio(.body, .medium))
            }
        }
        .radioSettingsList()
        .navigationTitle("Detection rules")
        .onAppear { loadFields() }
        .onDisappear { saveFields() }
    }

    private func loadFields() {
        siriusText = settings.detectionRules.siriusKeywords.joined(separator: "\n")
        radioGroupText = settings.detectionRules.radioGroupKeywords.joined(separator: "\n")
        radioNameText = settings.detectionRules.radioNameKeywords.joined(separator: "\n")
        videoGroupText = settings.detectionRules.videoGroupKeywords.joined(separator: "\n")
    }

    private func saveFields() {
        var rules = settings.detectionRules
        rules.siriusKeywords = lines(siriusText)
        rules.radioGroupKeywords = lines(radioGroupText)
        rules.radioNameKeywords = lines(radioNameText)
        rules.videoGroupKeywords = lines(videoGroupText)
        settings.detectionRules = rules
    }

    private func lines(_ text: String) -> [String] {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// The required authorization/privacy notice.
struct PrivacyNoticeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RadioPageHeading(title: "Privacy & authorization", subtitle: "How Aether handles your data.")

                Text("Authorization requirement")
                    .font(.radio(.headline))
                Text("You must hold valid authorization to access any provider streams you configure. Aether also lets you explore publicly listed radio streams in Aether Dial. Stations are operated by third parties and may change or restrict access. The app does not bundle or redistribute their audio, or bypass DRM, authentication, geographic restrictions, or provider limitations.")
                    .font(.radio(.subheadline))
                    .foregroundStyle(AetherTheme.secondaryText)

                Text("Your data")
                    .font(.radio(.headline))
                Text("Credentials (server URL, username, password or playlist URL) are stored exclusively in the iOS Keychain. Station lists and preferences stay on your device. Aether Dial sends the place, genre, and station name you search for to Radio Browser, and a station ID when you listen from the directory. It does not send your provider credentials or private stream URLs there.")
                    .font(.radio(.subheadline))
                    .foregroundStyle(AetherTheme.secondaryText)

                Text("No tracking")
                    .font(.radio(.headline))
                Text("This app contains no analytics, advertising, or third-party tracking SDKs. Logs are scrubbed of usernames, passwords and credential-bearing URLs.")
                    .font(.radio(.subheadline))
                    .foregroundStyle(AetherTheme.secondaryText)

                Text("Secure connections")
                    .font(.radio(.headline))
                Text("HTTPS is preferred. If your provider only offers an unencrypted HTTP endpoint, the app clearly warns you before you continue. Because providers differ, connections to provider-supplied HTTP endpoints (including artwork servers) are allowed; the app still warns you whenever an insecure portal is detected.")
                    .font(.radio(.subheadline))
                    .foregroundStyle(AetherTheme.secondaryText)
            }
            .padding()
        }
        .background(AetherTheme.background.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
