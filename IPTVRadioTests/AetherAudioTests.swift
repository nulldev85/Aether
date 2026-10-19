import XCTest
import AVFoundation
@testable import IPTVRadio

final class ICYAudioParserTests: XCTestCase {
    func testMetadataSplitAtEveryByteNeverEntersTheAudio() {
        let title = "StreamTitle='Artist - Song';"
        let padded = title + String(repeating: "\0", count: 32 - title.utf8.count)
        let input = Data("abcd".utf8) + Data([2]) + Data(padded.utf8) + Data("efgh".utf8) + Data([0]) + Data("ijkl".utf8)
        for width in 1...input.count {
            var parser = ICYAudioParser(interval: 4)
            var audio = Data()
            var titles: [String] = []
            for offset in stride(from: 0, to: input.count, by: width) {
                let parsed = parser.consume(input.subdata(in: offset..<min(input.count, offset + width)))
                audio.append(parsed.audio)
                titles.append(contentsOf: parsed.titles)
            }
            XCTAssertEqual(audio, Data("abcdefghijkl".utf8), "chunk width \(width)")
            XCTAssertEqual(titles, ["Artist - Song"])
        }
    }

    func testNoMetadataHeaderKeepsEveryByte() {
        var parser = ICYAudioParser(interval: 0)
        let bytes = Data([0, 1, 2, 3, 255])
        XCTAssertEqual(parser.consume(bytes).audio, bytes)
    }
}

final class RadioStreamReaderTests: XCTestCase {
    func testReserveUsesSourceBitrateAndBoundsMalformedInputs() {
        XCTAssertEqual(RadioStreamReader.reserveByteCount(seconds: 4, bitrate: 128_000), 64_000)
        XCTAssertEqual(RadioStreamReader.reserveByteCount(seconds: 12, bitrate: 128_000), 192_000)
        XCTAssertEqual(RadioStreamReader.reserveByteCount(seconds: 30, bitrate: Double(Int64.max)), 2 * 1024 * 1024)
        XCTAssertEqual(RadioStreamReader.reserveByteCount(seconds: .nan, bitrate: .infinity), 96_000)
    }

    private func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }

    func testReaderDeliversEveryByteAndFiniteEOF() async {
        let payload = Data((0..<24000).map { UInt8($0 % 251) })
        MockURLProtocol.requestHandler = { _ in (200, payload) }
        let reader = RadioStreamReader(url: URL(string: "https://fixture.invalid/radio")!, configuration: configuration(), onTitle: { _ in }, onWaiting: {})
        reader.start()
        defer { reader.close() }
        let result: Data = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var result = Data()
                var buffer = [UInt8](repeating: 0, count: 701)
                while true {
                    let count = buffer.withUnsafeMutableBufferPointer { reader.read($0.baseAddress, size: Int32($0.count)) }
                    if count <= 0 { break }
                    result.append(contentsOf: buffer.prefix(Int(count)))
                }
                continuation.resume(returning: result)
            }
        }
        XCTAssertEqual(result, payload)
        XCTAssertEqual(reader.bytesDelivered, Int64(payload.count))
        XCTAssertEqual(reader.seek(offset: 0, whence: 0), -1)
        XCTAssertFalse(reader.discImageProbeEnabled)
    }

    func testCancellationUnblocksReadWithoutWaitingForTheNetworkTimeout() async {
        let waiting = expectation(description: "reader is waiting")
        waiting.assertForOverFulfill = false
        let returned = expectation(description: "cancelled reader returned")
        let reader = RadioStreamReader(url: URL(string: "https://fixture.invalid/radio")!, onTitle: { _ in }, onWaiting: { waiting.fulfill() })
        DispatchQueue.global().async {
            var byte: UInt8 = 0
            XCTAssertEqual(reader.read(&byte, size: 1), -1)
            returned.fulfill()
        }
        await fulfillment(of: [waiting], timeout: 2)
        reader.cancel()
        await fulfillment(of: [returned], timeout: 2)
    }

    func testHTTPRefusalIsAnErrorRatherThanAudioOrCleanEOF() async {
        MockURLProtocol.requestHandler = { _ in (403, Data("not audio".utf8)) }
        let reader = RadioStreamReader(url: URL(string: "https://fixture.invalid/radio")!, configuration: configuration(), onTitle: { _ in }, onWaiting: {})
        reader.start()
        defer { reader.close() }
        let result: Int32 = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var byte: UInt8 = 0
                continuation.resume(returning: reader.read(&byte, size: 1))
            }
        }
        XCTAssertEqual(result, -1)
    }
}

@MainActor
final class AetherAudioTests: XCTestCase {
    func testPlaybackAcknowledgementsAreActuallyBundled() {
        let names = Set(PlaybackLicenseFiles.entries.map(\.name))
        XCTAssertTrue(names.isSuperset(of: ["AetherEngine", "GPL-3.0", "FFmpegBuild", "FFmpeg-LGPL-2.1", "LibDovi"]))
    }

    func testConfigurationDisablesVideoAndKeepsAppNowPlayingOwnership() {
        let options = AetherPlayerAdapter.options()
        XCTAssertTrue(options.audioOnly)
        XCTAssertTrue(options.isLive)
        XCTAssertFalse(options.autoplay)
        XCTAssertTrue(options.suppressDisplayCriteria)
        XCTAssertFalse(options.matchContentEnabled)
        XCTAssertEqual(options.sharedOutputRole, .secondary)
        XCTAssertEqual(options.maxConcurrentSourceRequests, 1)
        XCTAssertNil(options.dvrWindowSeconds)
    }

    func testTimedMetadataUsesSongTagsAndIgnoresStationDescription() {
        let title = AVMutableMetadataItem()
        title.identifier = .commonIdentifierTitle
        title.value = "Artist - Track" as NSString
        let description = AVMutableMetadataItem()
        description.identifier = .commonIdentifierDescription
        description.value = "Station name" as NSString
        let result = AetherPlayerAdapter.timedMetadata([description, title])
        XCTAssertEqual(result.title, "Track")
        XCTAssertEqual(result.artist, "Artist")
    }

    /// Exercises the actual upstream demuxer, PCM decoder, audio renderer and
    /// clock. MockAudioPlayer/UI-test mode is deliberately not involved.
    func testRealEnginePlaysPCMThroughTheAudioOnlyPipeline() async throws {
        let fixture = Self.wave(seconds: 16)
        MockURLProtocol.requestHandler = { _ in (200, fixture) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let player = AetherPlayerAdapter(httpConfiguration: configuration)
        let ready = expectation(description: "real audio renderer started")
        let diagnostics = expectation(description: "source format measured")
        diagnostics.assertForOverFulfill = false
        player.onReady = { ready.fulfill() }
        player.onFailure = { message in XCTFail(message); ready.fulfill() }
        player.onDiagnostics = { sample in
            if sample.audioFormat?.contains("16.0 kHz") == true {
                XCTAssertEqual(sample.playbackEngine, "AetherEngine 7.38.1")
                XCTAssertEqual(sample.playbackRoute, "Audio only · FFmpeg → PCM")
                diagnostics.fulfill()
            }
        }
        defer { player.stop() }
        // Supersede a load before its queued main-actor task can open media.
        // It must never replace the successor or emit a late failure/ready.
        player.load(url: URL(string: "https://fixture.invalid/abandoned.mp3")!, bufferDuration: 4)
        player.load(url: URL(string: "https://fixture.invalid/radio.wav")!, bufferDuration: 4)
        await fulfillment(of: [ready, diagnostics], timeout: 30)
        XCTAssertTrue(player.usesAudioOnlyPipeline)
        XCTAssertGreaterThan(player.playbackProgress ?? 0, 0)
        player.pause()
        player.play()
        player.stop()
        XCTAssertNil(player.playbackProgress)
    }

    private static func wave(seconds: Int) -> Data {
        let rate = 16000
        let count = rate * seconds
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { data.append(UInt8(value & 255)); data.append(UInt8(value >> 8)) }
        func u32(_ value: UInt32) { u16(UInt16(value & 65535)); u16(UInt16(value >> 16)) }
        text("RIFF"); u32(UInt32(36 + count * 2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        text("data"); u32(UInt32(count * 2))
        for index in 0..<count {
            let sample = Int16(sin(Double(index) * 2 * .pi * 440 / Double(rate)) * 1000)
            u16(UInt16(bitPattern: sample))
        }
        return data
    }

    func testRealEnginePlaysOriginalAACTransportStreamWithoutNativeHLSFallback() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "aether-audio", withExtension: "ts"),
                                "Run bash scripts/make-audio-fixture.sh before the tests")
        let fixture = try Data(contentsOf: url)
        let streamURL = URL(string: "https://fixture.invalid/live/original.ts")!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, streamURL, "Interruption recovery must retain the exact source URL")
            return (200, fixture)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let player = AetherPlayerAdapter(httpConfiguration: configuration)
        let ready = expectation(description: "AAC-in-TS renderer started")
        let diagnostics = expectation(description: "original AAC track identified")
        diagnostics.assertForOverFulfill = false
        player.onReady = { ready.fulfill() }
        player.onFailure = { message in XCTFail(message); ready.fulfill() }
        player.onDiagnostics = { sample in
            if sample.audioFormat?.contains("AAC") == true {
                XCTAssertEqual(sample.streamExtension, "ts")
                XCTAssertEqual(sample.playbackRoute, "Audio only · FFmpeg → PCM")
                diagnostics.fulfill()
            }
        }
        defer { player.stop() }
        player.load(url: streamURL, bufferDuration: 4)
        await fulfillment(of: [ready, diagnostics], timeout: 30)
        XCTAssertTrue(player.usesAudioOnlyPipeline)
        XCTAssertGreaterThan(player.playbackProgress ?? 0, 0)
        let resumed = expectation(description: "fresh audio-only renderer recovered after interruption")
        player.onReady = { resumed.fulfill() }
        player.onFailure = { message in XCTFail(message); resumed.fulfill() }
        player.pause()
        player.resumeAfterInterruption()
        XCTAssertNil(player.interruptionRecoveryProgress, "Network intake cannot certify a new renderer before load")
        await fulfillment(of: [resumed], timeout: 30)
        XCTAssertTrue(player.usesAudioOnlyPipeline)
        XCTAssertGreaterThan(player.interruptionRecoveryProgress ?? 0, 0)
    }
}
