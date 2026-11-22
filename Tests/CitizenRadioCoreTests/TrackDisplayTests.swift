import Foundation
import XCTest
@testable import CitizenRadioCore

final class TrackDisplayTests: XCTestCase {
    func testDecodesLiveRelayExample() throws {
        let json = """
        {
            "track": {
                "artist": "Miles Davis",
                "title": "Pharaoh's Dance",
                "artwork": {
                    "sha256": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
                    "mime": "image/jpeg"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNotNil(track)
        XCTAssertEqual(track?.artist, "Miles Davis")
        XCTAssertEqual(track?.title, "Pharaoh's Dance")

        if case .relay(let sha256, let mime) = track?.artwork {
            XCTAssertEqual(sha256, "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
            XCTAssertEqual(mime, "image/jpeg")
        } else {
            XCTFail("Expected relay artwork")
        }
    }

    func testDecodesURLArtwork() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "artwork": {
                    "url": "https://example.com/artwork.jpg"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNotNil(track)
        if case .url(let url) = track?.artwork {
            XCTAssertEqual(url, URL(string: "https://example.com/artwork.jpg")!)
        } else {
            XCTFail("Expected URL artwork")
        }
    }

    func testDecodesNullArtwork() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "artwork": null
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNotNil(track)
        XCTAssertNil(track?.artwork)
    }

    func testDecodesTrackNull() throws {
        let json = """
        {
            "track": null
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)
        XCTAssertNil(track)
    }

    func testThrowsForDataURL() {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "artwork": {
                    "url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try TrackDisplay.decode(data)) { error in
            XCTAssertEqual(error as? TrackDisplay.DecodeError, .invalid)
        }
    }

    func testThrowsForUppercaseSha256() {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "artwork": {
                    "sha256": "A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6",
                    "mime": "image/jpeg"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try TrackDisplay.decode(data)) { error in
            XCTAssertEqual(error as? TrackDisplay.DecodeError, .invalid)
        }
    }

    func testThrowsForShortSha256() {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "artwork": {
                    "sha256": "a1b2c3d4",
                    "mime": "image/jpeg"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try TrackDisplay.decode(data)) { error in
            XCTAssertEqual(error as? TrackDisplay.DecodeError, .invalid)
        }
    }

    func testThrowsForInvalidMime() {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "artwork": {
                    "sha256": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6",
                    "mime": "image/gif"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try TrackDisplay.decode(data)) { error in
            XCTAssertEqual(error as? TrackDisplay.DecodeError, .invalid)
        }
    }

    func testThrowsForInvalidJSON() {
        let json = "[]"
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try TrackDisplay.decode(data)) { error in
            XCTAssertEqual(error as? TrackDisplay.DecodeError, .invalid)
        }
    }

    func testMissingArtistDefaultsToEmpty() throws {
        let json = """
        {
            "track": {
                "title": "Title"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertEqual(track?.artist, "")
    }

    func testMissingTitleDefaultsToEmpty() throws {
        let json = """
        {
            "track": {
                "artist": "Artist"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertEqual(track?.title, "")
    }

    func testMissingArtworkDefaultsToNil() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.artwork)
    }

    func testMalformedJSONThrowsInvalid() {
        XCTAssertThrowsError(try TrackDisplay.decode(Data("{not json".utf8))) { error in
            XCTAssertEqual(error as? TrackDisplay.DecodeError, .invalid)
        }
    }

    func testDecodeReadsValueIdentity() throws {
        let json = """
        {
            "track": {
                "artist": "Miles Davis",
                "title": "Pharaoh's Dance",
                "value": {
                    "eventGuid": "event-guid-1",
                    "blockGuid": "block-guid-1"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertEqual(
            track?.value,
            TrackDisplay.ValueIdentity(eventGuid: "event-guid-1", blockGuid: "block-guid-1")
        )
    }

    func testDecodeIgnoresValueWithEmptyBlockGuid() throws {
        let json = """
        {
            "track": {
                "artist": "Miles Davis",
                "title": "Pharaoh's Dance",
                "value": {
                    "eventGuid": "event-guid-1",
                    "blockGuid": ""
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.value)
    }

    func testDecodeIgnoresValueOfAThirdShape() throws {
        let json = """
        {
            "track": {
                "artist": "Miles Davis",
                "title": "Pharaoh's Dance",
                "value": "not-an-object"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.value)
    }

    func testMissingValueDefaultsToNil() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.value)
    }

    // MARK: - album (ADR 0019)

    func testDecodeReadsAlbum() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "album": "Way to Go"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertEqual(track?.album, "Way to Go")
    }

    func testMissingAlbumGivesNil() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.album)
        XCTAssertEqual(track?.artist, "Artist")
    }

    func testNullAlbumGivesNil() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "album": null
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.album)
        XCTAssertEqual(track?.artist, "Artist")
    }

    func testEmptyAlbumGivesNil() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "album": ""
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.album)
        XCTAssertEqual(track?.artist, "Artist")
    }

    func testNonStringAlbumGivesNil() throws {
        let json = """
        {
            "track": {
                "artist": "Artist",
                "title": "Title",
                "album": 12
            }
        }
        """
        let data = json.data(using: .utf8)!
        let track = try TrackDisplay.decode(data)

        XCTAssertNil(track?.album)
        XCTAssertEqual(track?.artist, "Artist")
    }

    // MARK: - songLine (ADR 0024)

    func testDecodeReadsSongLine() throws {
        let json = """
        {"track": {"artist": "Song Artist", "title": "Song", "songLine": "Show Host - Episode 12"}}
        """
        let track = try TrackDisplay.decode(json.data(using: .utf8)!)

        XCTAssertEqual(track?.songLine, "Show Host - Episode 12")
        XCTAssertEqual(track?.artist, "Song Artist")
    }

    func testMissingEmptyNullOrNonStringSongLineGivesNil() throws {
        let bodies = [
            #"{"track": {"artist": "A", "title": "T"}}"#,
            #"{"track": {"artist": "A", "title": "T", "songLine": ""}}"#,
            #"{"track": {"artist": "A", "title": "T", "songLine": null}}"#,
            #"{"track": {"artist": "A", "title": "T", "songLine": 12}}"#,
        ]
        for body in bodies {
            let track = try TrackDisplay.decode(body.data(using: .utf8)!)
            XCTAssertNil(track?.songLine, body)
            XCTAssertEqual(track?.title, "T", body)
        }
    }
}
