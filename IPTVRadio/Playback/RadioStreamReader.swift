import Foundation
import AetherAudioRuntime

/// Removes ICY blocks from a streaming response, including when a callback
/// splits the length byte, metadata, or the next audio interval.
struct ICYAudioParser {
    private let interval: Int
    private var audioRemaining: Int
    private var metadataRemaining = 0
    private var awaitingLength = false
    private var metadata = Data()

    init(interval: Int) {
        self.interval = max(0, interval)
        audioRemaining = max(0, interval)
    }

    mutating func consume(_ input: Data) -> (audio: Data, titles: [String]) {
        guard interval > 0 else { return (input, []) }
        let bytes = Array(input)
        var position = 0
        var audio = Data()
        var titles: [String] = []
        while position < bytes.count {
            if awaitingLength {
                metadataRemaining = Int(bytes[position]) * 16
                position += 1
                awaitingLength = false
                metadata.removeAll(keepingCapacity: true)
                if metadataRemaining == 0 { audioRemaining = interval }
            } else if metadataRemaining > 0 {
                let count = min(metadataRemaining, bytes.count - position)
                metadata.append(contentsOf: bytes[position..<(position + count)])
                metadataRemaining -= count
                position += count
                if metadataRemaining == 0 {
                    let text = String(data: metadata, encoding: .utf8)
                        ?? String(data: metadata, encoding: .isoLatin1) ?? ""
                    if let start = text.range(of: "StreamTitle='", options: .caseInsensitive),
                       let end = text.range(of: "';", range: start.upperBound..<text.endIndex) {
                        let title = String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !title.isEmpty { titles.append(title) }
                    }
                    audioRemaining = interval
                }
            } else {
                let count = min(audioRemaining, bytes.count - position)
                audio.append(contentsOf: bytes[position..<(position + count)])
                audioRemaining -= count
                position += count
                if audioRemaining == 0 { awaitingLength = true }
            }
        }
        return (audio, titles)
    }
}

/// Forward-only HTTP source for AetherEngine's custom audio-only path. This
/// avoids handing an AAC-in-MPEG-TS URL back to AVPlayer on codec alone.
/// One bounded queue, no video decoder, no disk cache, no local HLS server.
final class RadioStreamReader: NSObject, RadioAudioRuntime.ByteReader, URLSessionDataDelegate, @unchecked Sendable {
    private let condition = NSCondition()
    private let url: URL
    private let configuration: URLSessionConfiguration
    private let maximumBytes = 4 * 1024 * 1024
    private var chunks: [Data] = []
    private var head = 0
    private var headOffset = 0
    private var queuedBytes = 0
    private var deliveredBytes: Int64 = 0
    private var ended = false
    private var cancelled = false
    private var failed = false
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var parser = ICYAudioParser(interval: 0)
    private var declaredBitrate: Double?
    private let onTitle: @Sendable (String) -> Void
    private let onWaiting: @Sendable () -> Void

    init(url: URL, configuration: URLSessionConfiguration = .ephemeral,
         onTitle: @escaping @Sendable (String) -> Void,
         onWaiting: @escaping @Sendable () -> Void) {
        self.url = url
        self.configuration = configuration
        self.onTitle = onTitle
        self.onWaiting = onWaiting
    }

    var discImageProbeEnabled: Bool { false }
    var bytesDelivered: Int64 { condition.lock(); defer { condition.unlock() }; return deliveredBytes }

    func start() {
        condition.lock()
        guard task == nil, !cancelled else { condition.unlock(); return }
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        configuration.urlCache = nil
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        var request = RequestBuilder.get(url, timeout: 30, userAgent: RequestBuilder.browserUserAgent)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        let task = session.dataTask(with: request)
        self.session = session
        self.task = task
        condition.unlock()
        task.resume()
    }

    func read(_ buffer: UnsafeMutablePointer<UInt8>?, size: Int32) -> Int32 {
        guard let buffer, size > 0 else { return -1 }
        condition.lock()
        let deadline = Date(timeIntervalSinceNow: 30)
        while queuedBytes == 0 && !ended && !cancelled {
            condition.unlock()
            onWaiting()
            condition.lock()
            if queuedBytes == 0 && !ended && !cancelled && !condition.wait(until: deadline) {
                failed = true; ended = true
            }
        }
        guard !cancelled else { condition.unlock(); return -1 }
        guard queuedBytes > 0 else {
            let result: Int32 = failed ? -1 : 0
            condition.unlock()
            return result
        }
        let count = min(Int(size), chunks[head].count - headOffset)
        chunks[head].withUnsafeBytes { raw in
            buffer.update(from: raw.bindMemory(to: UInt8.self).baseAddress!.advanced(by: headOffset), count: count)
        }
        headOffset += count
        queuedBytes -= count
        deliveredBytes += Int64(count)
        if headOffset == chunks[head].count {
            // Release the payload immediately; waiting for the array's next
            // compaction could retain 64 already-consumed large deliveries.
            chunks[head] = Data()
            head += 1; headOffset = 0
            if head >= 64 { chunks.removeFirst(head); head = 0 }
        }
        condition.broadcast()
        condition.unlock()
        return Int32(count)
    }

    func seek(offset: Int64, whence: Int32) -> Int64 { -1 }

    /// Wait off-main before starting the renderer. icy-br or the probed audio
    /// bitrate sizes the compressed reserve; undeclared rates use 192 kbps as
    /// an estimate. The reserve is capped in bytes and bounded by a deadline.
    func prime(seconds: TimeInterval, bitrate: Double?) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        let target = Self.reserveByteCount(seconds: seconds, bitrate: declaredBitrate ?? bitrate)
        let duration = seconds.isFinite ? min(max(seconds, 0), 30) : 4
        let deadline = Date(timeIntervalSinceNow: duration + 5)
        while queuedBytes < target && !ended && !cancelled {
            if !condition.wait(until: deadline) { break }
        }
        return !cancelled && (!failed || queuedBytes > 0)
    }

    static func reserveByteCount(seconds: TimeInterval, bitrate: Double?) -> Int {
        let rate = bitrate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 192_000
        let duration = seconds.isFinite ? min(max(seconds, 0), 30) : 4
        // Clamp as Double before converting: a corrupt codec bitrate can be
        // Int64.max and must not overflow an Int conversion or allocation.
        return Int(min(Double(2 * 1024 * 1024), max(1, rate / 8 * duration)))
    }

    func cancel() {
        condition.lock()
        cancelled = true
        let session = session
        self.session = nil
        task = nil
        chunks.removeAll(); head = 0; headOffset = 0; queuedBytes = 0
        condition.broadcast()
        condition.unlock()
        session?.invalidateAndCancel()
    }

    func close() { cancel() }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            condition.lock(); failed = true; ended = true; condition.broadcast(); condition.unlock()
            completionHandler(.cancel)
            return
        }
        parser = ICYAudioParser(interval: Int(response.value(forHTTPHeaderField: "icy-metaint") ?? "") ?? 0)
        condition.lock()
        declaredBitrate = Double(response.value(forHTTPHeaderField: "icy-br") ?? "").flatMap { $0 > 0 && $0 < 10_000 ? $0 * 1000 : nil }
        condition.unlock()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let parsed = parser.consume(data)
        for title in parsed.titles { onTitle(title) }
        // Split large delegate deliveries so even a single callback cannot
        // exceed the queue cap. Cancellation wakes a backpressured producer.
        var offset = 0
        while offset < parsed.audio.count {
            condition.lock()
            while queuedBytes >= maximumBytes && !cancelled { condition.wait() }
            guard !cancelled else { condition.unlock(); return }
            let count = min(maximumBytes - queuedBytes, parsed.audio.count - offset)
            chunks.append(parsed.audio.subdata(in: offset..<(offset + count)))
            queuedBytes += count
            offset += count
            condition.broadcast()
            condition.unlock()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        condition.lock()
        ended = true
        failed = failed || (error != nil && !cancelled)
        condition.broadcast()
        condition.unlock()
        session.finishTasksAndInvalidate()
    }
}
