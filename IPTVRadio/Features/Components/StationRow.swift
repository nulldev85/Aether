import SwiftUI

/// Directory rows and open station presets share playback actions, not layout.
/// Favorite and play are sibling buttons, so each keeps its own touch target.
struct StationRow: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var playback: PlaybackEngine
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var manualStations: ManualStationStore
    let station: RadioStation
    var preset = false
    var position: Int?

    private var displayedStation: RadioStation {
        station.source == .manual ? (manualStations.station(id: station.id) ?? station) : station
    }
    var isCurrent: Bool { playback.state.station?.id == station.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if preset {
                HStack {
                    Text(position.map { String(format: "%02d", $0) } ?? "")
                        .font(.radio(.caption, .medium)).foregroundStyle(AetherTheme.mutedIcon)
                    Spacer(minLength: 8)
                    favoriteButton
                }
                Button(action: play) {
                    VStack(alignment: .leading, spacing: 16) {
                        StationArtwork(logoURL: displayedStation.logoURL, size: 76)
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
                        stationText
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("station.row.\(station.name)")
                .accessibilityLabel(station.name)
                .accessibilityHint("Plays this station")
                AetherTheme.divider.frame(height: 0.5)
            } else {
                HStack(spacing: 12) {
                    Button(action: play) {
                        HStack(spacing: 16) {
                            StationArtwork(logoURL: displayedStation.logoURL, size: 36)
                                .frame(width: 40, height: 44)
                            stationText
                            Spacer(minLength: 0)
                            if isCurrent { stateIcon }
                        }
                        .frame(minHeight: 72).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("station.row.\(station.name)")
                    .accessibilityLabel(station.name)
                    .accessibilityHint("Plays this station")
                    favoriteButton
                }
                AetherTheme.divider.frame(height: 0.5)
            }
        }
        .listRowBackground(Color.clear).listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
    }

    private var stationText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(station.name).font(.radio(.subheadline, .bold))
                .foregroundStyle(AetherTheme.primaryText).lineLimit(2)
            if isCurrent {
                Label(playback.state.isPlaying ? "Playing" : "Selected", systemImage: "waveform")
                    .font(.radio(.caption)).foregroundStyle(AetherTheme.caption)
            } else if !station.groupTitle.isEmpty {
                Text(station.groupTitle).font(.radio(.caption))
                    .foregroundStyle(AetherTheme.secondaryText).lineLimit(1)
            }
        }
    }

    private var favoriteButton: some View {
        Button { favorites.toggle(displayedStation) } label: {
            Image(systemName: favorites.isFavorite(station) ? "star.fill" : "star")
                .font(.radio(16, .regular)).foregroundStyle(AetherTheme.mutedIcon)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(favorites.isFavorite(station) ? "Remove from favorites" : "Add to favorites")
        .accessibilityIdentifier("station.favorite.\(station.name)")
    }

    @ViewBuilder private var stateIcon: some View {
        if playback.state.isBusy { ProgressView().controlSize(.small) }
        else { Image(systemName: playback.state.isPlaying ? "waveform" : "pause.fill")
            .foregroundStyle(AetherTheme.mutedIcon).font(.radio(.caption)) }
    }

    private func play() {
        let fresh = station.source == .manual ? displayedStation : library.freshStation(matching: station)
        playback.play(fresh, in: nil)
        if let directoryID = fresh.directoryStationID {
            let service = AetherDialService(httpClient: environment.httpClient)
            Task { await service.registerClick(stationID: directoryID) }
        }
    }
}


/// A station's channel logo.
///
/// Provider logos are background-keyed once (see `LogoBackgroundKeyer`).
/// A fine adaptive edge shadow keeps pale marks legible without a logo tile.
struct StationArtwork: View {
    let logoURL: URL?
    var size: CGFloat = 52

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    // Fit, not fill: provider logos are often wide wordmarks,
                    // and filling crops them into a square.
                    .aspectRatio(contentMode: .fit)
                    .shadow(color: AetherTheme.logoShadow, radius: 1.2)
            } else if logoURL == nil || didFail {
                placeholder
            }
            // While loading, stay empty rather than flashing a grey plate.
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: logoURL) {
            // Reset first. This view keeps its position across station changes
            // (the mini player and the now playing screen both reuse it), so
            // leaving the previous station's image in place shows its logo for
            // the whole of the next station's fetch — and permanently, for a
            // station that has no logo at all and returns early below.
            image = nil
            didFail = false
            guard let logoURL else { return }
            let loaded = await ArtworkCache.shared.image(for: logoURL)
            image = loaded
            didFail = loaded == nil
        }
    }

    /// Only shown when there is no logo, or it could not be loaded.
    private var placeholder: some View {
        ZStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.radio(size * 0.38))
                .foregroundStyle(AetherTheme.mutedIcon)
        }
    }
}

/// Artwork used while playing: shows the current song's artwork when the
/// stream provides it, falling back to the channel logo otherwise.
/// (Channel logos remain unchanged everywhere else in the app.)
struct PlaybackArtwork: View {
    let station: RadioStation
    let songArtwork: UIImage?
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            if let songArtwork {
                Image(uiImage: songArtwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
            } else {
                StationArtwork(logoURL: station.logoURL, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Tiny in-memory artwork cache to avoid refetching logos while scrolling.
/// Channel logos are background-keyed once so they sit directly on the
/// browsing canvas.
actor ArtworkCache {
    static let shared = ArtworkCache()
    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 150
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
    private var failed: Set<URL> = []
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        if let image = cache.object(forKey: url as NSURL) { return image }
        if failed.contains(url) { return nil }
        if let existing = inFlight[url] { return await existing.value }

        let request = Task<UIImage?, Never> {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let image = UIImage(data: data) else { return nil }
                return LogoBackgroundKeyer.keyed(image)
            } catch {
                return nil
            }
        }
        inFlight[url] = request
        let image = await request.value
        inFlight[url] = nil
        if let image {
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            cache.setObject(image, forKey: url as NSURL, cost: cost)
        } else {
            failed.insert(url)
        }
        return image
    }
}
