import Foundation
import XCTest
@testable import CitizenRadioCore

/// ADR 0020 §Stream quality: the variants of a master playlist, and the variant for each quality.
final class HLSMasterPlaylistTests: XCTestCase {
    private let baseURL = URL(string: "https://bastone.heycitizen.xyz/hls/live.m3u8")!

    /// The live master playlist of 2026-10-07, with CR LF line ends.
    private let liveMaster = [
        "#EXTM3U",
        "#EXT-X-VERSION:3",
        "#EXT-X-STREAM-INF:BANDWIDTH=140800,CODECS=\"mp4a.40.2\"",
        "https://bastone.heycitizen.xyz/hls/aac.m3u8",
        "#EXT-X-STREAM-INF:BANDWIDTH=52800,CODECS=\"mp4a.40.2\"",
        "https://bastone.heycitizen.xyz/hls/aac_low.m3u8",
        "#EXT-X-STREAM-INF:BANDWIDTH=105600,CODECS=\"mp4a.40.2\"",
        "https://bastone.heycitizen.xyz/hls/aac_mid.m3u8",
        ""
    ].joined(separator: "\r\n")

    private var liveVariants: [HLSVariant] {
        HLSMasterPlaylist.variants(in: liveMaster, baseURL: baseURL)
    }

    func testLiveMasterGivesThreeVariantsInFileOrder() {
        XCTAssertEqual(liveVariants, [
            HLSVariant(bandwidth: 140_800, url: URL(string: "https://bastone.heycitizen.xyz/hls/aac.m3u8")!),
            HLSVariant(bandwidth: 52_800, url: URL(string: "https://bastone.heycitizen.xyz/hls/aac_low.m3u8")!),
            HLSVariant(bandwidth: 105_600, url: URL(string: "https://bastone.heycitizen.xyz/hls/aac_mid.m3u8")!)
        ])
    }

    func testRelativeURIResolvesAgainstBase() {
        let text = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=52800\naac_low.m3u8\n"
        let variants = HLSMasterPlaylist.variants(in: text, baseURL: baseURL)
        XCTAssertEqual(variants.map(\.url.absoluteString), ["https://bastone.heycitizen.xyz/hls/aac_low.m3u8"])
        XCTAssertEqual(variants.map(\.bandwidth), [52_800])
    }

    func testMediaPlaylistGivesNoVariants() {
        let text = [
            "#EXTM3U",
            "#EXT-X-VERSION:3",
            "#EXT-X-TARGETDURATION:6",
            "#EXT-X-MEDIA-SEQUENCE:1200",
            "#EXTINF:6.000,",
            "aac_mid-1200.ts",
            "#EXTINF:6.000,",
            "aac_mid-1201.ts"
        ].joined(separator: "\r\n")
        XCTAssertEqual(HLSMasterPlaylist.variants(in: text, baseURL: baseURL), [])
    }

    func testStreamTagWithNoBandwidthIsSkipped() {
        let text = [
            "#EXTM3U",
            "#EXT-X-STREAM-INF:CODECS=\"mp4a.40.2\"",
            "aac.m3u8",
            "#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=50000,BANDWIDTH=52800,CODECS=\"mp4a.40.2,avc1.4d401f\"",
            "aac_low.m3u8"
        ].joined(separator: "\r\n")
        let variants = HLSMasterPlaylist.variants(in: text, baseURL: baseURL)
        XCTAssertEqual(variants.map(\.bandwidth), [52_800])
        XCTAssertEqual(variants.map(\.url.lastPathComponent), ["aac_low.m3u8"])
    }

    func testSelectWithLiveVariants() {
        XCTAssertEqual(HLSMasterPlaylist.select(.high, from: liveVariants)?.bandwidth, 140_800)
        XCTAssertEqual(HLSMasterPlaylist.select(.medium, from: liveVariants)?.bandwidth, 105_600)
        XCTAssertEqual(HLSMasterPlaylist.select(.low, from: liveVariants)?.bandwidth, 52_800)
    }

    func testMediumWithOnlyAHigherVariantGivesTheLowest() {
        let variant = HLSVariant(bandwidth: 140_800, url: URL(string: "https://bastone.heycitizen.xyz/hls/aac.m3u8")!)
        XCTAssertEqual(HLSMasterPlaylist.select(.medium, from: [variant])?.bandwidth, 140_800)
    }

    func testEmptyListGivesNil() {
        for quality in StreamQuality.allCases {
            XCTAssertNil(HLSMasterPlaylist.select(quality, from: []))
        }
    }
}
