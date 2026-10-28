import XCTest
@testable import IPTVRadio

final class ArtworkLookupServiceTests: XCTestCase {
    private var logoData: Data {
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
    }

    func testLogoRequestsShareOneLoadAndCacheTheResult() async {
        let counter = RequestCounter()
        let data = logoData
        let http = MockHTTP.client { request in
            counter.increment()
            XCTAssertEqual(request.timeoutInterval, 12)
            return (200, data)
        }
        let cache = ArtworkCache(http: http)
        let url = URL(string: "https://art.example/station.png")!
        async let first = cache.image(for: url)
        async let second = cache.image(for: url)
        let images = await (first, second)
        XCTAssertNotNil(images.0)
        XCTAssertNotNil(images.1)
        let cached = await cache.image(for: url)
        XCTAssertNotNil(cached)
        XCTAssertEqual(counter.value, 1)
    }

    func testLogoFailureBacksOffInsteadOfRepeatingRequests() async {
        let counter = RequestCounter()
        let cache = ArtworkCache(http: MockHTTP.client { _ in
            counter.increment()
            return (503, Data())
        })
        let url = URL(string: "https://art.example/offline.png")!
        let first = await cache.image(for: url)
        let second = await cache.image(for: url)
        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(counter.value, 1)
    }

    func testLogoFailureCanRecoverAfterItsBackoffExpires() async {
        let counter = RequestCounter()
        let data = logoData
        let cache = ArtworkCache(http: MockHTTP.client { _ in
            counter.increment()
            return counter.value == 1 ? (503, Data()) : (200, data)
        }, retryDelay: 0)
        let url = URL(string: "https://art.example/recovered.png")!
        let first = await cache.image(for: url)
        let second = await cache.image(for: url)
        XCTAssertNil(first)
        XCTAssertNotNil(second, "A temporary logo error must not last for the entire app session")
        XCTAssertEqual(counter.value, 2)
    }

    func testLogoFailureCacheEvictsOldEntriesAtItsLimit() async {
        let counter = RequestCounter()
        let cache = ArtworkCache(http: MockHTTP.client { _ in
            counter.increment()
            return (404, Data())
        }, failureLimit: 2)
        for name in ["one", "two", "three", "one"] {
            _ = await cache.image(for: URL(string: "https://art.example/\(name).png")!)
        }
        XCTAssertEqual(counter.value, 4, "The oldest failed URL must be evicted, keeping the failure cache bounded")
    }

    func testReturnsArtworkDataAndUpscalesURL() async {
        let searchJSON = #"{"results":[{"artworkUrl100":"https://art.example/100x100bb.jpg"}]}"#
        let imageData = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        )!
        let http = MockHTTP.client { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("itunes.apple.com/search") {
                return (200, Data(searchJSON.utf8))
            }
            if url.contains("art.example") {
                XCTAssertTrue(url.contains("600x600"), "Artwork URL should be requested at higher resolution")
                return (200, imageData)
            }
            return (404, Data())
        }
        let service = ArtworkLookupService(http: http)

        let data = await service.artworkData(artist: "Daft Punk", title: "Around the World")
        XCTAssertEqual(data, imageData)
    }

    func testReturnsNilWhenNoCatalogMatch() async {
        let http = MockHTTP.client { _ in (200, Data(#"{"results":[]}"#.utf8)) }
        let service = ArtworkLookupService(http: http)
        let data = await service.artworkData(artist: "Unknown Artist", title: "Unknown Song")
        XCTAssertNil(data)
    }

    func testBlankInputNeverRequests() async {
        let http = MockHTTP.client { request in
            XCTFail("Blank artist/title must not trigger a lookup: \(request.url?.absoluteString ?? "")")
            return (200, Data())
        }
        let service = ArtworkLookupService(http: http)
        let data = await service.artworkData(artist: "", title: " ")
        XCTAssertNil(data)
    }

    func testNegativeResultsAreCached() async {
        let counter = RequestCounter()
        let http = MockHTTP.client { _ in
            counter.increment()
            return (200, Data(#"{"results":[]}"#.utf8))
        }
        let service = ArtworkLookupService(http: http)

        _ = await service.artworkData(artist: "Nobody", title: "Nothing")
        _ = await service.artworkData(artist: "Nobody", title: "Nothing")
        XCTAssertEqual(counter.value, 1, "A song with no match must not be looked up repeatedly")
    }

    func testTemporaryFailureCanRecoverOnNextLookup() async {
        let counter = RequestCounter()
        let imageData = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        )!
        let http = MockHTTP.client { request in
            if request.url?.host == "itunes.apple.com" {
                counter.increment()
                if counter.value == 1 { return (503, Data()) }
                return (200, Data(#"{"results":[{"artworkUrl100":"https://art.example/100x100bb.jpg"}]}"#.utf8))
            }
            return (200, imageData)
        }
        let service = ArtworkLookupService(http: http)
        let first = await service.artworkData(artist: "Artist", title: "Song")
        let second = await service.artworkData(artist: "Artist", title: "Song")
        XCTAssertNil(first)
        XCTAssertEqual(second, imageData)
        XCTAssertEqual(counter.value, 2)
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
