#if os(iOS)
import Foundation
import ImageIO
import UIKit
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Downloads and decodes track artwork off the main thread.
/// ADR 0008 §Artwork and ADR 0015 name these rules.
actor ArtworkLoader {
    private static let requestTimeout: TimeInterval = 20
    private static let chunkSize = 65_536

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
        guard let data = await download(from: url, maximumBytes: ArtworkPolicy.maximumBytes(for: artwork)),
              ArtworkPolicy.accepts(data, for: artwork),
              let image = decode(data) else {
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

    // MARK: - Download

    /// Reads the response body as a byte stream.
    /// Gives nil when the status is not 200, or when the body has more bytes than the limit.
    /// Each path cancels the data task. A canceled caller also cancels the data task.
    private func download(from url: URL, maximumBytes: Int) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout

        guard let (bytes, response) = try? await session.bytes(for: request) else {
            return nil
        }
        let dataTask = bytes.task
        defer { dataTask.cancel() }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              httpResponse.expectedContentLength <= Int64(maximumBytes) else {
            return nil
        }

        return await withTaskCancellationHandler {
            await readBody(bytes, maximumBytes: maximumBytes)
        } onCancel: {
            dataTask.cancel()
        }
    }

    /// Reads the bytes into a buffer in chunks.
    /// Gives nil when the buffer gets more bytes than the limit, or when the read fails.
    private func readBody(_ bytes: URLSession.AsyncBytes, maximumBytes: Int) async -> Data? {
        var body = Data()
        var chunk: [UInt8] = []
        chunk.reserveCapacity(Self.chunkSize)
        do {
            for try await byte in bytes {
                chunk.append(byte)
                if chunk.count == Self.chunkSize {
                    guard body.count + chunk.count <= maximumBytes, !Task.isCancelled else {
                        return nil
                    }
                    body.append(contentsOf: chunk)
                    chunk.removeAll(keepingCapacity: true)
                }
            }
        } catch {
            return nil
        }
        guard body.count + chunk.count <= maximumBytes, !Task.isCancelled else {
            return nil
        }
        body.append(contentsOf: chunk)
        return body
    }

    // MARK: - Decode

    /// Decodes the data with ImageIO into a smaller image.
    /// A GIF with two or more frames gives an animated image. Gives nil when a step fails.
    private func decode(_ data: Data) -> UIImage? {
        guard let format = ArtworkPolicy.format(of: data),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount >= 1 else {
            return nil
        }
        if format == .gif && frameCount >= 2 {
            return animatedImage(from: source, frameCount: frameCount)
        }
        guard let cgImage = thumbnail(from: source, at: 0, maximumSide: ArtworkFrames.stillMaximumSide) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Makes an animated image from the frames in the plan of `ArtworkFrames`.
    private func animatedImage(from source: CGImageSource, frameCount: Int) -> UIImage? {
        let delays = (0..<frameCount).map { frameDelay(from: source, at: $0) }
        guard let framePixels = reducedFramePixels(from: source) else {
            return nil
        }

        let plan = ArtworkFrames.plan(delays: delays, framePixels: framePixels)
        var frames: [UIImage] = []
        frames.reserveCapacity(plan.count)
        var duration = 0.0
        for kept in plan {
            guard let cgImage = thumbnail(from: source, at: kept.index, maximumSide: ArtworkFrames.animatedMaximumSide) else {
                return nil
            }
            frames.append(UIImage(cgImage: cgImage))
            duration += kept.delay
        }
        guard !frames.isEmpty else {
            return nil
        }
        return UIImage.animatedImage(with: frames, duration: duration)
    }

    /// Reads the delay of one GIF frame through `ArtworkFrames.delay`.
    private func frameDelay(from source: CGImageSource, at index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let unclamped = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
        let clamped = (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue
        return ArtworkFrames.delay(unclamped: unclamped, clamped: clamped)
    }

    /// Gives the pixel count of one reduced frame.
    /// The app makes the dimensions of frame 0 smaller until the longest side is a maximum of `animatedMaximumSide`.
    private func reducedFramePixels(from source: CGImageSource) -> Int? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else {
            return nil
        }
        let scale = min(1, Double(ArtworkFrames.animatedMaximumSide) / max(width, height))
        let reducedWidth = (width * scale).rounded(.up)
        let reducedHeight = (height * scale).rounded(.up)
        return Int(reducedWidth * reducedHeight)
    }

    /// Makes a decoded thumbnail of one frame, with a maximum side in pixels.
    private func thumbnail(from source: CGImageSource, at index: Int, maximumSide: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSide,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }
}
#endif
