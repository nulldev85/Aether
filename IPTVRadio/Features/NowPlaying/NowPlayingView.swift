import SwiftUI
import AVKit
import MediaPlayer

/// Lineup's neutral panels and rounded controls around Aether's original disc.
struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var playback: PlaybackEngine
    @EnvironmentObject private var settings: SettingsStore
    @State private var showSleepTimerSheet = false
    @State private var stationLogo: UIImage?

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                if let station = playback.state.station {
                    ScrollView {
                        VStack(spacing: 24) {
                            VinylRecordView(
                                artwork: playback.nowPlayingMetadata?.artworkImage ?? stationLogo,
                                isSpinning: playback.state.isPlaying && scenePhase == .active && !reduceMotion
                            )
                            .frame(width: recordSize(in: proxy.size), height: recordSize(in: proxy.size))
                            .padding(.top, 12)

                            trackDetails(for: station)
                            VStack(spacing: 20) {
                                controlRow
                                outputControls
                            }
                            .padding(20)
                            .frame(maxWidth: 440)
                            .background(AetherTheme.surface, in: RoundedRectangle(cornerRadius: AetherTheme.panelRadius, style: .continuous))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AetherTheme.margin)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
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
        }
        .foregroundStyle(AetherTheme.primaryText)
        .background(AetherTheme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSleepTimerSheet) { SleepTimerSheet() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AetherIconTile(symbol: "music.note")
            Text("Now Playing").font(.radio(17, .heavy))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").frame(width: 16, height: 20)
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
                Circle().fill(playback.state.isPlaying ? AetherTheme.accent : AetherTheme.mutedIcon)
                    .frame(width: 6, height: 6)
                Text(status).font(.radio(12, .bold)).tracking(0.6)
            }
            .foregroundStyle(AetherTheme.caption)
            .accessibilityIdentifier("nowplaying.status")

            if let metadata = playback.nowPlayingMetadata,
               metadata.title != nil || metadata.artist != nil {
                if let title = metadata.title {
                    Text(title).font(.radio(.title2, .bold))
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

    private func recordSize(in size: CGSize) -> CGFloat {
        max(120, min(size.width - 80, size.height * 0.38))
    }

    private var controlRow: some View {
        HStack(spacing: 24) {
            Button { playback.previousStation() } label: {
                Image(systemName: "backward.end.fill").font(.radio(22, .semibold))
                    .frame(width: 52, height: 52)
                    .background(AetherTheme.selected, in: Circle())
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
                    .frame(width: 76, height: 76)
                    .foregroundStyle(.white)
                    .background(AetherTheme.accent, in: Circle())
            }
            .accessibilityLabel(mainButtonLabel)
            .accessibilityIdentifier(mainButtonIsStop ? "nowplaying.stop" : "nowplaying.toggle")

            Button { playback.nextStation() } label: {
                Image(systemName: "forward.end.fill").font(.radio(22, .semibold))
                    .frame(width: 52, height: 52)
                    .background(AetherTheme.selected, in: Circle())
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
