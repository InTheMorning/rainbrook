# Relay display task 005: Artwork policy, cache and loader

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 2. Model: Sonnet.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md) §Artwork, §Invariants. [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for blocking calls.
- Depends on: task 001.

## Goal

Add the image rules and a small cache to `CitizenRadioCore`.
Add an `ArtworkLoader` actor to the app. It downloads and decodes images off the main thread.

## Files to inspect

- `CitizenRadio/Core/TrackDisplay.swift`, `CitizenRadio/Core/RelayEvent.swift`
- `CitizenRadio/URLSessionRelayConnection.swift` (the header pattern for an iOS-only file)

## Files likely to change

- `CitizenRadio/Core/ArtworkPolicy.swift` (new)
- `CitizenRadio/Core/LRUCache.swift` (new)
- `Tests/CitizenRadioCoreTests/ArtworkPolicyTests.swift`, `LRUCacheTests.swift` (new)
- `CitizenRadio/ArtworkLoader.swift` (new, iOS only)

## Do not touch

- All other files.

## Constraints

Core API (`import Foundation` only):

```swift
public enum ArtworkPolicy {
    public static let maximumBytes = 524_288
    /// True only for JPEG or PNG data of maximumBytes or less, by the first bytes.
    public static func accepts(_ data: Data) -> Bool
    /// The cache key: "sha256:<hash>" for a relay image, "url:<absolute URL>" for a URL image.
    public static func cacheKey(for artwork: TrackDisplay.Artwork) -> String
}

public struct LRUCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    public init(capacity: Int)
    public var count: Int { get }
    /// Gives the value, and marks the key as the most recent.
    public mutating func value(for key: Key) -> Value?
    /// Stores the value as the most recent. Removes the least recent entry when the cache is full.
    public mutating func insert(_ value: Value, for key: Key)
}
```

- JPEG starts with the bytes `FF D8 FF`. PNG starts with `89 50 4E 47 0D 0A 1A 0A`.
- `LRUCache` with a capacity of 0 or less stores nothing.

App API:

```swift
#if os(iOS)
actor ArtworkLoader {
    init(session: URLSession = .shared, capacity: Int = 8)
    /// Gives the decoded image, from the cache or from the network. Gives nil after any failure.
    func image(for artwork: TrackDisplay.Artwork, event: RelayEvent) async -> UIImage?
}
#endif
```

Loader rules:

- A relay image loads from `event.artworkURL(sha256:)`. A URL image loads from its URL.
- Use `session.data(for:)` with a `timeoutInterval` of 20 seconds.
- Reject a status that is not `200`, an `expectedContentLength` larger than `maximumBytes`, and data that `ArtworkPolicy.accepts` rejects.
- Decode with `UIImage(data:)`, then `await image.byPreparingForDisplay()`. This runs in the actor, not on the main thread.
- Keep decoded images in an `LRUCache` keyed by `ArtworkPolicy.cacheKey(for:)`.
- No log of a URL or of image data.
- If Swift 6 rejects `UIImage` as `Sendable`, stop and escalate.

Other constraints:

- New iOS files start with `#if os(iOS)` and import `CitizenRadioCore` inside `#if SWIFT_PACKAGE`.
- Prose and comments in ASD-STE100.

## Acceptance criteria

Mechanical (each one is a test):

- `accepts` is true for JPEG and PNG data, and false for GIF data, for empty data, and for JPEG data of `maximumBytes + 1` bytes.
- `cacheKey` gives `sha256:<hash>` and `url:<URL>`.
- `LRUCache` with capacity 2: after inserts of A, B, a read of A, and an insert of C, the cache holds A and C, not B.
- `LRUCache` with capacity 0 stores nothing.
- `scripts/check.sh` passes, so `ArtworkLoader` compiles with the iOS SDK in Swift 6 mode.

Visual (on an iPhone, after task 008):

- The artwork of the playing track shows. A change of track shows the new artwork.

## Test commands

```sh
swift test --build-system native --filter "ArtworkPolicyTests|LRUCacheTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- Swift 6 rejects `UIImage` across the actor boundary.
- `byPreparingForDisplay()` is not available.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-005-artwork.md
- CitizenRadio/Core/TrackDisplay.swift
- CitizenRadio/Core/RelayEvent.swift
- CitizenRadio/URLSessionRelayConnection.swift (header pattern only)

Goal:
- Add ArtworkPolicy and LRUCache (core, tested) and the ArtworkLoader actor (app).

Constraints:
- Use the exact API and rules in the task file. Download and decode run in the actor, not on the main thread.
- No log of URLs or image data. No @unchecked Sendable or nonisolated(unsafe).
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "ArtworkPolicyTests|LRUCacheTests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
