#if os(iOS)
import Foundation
import UIKit
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Downloads and decodes track artwork off the main thread.
/// ADR 0008 §Artwork names these rules.
actor ArtworkLoader {
    private static let requestTimeout: TimeInterval = 20

    private let session: URLSession
    private var cache: LRUCache<String, UIImage>

    init(session: URLSession = .shared, capacity: Int = 8) {
        self.session = session
        self.cache = LRUCache(capacity: capacity)
    }

    /// Gives the decoded image for the track artwork.
    /// The image comes from the cache, or from a new download and decode.
    /// Gives nil when a step fails.
    func image(for artwork: TrackDisplay.Artwork, event: RelayEvent) async -> UIImage? {
        let key = ArtworkPolicy.cacheKey(for: artwork)
        if let cachedImage = cache.value(for: key) {
            return cachedImage
        }

        let url = sourceURL(for: artwork, event: event)
        guard let image = await downloadAndDecode(from: url) else {
            return nil
        }

        cache.insert(image, for: key)
        return image
    }

    private func sourceURL(for artwork: TrackDisplay.Artwork, event: RelayEvent) -> URL {
        switch artwork {
        case .relay(let sha256, _):
            return event.artworkURL(sha256: sha256)
        case .url(let url):
            return url
        }
    }

    private func downloadAndDecode(from url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout

        guard let (data, response) = try? await session.data(for: request) else {
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard httpResponse.expectedContentLength <= Int64(ArtworkPolicy.maximumBytes) else {
            return nil
        }

        guard ArtworkPolicy.accepts(data) else {
            return nil
        }

        guard let decodedImage = UIImage(data: data) else {
            return nil
        }

        return await decodedImage.byPreparingForDisplay()
    }
}
#endif
