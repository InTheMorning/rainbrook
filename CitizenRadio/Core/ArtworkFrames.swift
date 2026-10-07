import Foundation

/// The frame selection and the frame delays for an animated image.
/// ADR 0015 §Decoding names these rules. This type does not use ImageIO.
public enum ArtworkFrames {
    /// The largest side, in pixels, of one frame of an animated image.
    public static let animatedMaximumSide = 400

    /// The largest side, in pixels, of a still image.
    public static let stillMaximumSide = 1_024

    /// The largest number of bytes for all decoded frames together, at 4 bytes for each pixel.
    public static let maximumDecodedBytes = 50_331_648

    /// The smallest frame delay, in seconds, that the app keeps.
    public static let minimumDelay = 0.02

    /// The delay, in seconds, that replaces a missing delay or a delay that is too short.
    public static let replacementDelay = 0.1

    /// The delay of one frame: unclamped, else clamped, else replacementDelay; less than minimumDelay gives replacementDelay.
    public static func delay(unclamped: Double?, clamped: Double?) -> Double {
        let value = unclamped ?? clamped ?? replacementDelay
        guard value >= minimumDelay else {
            return replacementDelay
        }
        return value
    }

    /// The frames to keep and their delays, in frame order.
    /// framePixels: the pixel count of one decoded frame. The sum of the kept delays equals the sum of all delays.
    public static func plan(delays: [Double], framePixels: Int) -> [(index: Int, delay: Double)] {
        guard !delays.isEmpty else {
            return []
        }

        let budget = frameBudget(framePixels: framePixels)
        guard delays.count > budget else {
            return delays.enumerated().map { (index: $0.offset, delay: $0.element) }
        }

        // The step is ceil(count / budget). Each dropped frame adds its delay
        // to the kept frame before it.
        let step = (delays.count + budget - 1) / budget
        var result: [(index: Int, delay: Double)] = []
        for (index, delay) in delays.enumerated() {
            if index % step == 0 {
                result.append((index: index, delay: delay))
            } else {
                result[result.count - 1].delay += delay
            }
        }
        return result
    }

    /// The number of frames that fit in maximumDecodedBytes, with a minimum of 1.
    private static func frameBudget(framePixels: Int) -> Int {
        let pixels = max(framePixels, 1)
        let (frameBytes, overflow) = pixels.multipliedReportingOverflow(by: 4)
        guard !overflow else {
            return 1
        }
        return max(maximumDecodedBytes / frameBytes, 1)
    }
}
