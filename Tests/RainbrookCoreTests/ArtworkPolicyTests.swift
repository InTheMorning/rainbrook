import Foundation
import XCTest
@testable import RainbrookCore

final class ArtworkPolicyTests: XCTestCase {
    private let jpegStart: [UInt8] = [0xFF, 0xD8, 0xFF]
    private let pngStart: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    private let relayArtwork = TrackDisplay.Artwork.relay(sha256: "abc", mime: "image/jpeg")
    private let urlArtwork = TrackDisplay.Artwork.url(URL(string: "https://example.com/artwork")!)

    /// Gives data of the count, with the start bytes first and zero bytes after them.
    private func data(start: [UInt8], count: Int) -> Data {
        var data = Data(start)
        data.append(Data(repeating: 0, count: count - start.count))
        return data
    }

    // MARK: - format(of:)

    func testFormatOfJPEG() {
        XCTAssertEqual(ArtworkPolicy.format(of: Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])), .jpeg)
    }

    func testFormatOfPNG() {
        XCTAssertEqual(
            ArtworkPolicy.format(of: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])),
            .png
        )
    }

    func testFormatOfGIF87a() {
        XCTAssertEqual(ArtworkPolicy.format(of: Data("GIF87a\u{01}\u{00}".utf8)), .gif)
    }

    func testFormatOfGIF89a() {
        XCTAssertEqual(ArtworkPolicy.format(of: Data("GIF89a\u{01}\u{00}".utf8)), .gif)
    }

    func testFormatOfWebPIsNil() {
        XCTAssertNil(ArtworkPolicy.format(of: Data("RIFF\u{00}\u{00}\u{00}\u{00}WEBPVP8 ".utf8)))
    }

    func testFormatOfEmptyDataIsNil() {
        XCTAssertNil(ArtworkPolicy.format(of: Data()))
    }

    func testFormatOfTwoBytesIsNil() {
        XCTAssertNil(ArtworkPolicy.format(of: Data([0xFF, 0xD8])))
    }

    // MARK: - Relay artwork

    func testRelayAcceptsJPEGOf524288Bytes() {
        let jpeg = data(start: jpegStart, count: 524_288)
        XCTAssertTrue(ArtworkPolicy.accepts(jpeg, for: relayArtwork))
    }

    func testRelayAcceptsPNGOf524288Bytes() {
        let png = data(start: pngStart, count: 524_288)
        XCTAssertTrue(ArtworkPolicy.accepts(png, for: relayArtwork))
    }

    func testRelayRejectsJPEGOf524289Bytes() {
        let jpeg = data(start: jpegStart, count: 524_289)
        XCTAssertFalse(ArtworkPolicy.accepts(jpeg, for: relayArtwork))
    }

    func testRelayRejectsGIF() {
        XCTAssertFalse(ArtworkPolicy.accepts(Data("GIF89a\u{01}\u{00}".utf8), for: relayArtwork))
    }

    func testRelayMaximumBytes() {
        XCTAssertEqual(ArtworkPolicy.maximumBytes(for: relayArtwork), 524_288)
    }

    // MARK: - URL artwork

    func testURLAcceptsGIF() {
        XCTAssertTrue(ArtworkPolicy.accepts(Data("GIF89a\u{01}\u{00}".utf8), for: urlArtwork))
    }

    func testURLAcceptsPNGOf659106Bytes() {
        let png = data(start: pngStart, count: 659_106)
        XCTAssertTrue(ArtworkPolicy.accepts(png, for: urlArtwork))
    }

    func testURLAccepts41943040Bytes() {
        let png = data(start: pngStart, count: 41_943_040)
        XCTAssertTrue(ArtworkPolicy.accepts(png, for: urlArtwork))
    }

    func testURLRejects41943041Bytes() {
        let png = data(start: pngStart, count: 41_943_041)
        XCTAssertFalse(ArtworkPolicy.accepts(png, for: urlArtwork))
    }

    func testURLRejectsWebP() {
        XCTAssertFalse(ArtworkPolicy.accepts(Data("RIFF\u{00}\u{00}\u{00}\u{00}WEBPVP8 ".utf8), for: urlArtwork))
    }

    func testURLMaximumBytes() {
        XCTAssertEqual(ArtworkPolicy.maximumBytes(for: urlArtwork), 41_943_040)
    }

    // MARK: - Cache key

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
