import SwiftUI
import AVKit

/// Compact mini player shown above the tab bar while a station is loaded.
/// Owns no presentation state: opening the full player is delegated upward.
struct MiniPlayerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var playback: PlaybackEngine
    @State private var stationLogo: UIImage?

    let onOpen: () -> Void

    var body: some View {
        Group {
            if let station = playback.state.station {
                HStack(spacing: 8) {
                    Button {
                        onOpen()
                    } label: {
                        HStack(spacing: 12) {
                            VinylRecordView(
                                artwork: playback.nowPlayingMetadata?.artworkImage ?? stationLogo,
                                isSpinning: playback.state.isPlaying && scenePhase == .active && !reduceMotion
                            )
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(playback.nowPlayingMetadata?.title ?? station.name)
                                    .font(.radio(.subheadline, .bold))
                                    .foregroundStyle(AetherTheme.primaryText)
                                    .lineLimit(1)
                                Text(playback.nowPlayingMetadata?.artist ?? stateDescription)
                                    .font(.radio(.caption2))
                                    .foregroundStyle(AetherTheme.accentSoft)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("miniplayer.open")
                    .accessibilityLabel("Open now playing screen")
                    .accessibilityHint("Opens the full now playing controls")

                    if playback.state.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AetherTheme.accent)
                    }

                    Button {
                        playback.togglePlayPause()
                    } label: {
                        Image(systemName: iconName)
                            .font(.radio(18, .bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(AetherTheme.onAccent)
                            .background(AetherTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel(toggleAccessibilityLabel)
                    .accessibilityIdentifier("miniplayer.toggle")

                    Button {
                        playback.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.radio(14, .semibold))
                            .foregroundStyle(AetherTheme.mutedIcon)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Stop")
                    .accessibilityIdentifier("miniplayer.stop")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .foregroundStyle(AetherTheme.primaryText)
                .background(AetherTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(AetherTheme.accent)
                        .frame(width: 2, height: 26).padding(.leading, 1)
                }
                .padding(.horizontal, AetherTheme.margin)
                .task(id: station.id) {
                    stationLogo = nil
                    guard let url = station.logoURL else { return }
                    stationLogo = await ArtworkCache.shared.image(for: url)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: playback.state.station?.id)
    }

    private var iconName: String {
        switch playback.state {
        case .playing: return "pause.fill"
        case .loading: return "arrow.clockwise"
        case .failed: return "arrow.clockwise"
        case .paused, .stopped: return "play.fill"
        default: return "play.fill"
        }
    }

    private var toggleAccessibilityLabel: String {
        switch playback.state {
        case .playing: return "Pause"
        case .loading: return "Retry"
        case .failed: return "Retry"
        default: return "Play"
        }
    }

    private var stateDescription: String {
        switch playback.state {
        case .playing: return "Playing live"
        case .paused: return "Paused"
        case .loading: return "Connecting…"
        case .failed: return "Connection failed — tap to retry"
        case .stopped: return "Stopped"
        case .idle: return ""
        }
    }
}
