# Artwork task 001: Large URL images and animated GIF images

- Decision: [ADR 0015](../adr/0015-artwork-from-url-and-animated-gif.md). [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for threading. Model: Opus.
- Depends on: none.

## Goal

Show large URL images and animated GIF images. The download has a limit, the decode makes the image smaller, and the player screen shows the animation.

## Files to inspect

- `docs/adr/0015-artwork-from-url-and-animated-gif.md`, `docs/adr/0008-relay-display-metadata.md` §Artwork
- `CitizenRadio/Core/ArtworkPolicy.swift` and `Tests/CitizenRadioCoreTests/ArtworkPolicyTests.swift`
- `CitizenRadio/ArtworkLoader.swift`, `CitizenRadio/PlayerView.swift` (`Artwork`), `CitizenRadio/TrackInfoModel.swift` (`image`, `updateNowPlaying`)
- `CitizenRadio/URLSessionEventStream.swift` (the pattern for a byte stream with `session.bytes(for:)`)

## Files likely to change

- `CitizenRadio/Core/ArtworkPolicy.swift`, `Tests/CitizenRadioCoreTests/ArtworkPolicyTests.swift`
- `CitizenRadio/Core/ArtworkFrames.swift` (new), `Tests/CitizenRadioCoreTests/ArtworkFramesTests.swift` (new)
- `CitizenRadio/ArtworkLoader.swift`
- `CitizenRadio/PlayerView.swift` (only the `Artwork` view)
- `CitizenRadio/TrackInfoModel.swift` (only the image that goes to Now Playing)

## Do not touch

- All other files. Playback, ICY sync, the relay clients and the boost code do not change.

## Constraints

Core API (only `Foundation`):

```swift
public enum ArtworkFormat: Equatable, Sendable { case jpeg, png, gif }

public enum ArtworkPolicy {
    public static let relayMaximumBytes = 524_288
    public static let urlMaximumBytes = 41_943_040
    /// The format from the first bytes, or nil.
    public static func format(of data: Data) -> ArtworkFormat?
    /// Relay images: JPEG or PNG, a maximum of relayMaximumBytes. URL images: JPEG, PNG or GIF, a maximum of urlMaximumBytes.
    public static func accepts(_ data: Data, for artwork: TrackDisplay.Artwork) -> Bool
    public static func maximumBytes(for artwork: TrackDisplay.Artwork) -> Int
    public static func cacheKey(for artwork: TrackDisplay.Artwork) -> String   // no change
}

public enum ArtworkFrames {
    public static let animatedMaximumSide = 400
    public static let stillMaximumSide = 1_024
    public static let maximumDecodedBytes = 50_331_648
    public static let minimumDelay = 0.02
    public static let replacementDelay = 0.1
    /// The delay of one frame: unclamped, else clamped, else replacementDelay; less than minimumDelay gives replacementDelay.
    public static func delay(unclamped: Double?, clamped: Double?) -> Double
    /// The frames to keep and their delays, in frame order.
    /// framePixels: the pixel count of one decoded frame. The sum of the kept delays equals the sum of all delays.
    public static func plan(delays: [Double], framePixels: Int) -> [(index: Int, delay: Double)]
}
```

- Remove `ArtworkPolicy.maximumBytes` and the old `accepts(_:)`. Update their callers.
- `plan`: the frame budget is `maximumDecodedBytes / (framePixels * 4)`, with a minimum of 1. If all frames fit, keep all. Else keep frame indexes at a regular step (`step = ceil(count / budget)`: indexes 0, step, 2 × step, …), and add the delay of each dropped frame to the kept frame before it. An empty input gives an empty result.

`ArtworkLoader` (actor, iOS):

- The cache value is a `UIImage`. An animated image is `UIImage.animatedImage(with:duration:)`.
- Download with `session.bytes(for:)`, a request time limit of 20 seconds, and status 200:
  - If `expectedContentLength` is more than `ArtworkPolicy.maximumBytes(for:)`, stop before the body.
  - Read the bytes into a buffer in chunks. Stop and give nil when the buffer gets more bytes than the limit. Cancel the byte stream task on each path.
- Then `ArtworkPolicy.accepts(_:for:)` must be true.
- Decode with ImageIO (`CGImageSourceCreateWithData`):
  - Frame count 1, or JPEG or PNG: `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceCreateThumbnailWithTransform` and `kCGImageSourceThumbnailMaxPixelSize` = `ArtworkFrames.stillMaximumSide`.
  - A GIF with two or more frames: read each frame delay from `kCGImagePropertyGIFDictionary` (`kCGImagePropertyGIFUnclampedDelayTime`, `kCGImagePropertyGIFDelayTime`) through `ArtworkFrames.delay`. Find the reduced frame size from the pixel size of frame 0 and `animatedMaximumSide`. Get the plan from `ArtworkFrames.plan`, then make only the kept frames as thumbnails with `kCGImageSourceThumbnailMaxPixelSize` = `animatedMaximumSide`. Make the animated image with the total delay as its duration.
  - Any failure gives nil.
- All of this runs in the actor, off the main actor. No log of a URL or image data.

Display:

- `PlayerView.Artwork`: an animated image (`image.images` has 2 or more frames) shows in a `UIViewRepresentable` around a `UIImageView`. Set `contentMode = .scaleAspectFill`, `clipsToBounds = true` and a low compression resistance, so it fills and clips like the still image. A still image shows as now. The rounded rectangle, the size, the clip and `accessibilityHidden` do not change.
- `TrackInfoModel`: Now Playing gets `image?.images?.first ?? image`.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- Comments in ASD-STE100.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `format(of:)` for JPEG, PNG, `GIF87a`, `GIF89a`, and nil for `RIFF…WEBP`, empty data and 2 bytes.
- A relay artwork accepts JPEG and PNG of 524,288 bytes, and rejects 524,289 bytes and a GIF.
- A URL artwork accepts a GIF and a PNG of 659,106 bytes, accepts 41,943,040 bytes, and rejects 41,943,041 bytes.
- `delay`: unclamped 0.05 gives 0.05. No unclamped and clamped 0.07 gives 0.07. 0.0 gives 0.1, 0.01 gives 0.1, and nil and nil gives 0.1.
- `plan`: 10 frames of 0.1 s that fit keep all 10. 10 frames with a budget of 4 keep indexes 0, 3, 6, 9 with delays 0.3, 0.3, 0.3, 0.1. Select `framePixels` to give that budget. An empty input gives an empty result. A frame larger than the memory limit keeps 1 frame with the total delay.
- `scripts/check.sh` passes.

Manual (by the reviewer): the download stops at the limit, the decode is in the actor, and the animated view clips like the still image.

Visual (on an iPhone): the ADR 0015 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "ArtworkPolicyTests|ArtworkFramesTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.
- ImageIO needs a change outside the listed files.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/artwork-task-001-url-and-gif.md
- docs/adr/0015-artwork-from-url-and-animated-gif.md
- the files listed in "Files to inspect"

Goal:
- Show large URL images and animated GIF images.
- Stop the download at the limit, decode a smaller image, and show the animation on the player screen.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- Download and decode stay in the ArtworkLoader actor. No log of URLs or image data.
- No @unchecked Sendable or nonisolated(unsafe). Tests use fixed values.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
