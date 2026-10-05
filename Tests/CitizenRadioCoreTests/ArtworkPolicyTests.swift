import Foundation
import XCTest
@testable import CitizenRadioCore

final class ArtworkPolicyTests: XCTestCase {
    func testAcceptsJPEGData() {
        let data = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01, 0x02])
        XCTAssertTrue(ArtworkPolicy.accepts(data))
    }

    func testAcceptsPNGData() {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])
        XCTAssertTrue(ArtworkPolicy.accepts(data))
    }

    func testRejectsGIFData() {
        let data = Data("GIF89a".utf8)
        XCTAssertFalse(ArtworkPolicy.accepts(data))
    }

    func testRejectsEmptyData() {
        XCTAssertFalse(ArtworkPolicy.accepts(Data()))
    }

    func testRejectsJPEGDataOverTheMaximumSize() {
        var data = Data([0xFF, 0xD8, 0xFF])
        data.append(Data(repeating: 0, count: ArtworkPolicy.maximumBytes + 1 - data.count))
        XCTAssertEqual(data.count, ArtworkPolicy.maximumBytes + 1)
        XCTAssertFalse(ArtworkPolicy.accepts(data))
    }

    func testAcceptsJPEGDataAtTheMaximumSize() {
        var data = Data([0xFF, 0xD8, 0xFF])
        data.append(Data(repeating: 0, count: ArtworkPolicy.maximumBytes - data.count))
        XCTAssertEqual(data.count, ArtworkPolicy.maximumBytes)
        XCTAssertTrue(ArtworkPolicy.accepts(data))
    }

    func testCacheKeyForRelayArtwork() {
        let artwork = TrackDisplay.Artwork.relay(
            sha256: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
            mime: "image/jpeg"
        )
        let key = ArtworkPolicy.cacheKey(for: artwork)
        XCTAssertEqual(
            key,
            "sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        )
    }

    func testCacheKeyForURLArtwork() {
        let url = URL(string: "https://example.com/artwork.jpg")!
        let artwork = TrackDisplay.Artwork.url(url)
        let key = ArtworkPolicy.cacheKey(for: artwork)
        XCTAssertEqual(key, "url:https://example.com/artwork.jpg")
    }
}
