import Foundation
import AVFoundation
import Combine
import AetherAudioRuntime

/// Radio uses the engine's audio-only host, not a hidden video player. The
/// application retains its own Now Playing, metadata and recovery state.
@MainActor
final class AetherPlayerAdapter: NSObject, AudioPlayerControlling, AVPlayerItemMetadataOutputPushDelegate {
    var onReady: (() -> Void)?
    var onFailure: ((String) -> Void)?
    var onEnded: (() -> Void)?
    var onDiagnostics: ((StreamDiagnosticsSample) -> Void)?
    var onMetadata: ((StreamMetadataUpdate) -> Void)?
    var onStalled: (() -> Void)?
    var onPlaybackResumed: (() -> Void)?

    private var engine: RadioAudioRuntime.Engine?
    private var reader: RadioStreamReader?
    private var loadTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    private var generation = UUID()
    private var wantsPlayback = false
    private var reportedReady = false
    private var terminal = false
    private var loading = false
    private var streamExtension = ""
    private var requestedBuffer: TimeInterval = 4
    private var activeURL: URL?
    private var nativeHLSFallback = false
    private var lastProgress: Double = 0
    private var staleSince = Date()
    private var reportedStall = false
    private var lastSample: StreamDiagnosticsSample?
    private let httpConfiguration: URLSessionConfiguration
    private var registeredURLs = Set<String>()
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private weak var metadataItem: AVPlayerItem?

    init(httpConfiguration: URLSessionConfiguration = .ephemeral) {
        self.httpConfiguration = httpConfiguration
        super.init()
    }

    var usesAudioOnlyPipeline: Bool { engine?.videoRoute == .audio }

    var startupGracePeriod: TimeInterval { 8 }
    var engineName: String { "AetherEngine 7.38.1" }
    var playbackProgress: Double? {
        guard activeURL != nil, !loading, !terminal, let engine else { return nil }
        // The FFmpeg audio host's clock can keep running while a read is
        // blocked. Bytes consumed by its demuxer prove progress; wall time does not.
        if let reader { return Double(reader.bytesDelivered) }
        return engine.currentTime.isFinite ? engine.currentTime : nil
    }

    static func options() -> RadioAudioRuntime.Options {
        var options = RadioAudioRuntime.Options()
        options.audioOnly = true
        options.isLive = true
        options.autoplay = false
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        // Keep the app's existing MPNowPlayingInfoCenter/remote commands as
        // the sole owner, including on a native HLS compatibility route.
        options.sharedOutputRole = .secondary
        options.preferredAudioLanguages = ["en", "eng"]
        options.maxConcurrentSourceRequests = 1
        return options
    }

    func load(url: URL, bufferDuration: TimeInterval) {
        stop()
        activeURL = url
        streamExtension = url.pathExtension.lowercased()
        requestedBuffer = StreamBuffer.clampedCellularDuration(bufferDuration)
        wantsPlayback = true
        loading = true
        let token = generation
        if registeredURLs.insert(url.absoluteString).inserted {
            // Opaque provider URLs can put credentials outside standard query
            // fields. Keep each registration for this app session, including
            // while a stopped reader's asynchronous teardown finishes.
            RadioAudioRuntime.registerSecret(url.absoluteString)
        }
        do {
            if engine == nil { engine = try RadioAudioRuntime.Engine() }
        } catch {
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.fail("The audio engine could not be initialized.")
            }
            return
        }
        guard let engine else { return }
        engine.backgroundPlaybackEnabled = true
        observe(engine, token: token)
        let source: RadioAudioRuntime.Source
        if streamExtension == "m3u8" {
            // Upstream recognizes live HLS, ingests its media, and passes a
            // custom source to the same lean audio host. Unsupported carriage
            // (such as fMP4) may require the native compatibility route below.
            source = .url(url)
        } else {
            let reader = RadioStreamReader(url: url, configuration: httpConfiguration, onTitle: { [weak self] title in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    let update = StreamMetadataParser.splittingCombinedTitle(
                        StreamMetadataUpdate(title: title, artist: nil, artworkData: nil))
                    self.onMetadata?(update)
                }
            }, onWaiting: {})
            self.reader = reader
            reader.start()
            source = .custom(reader, formatHint: nil)
        }
        startLoad(engine, source: source, options: Self.options(), token: token)
    }

    private func startLoad(_ engine: RadioAudioRuntime.Engine, source: RadioAudioRuntime.Source,
                           options: RadioAudioRuntime.Options, token: UUID) {
        loadTask = Task { [weak self] in
            guard let self, self.generation == token, !Task.isCancelled else { return }
            do {
                _ = try await engine.load(source: source, options: options)
                guard self.generation == token, !Task.isCancelled else { return }
                if let reader = self.reader {
                    let bitrate = self.selectedTrack.map { Double($0.bitrate) }
                    let seconds = self.requestedBuffer
                    let primed = await withCheckedContinuation { continuation in
                        DispatchQueue.global(qos: .userInitiated).async {
                            continuation.resume(returning: reader.prime(seconds: seconds, bitrate: bitrate))
                        }
                    }
                    guard self.generation == token, !Task.isCancelled else { return }
                    guard primed else { self.fail("The radio stream stopped sending audio."); return }
                }
                // Aether declares a video-oriented category while loading;
                // restore the app's long-form audio category after that await.
                try AVAudioSessionAdapter().activateForPlayback()
                guard self.generation == token, !Task.isCancelled else { return }
                if self.nativeHLSFallback, let item = engine.currentAVPlayerItem {
                    item.preferredForwardBufferDuration = self.requestedBuffer
                    item.preferredPeakBitRate = 0
                    item.tracks.filter { $0.assetTrack?.mediaType == .video }.forEach { $0.isEnabled = false }
                }
                self.loading = false
                self.staleSince = Date()
                if self.wantsPlayback { engine.play() } else { engine.pause() }
                self.publishDiagnostics()
            } catch is CancellationError {
            } catch {
                guard self.generation == token, !Task.isCancelled else { return }
                self.failOrUseNativeHLS()
            }
        }
    }

    private func observe(_ engine: RadioAudioRuntime.Engine, token: UUID) {
        engine.$state.receive(on: DispatchQueue.main).sink { [weak self] state in
            guard let self, self.generation == token, !self.terminal else { return }
            switch state {
            case .error: self.failOrUseNativeHLS()
            case .ended:
                guard !self.loading else { return }
                self.terminal = true
                self.onEnded?()
            default: break
            }
        }.store(in: &subscriptions)
        Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.generation == token else { return }
            self.tick()
        }.store(in: &subscriptions)
    }

    private var selectedTrack: RadioAudioRuntime.Track? {
        guard let engine else { return nil }
        return engine.audioTracks.first { $0.id == engine.activeAudioTrackIndex } ?? engine.audioTracks.first
    }

    private func tick() {
        guard let engine, !loading, !terminal, wantsPlayback else { return }
        if nativeHLSFallback, let item = engine.currentAVPlayerItem {
            // Tracks may arrive after load() returns. Disable video each time
            // the actual item acquires tracks, rather than trusting that first snapshot.
            item.tracks.filter { $0.assetTrack?.mediaType == .video }.forEach { $0.isEnabled = false }
            if metadataItem !== item {
                detachMetadata()
                let output = AVPlayerItemMetadataOutput(identifiers: nil)
                output.setDelegate(self, queue: .main)
                item.add(output)
                metadataItem = item
                metadataOutput = output
            }
        }
        let progress = playbackProgress ?? 0
        let moving = progress > lastProgress
        lastProgress = progress
        if engine.isSessionReady && moving && engine.currentTime > 0 {
            if !reportedReady { reportedReady = true; onReady?() }
            if reportedStall { reportedStall = false; onPlaybackResumed?() }
            staleSince = Date()
        } else if reportedReady && (engine.isBuffering || Date().timeIntervalSince(staleSince) > 2), !reportedStall {
            reportedStall = true
            onStalled?()
        }
        publishDiagnostics()
    }

    private func failOrUseNativeHLS() {
        guard !terminal else { return }
        let kind = engine?.errorInfo?.kind.rawValue
        let refusal = ["sourceRefused", "sourceRateLimited", "sourceCertificateRejected"].contains(kind ?? "")
        if streamExtension == "m3u8", !refusal, !nativeHLSFallback, let engine, let url = activeURL {
            nativeHLSFallback = true
            loading = true
            lastProgress = 0
            lastSample = nil
            if reportedReady {
                reportedStall = true
                onStalled?()
            }
            loadTask?.cancel()
            // Retire callbacks from the failed load before constructing a
            // compatibility load; an old published error must not reject it.
            generation = UUID()
            let token = generation
            subscriptions.removeAll()
            engine.stop()
            observe(engine, token: token)
            var options = Self.options()
            options.nativeRemoteHLS = true
            options.nativeRemoteHLSIngestFallback = false
            startLoad(engine, source: .url(url), options: options, token: token)
        } else {
            fail("Could not play this radio stream.")
        }
    }

    private func fail(_ message: String) {
        guard !terminal else { return }
        terminal = true
        loading = false
        reader?.cancel()
        engine?.stop()
        onFailure?(message)
    }

    private func publishDiagnostics() {
        let track = selectedTrack
        var format: [String] = []
        if let codec = track?.codec { format.append(codec.uppercased()) }
        if let rate = track?.sampleRate, rate > 0 { format.append(String(format: "%.1f kHz", Double(rate) / 1000)) }
        if let channels = track?.channels, channels > 0 { format.append(channels == 1 ? "mono" : channels == 2 ? "stereo" : "\(channels) ch") }
        let trackRate = track.flatMap { $0.bitrate > 0 ? Double($0.bitrate) : nil }
        let sample = StreamDiagnosticsSample(
            streamExtension: streamExtension, indicatedBitrate: nil, observedBitrate: nil,
            averageAudioBitrate: nil, audioTrackDataRate: trackRate, mediaRequests: nil,
            audioFormat: format.isEmpty ? nil : format.joined(separator: " · "),
            playbackEngine: engineName,
            playbackRoute: usesAudioOnlyPipeline ? "Audio only · FFmpeg → PCM" : "Native HLS compatibility",
            bufferIsEstimated: true)
        guard sample != lastSample else { return }
        lastSample = sample
        onDiagnostics?(sample)
    }

    func play() { wantsPlayback = true; staleSince = Date(); if !loading { engine?.play() } }
    func pause() { wantsPlayback = false; engine?.pause() }
    func stop() {
        generation = UUID()
        wantsPlayback = false
        terminal = false
        loading = false
        reportedReady = false
        reportedStall = false
        nativeHLSFallback = false
        lastProgress = 0
        lastSample = nil
        activeURL = nil
        detachMetadata()
        loadTask?.cancel(); loadTask = nil
        subscriptions.removeAll()
        reader?.close(); reader = nil
        engine?.stop()
    }

    private func detachMetadata() {
        if let output = metadataOutput { metadataItem?.remove(output) }
        metadataOutput = nil
        metadataItem = nil
    }

    nonisolated func metadataOutput(_ output: AVPlayerItemMetadataOutput,
                                    didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                                    from track: AVPlayerItemTrack?) {
        let update = Self.timedMetadata(groups.flatMap(\.items))
        Task { @MainActor [weak self] in
            guard let self, self.metadataOutput === output, !update.isEmpty else { return }
            self.onMetadata?(update)
        }
    }

    nonisolated static func timedMetadata(_ items: [AVMetadataItem]) -> StreamMetadataUpdate {
        var update = StreamMetadataUpdate(title: nil, artist: nil, artworkData: nil)
        for item in items {
            switch item.commonKey {
            case .commonKeyTitle: update.title = item.stringValue
            case .commonKeyArtist: update.artist = item.stringValue
            case .commonKeyArtwork: update.artworkData = item.dataValue
            default: break
            }
        }
        return StreamMetadataParser.splittingCombinedTitle(update)
    }

    deinit {
        loadTask?.cancel()
        reader?.close()
        let engine = engine
        Task { @MainActor in engine?.stop() }
    }
}
