import SwiftUI
import AVKit
import MediaPlayer

/// After-hours listening room around Aether's unchanged spinning disc.
struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var playback: PlaybackEngine
    @EnvironmentObject private var settings: SettingsStore
    @State private var showSleepTimerSheet = false
    @State private var stationLogo: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let station = playback.state.station {
                recordContent(for: station)
                    .task(id: station.id) {
                        stationLogo = nil
                        guard let url = station.logoURL else { return }
                        stationLogo = await ArtworkCache.shared.image(for: url)
                    }
            } else {
                EmptyStateView(title: "Nothing playing", message: "Pick a station to start listening.", systemImage: "music.note")
                    .frame(maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if playback.state.station != nil {
                controlCard
                    .padding(.horizontal, AetherTheme.margin)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(AetherTheme.primaryText)
        .background(AetherTheme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSleepTimerSheet) { SleepTimerSheet() }
    }

    private func recordContent(for station: RadioStation) -> some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 16) {
                GeometryReader { stage in
                    record(diameter: NowPlayingLayout.recordDiameter(in: stage.size))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(minHeight: NowPlayingLayout.minimumRecordStageHeight)
                trackDetails(for: station)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // On short screens or large text sizes, only the record/details
            // scroll. Transport and Close remain fixed and reachable.
            ScrollView {
                VStack(spacing: 16) {
                    record(diameter: NowPlayingLayout.compactRecordDiameter)
                    trackDetails(for: station)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("nowplaying.detailsScroll")
        }
        .padding(.horizontal, AetherTheme.margin)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func record(diameter: CGFloat) -> some View {
        VinylRecordView(
            artwork: playback.nowPlayingMetadata?.artworkImage ?? stationLogo,
            isSpinning: playback.state.isPlaying && scenePhase == .active && !reduceMotion
        )
        .frame(width: diameter, height: diameter)
    }

    private var controlCard: some View {
        VStack(spacing: NowPlayingLayout.controlRowGap) {
            controlRow
            outputControls
        }
        .padding(.horizontal, 18)
        .padding(.vertical, NowPlayingLayout.controlVerticalPadding)
        .frame(maxWidth: 440)
        .background(AetherTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AetherTheme.divider, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nowplaying.controls")
    }

    private var header: some View {
        HStack(spacing: 10) {
            AetherIconTile(symbol: "dot.radiowaves.left.and.right")
            Text("Now Playing").font(.radio(17, .heavy)).tracking(0.2)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").frame(width: 16, height: 20)
            }
            .buttonStyle(AetherBarButtonStyle())
            .accessibilityLabel("Close now playing")
            .accessibilityIdentifier("nowplaying.close")
        }
        .padding(.horizontal, AetherTheme.margin)
        .padding(.top, 24).padding(.bottom, 16)
    }

    private func trackDetails(for station: RadioStation) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Rectangle().fill(playback.state.isPlaying ? AetherTheme.accent : AetherTheme.mutedIcon)
                    .frame(width: 12, height: 3)
                Text(status).font(.radio(11, .heavy)).tracking(1.8)
            }
            .foregroundStyle(AetherTheme.accent)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("nowplaying.status")

            if let metadata = playback.nowPlayingMetadata,
               metadata.title != nil || metadata.artist != nil {
                if let title = metadata.title {
                    Text(title).font(.radio(.title2, .heavy))
                        .accessibilityIdentifier("nowplaying.songTitle")
                }
                if let artist = metadata.artist {
                    Text(artist).font(.radio(.subheadline))
                        .foregroundStyle(AetherTheme.secondaryText)
                        .accessibilityIdentifier("nowplaying.artist")
                }
                Text(station.name).font(.radio(.caption, .medium))
                    .foregroundStyle(AetherTheme.mutedIcon)
                    .accessibilityIdentifier("nowplaying.station")
            } else {
                Text(station.name).font(.radio(.title2, .bold))
                    .accessibilityIdentifier("nowplaying.station")
                if !station.groupTitle.isEmpty {
                    Text(station.groupTitle).font(.radio(.subheadline))
                        .foregroundStyle(AetherTheme.secondaryText)
                }
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
    }

    private var status: String {
        switch playback.state {
        case .playing: return "LIVE RADIO"
        case .loading: return "CONNECTING"
        case .paused: return "PAUSED"
        case .failed: return "CONNECTION FAILED"
        default: return "STOPPED"
        }
    }

    private var controlRow: some View {
        HStack(spacing: 24) {
            Button { playback.previousStation() } label: {
                Image(systemName: "backward.end.fill").font(.radio(22, .semibold))
                    .frame(width: NowPlayingLayout.skipButtonSize, height: NowPlayingLayout.skipButtonSize)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AetherTheme.divider, lineWidth: 1))
            }
            .accessibilityLabel("Previous station")
            .accessibilityIdentifier("nowplaying.previous")

            Button {
                if mainButtonIsStop {
                    playback.stop()
                    dismiss()
                } else {
                    playback.togglePlayPause()
                }
            } label: {
                Image(systemName: mainButtonIcon).font(.radio(28, .semibold))
                    .frame(width: NowPlayingLayout.transportButtonSize, height: NowPlayingLayout.transportButtonSize)
                    .foregroundStyle(AetherTheme.onAccent)
                    .background(AetherTheme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel(mainButtonLabel)
            .accessibilityIdentifier(mainButtonIsStop ? "nowplaying.stop" : "nowplaying.toggle")

            Button { playback.nextStation() } label: {
                Image(systemName: "forward.end.fill").font(.radio(22, .semibold))
                    .frame(width: NowPlayingLayout.skipButtonSize, height: NowPlayingLayout.skipButtonSize)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AetherTheme.divider, lineWidth: 1))
            }
            .accessibilityLabel("Next station")
            .accessibilityIdentifier("nowplaying.next")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var outputControls: some View {
        HStack(spacing: 24) {
            SleepTimerButton(showSheet: $showSleepTimerSheet)
                .frame(width: 44, height: 44)
            if settings.sonosOutputControl {
                RoutePickerButton().frame(width: 44, height: 44)
            } else if settings.bluetoothOutputControl {
                BluetoothRoutePickerButton().frame(width: 44, height: 44)
            }
            Button { playback.retry() } label: {
                Image(systemName: "arrow.clockwise").font(.radio(19, .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Retry connection")
            .accessibilityIdentifier("nowplaying.retry")
        }
        .buttonStyle(.plain)
        .foregroundStyle(AetherTheme.caption)
        .frame(maxWidth: .infinity)
    }

    private var mainButtonIcon: String {
        switch playback.state {
        case .playing, .loading: return "stop.fill"
        case .failed: return "arrow.clockwise"
        default: return "play.fill"
        }
    }
    private var mainButtonLabel: String {
        switch playback.state {
        case .playing, .loading: return "Stop"
        case .failed: return "Retry"
        default: return "Play"
        }
    }
    private var mainButtonIsStop: Bool {
        switch playback.state {
        case .playing, .loading: return true
        default: return false
        }
    }
}

/// Full-player geometry only; no audio, metadata or animation behavior.
enum NowPlayingLayout {
    static let transportButtonSize: CGFloat = 64
    static let skipButtonSize: CGFloat = 48
    static let controlRowGap: CGFloat = 8
    static let controlVerticalPadding: CGFloat = 12
    static let minimumRecordStageHeight: CGFloat = 160
    static let compactRecordDiameter: CGFloat = 160

    static func recordDiameter(in stage: CGSize) -> CGFloat {
        // The stage already has the page's 20-point horizontal margins.
        // Preserve the original disc's extra breathing room on each side.
        max(0, min(stage.width - 40, min(stage.height, 360)))
    }
}

/// Sleep timer trigger button with active-timer indicator.
struct SleepTimerButton: View {
    @EnvironmentObject private var playback: PlaybackEngine
    @Binding var showSheet: Bool

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: playback.sleepTimerDeadline == nil ? "moon.zzz" : "moon.zzz.fill")
                .font(.radio(.title3))
        }
        .accessibilityLabel("Sleep timer")
        .accessibilityIdentifier("nowplaying.sleepTimer")
    }
}

/// System AirPlay route picker for compatible Sonos and other speakers.
struct RoutePickerButton: View {
    var body: some View {
        AVRoutePickerViewRepresentable()
            .frame(width: 28, height: 28)
            .accessibilityLabel("Audio output route")
    }
}

/// System audio-output selector includes paired Bluetooth receivers. This
/// changes only the output route; it never restarts or replaces the stream.
struct BluetoothRoutePickerButton: View {
    var body: some View {
        BluetoothRoutePickerViewRepresentable()
            .frame(width: 28, height: 28)
            .accessibilityLabel("Bluetooth audio output")
    }
}

private struct BluetoothRoutePickerViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsVolumeSlider = false
        view.tintColor = AetherTheme.uiMutedIcon
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

struct AVRoutePickerViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = AetherTheme.uiMutedIcon
        view.activeTintColor = AetherTheme.uiAccent
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Sleep timer options sheet.
struct SleepTimerSheet: View {
    @EnvironmentObject private var playback: PlaybackEngine
    @Environment(\.dismiss) private var dismiss

    private let options: [Double] = [15, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            List {
                AetherSectionLabel(title: "Sleep timer", detail: "Switch off, drift off.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                Section {
                    ForEach(options, id: \.self) { minutes in
                        Button {
                            playback.startSleepTimer(minutes: minutes)
                            dismiss()
                        } label: {
                            Text("\(Int(minutes)) minutes")
                                .font(.radio(.body, .medium))
                        }
                    }
                }
                if playback.sleepTimerDeadline != nil {
                    Section {
                        Button(role: .destructive) {
                            playback.cancelSleepTimer()
                            dismiss()
                        } label: {
                            Text("Cancel sleep timer")
                                .font(.radio(.body, .medium))
                        }
                    }
                }
            }
            .radioSettingsList()
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .buttonStyle(AetherBarButtonStyle(prominent: true))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(AetherTheme.background)
        .tint(AetherTheme.accent)
    }
}
