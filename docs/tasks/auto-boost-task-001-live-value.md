# Auto-boost task 001: Live value and pairing

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave 1. Model: Sonnet.
- Decision: [ADR 0012](../adr/0012-auto-boost.md) §The pairing, §Payable destinations.
- Depends on: none.

## Goal

Decode the relay live value payload with only its payable destinations. Pair a completed track with its payload. Decode the optional `value` of a display track. Add the value routes to `RelayEvent`.

## Files to inspect

- `docs/adr/0012-auto-boost.md`
- `CitizenRadio/Core/TrackDisplay.swift`, `CitizenRadio/Core/RelayEvent.swift`, `CitizenRadio/Core/IcySync.swift` (`normalize`)
- `Tests/CitizenRadioCoreTests/TrackDisplayTests.swift`, `RelayEventTests.swift`

## Files likely to change

- `CitizenRadio/Core/LiveValue.swift` (new)
- `CitizenRadio/Core/BoostPairing.swift` (new)
- `CitizenRadio/Core/TrackDisplay.swift`
- `CitizenRadio/Core/RelayEvent.swift`
- `Tests/CitizenRadioCoreTests/LiveValueTests.swift`, `BoostPairingTests.swift` (new)
- `Tests/CitizenRadioCoreTests/TrackDisplayTests.swift`, `RelayEventTests.swift`

## Do not touch

- All other files.

## Constraints

Each file imports only `Foundation`. Use exactly this API:

```swift
public struct LiveValueDestination: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case node(pubkey: String)                       // 66 lowercase hex characters after lowercasing
        case lightningAddress(name: String, host: String) // lowercased
    }
    public let kind: Kind
    public let name: String?
    public let split: Double        // > 0
    public let fee: Bool            // false when absent
    public let customKey: String?
    public let customValue: String?
    public init(kind: Kind, name: String?, split: Double, fee: Bool, customKey: String?, customValue: String?)
}

public struct LiveValuePayload: Equatable, Sendable {
    public static let placeholderTitle = "No V4V track playing"
    public let title: String
    public let eventGuid: String
    public let blockGuid: String
    public let feedGuid: String?
    public let itemGuid: String?
    /// Only the payable destinations, in payload order.
    public let destinations: [LiveValueDestination]
    /// False for the placeholder title, and when no destination is payable.
    public var isPayable: Bool { get }
    /// Gives nil for `{}`. Throws `DecodeError.invalid` for data that is not a JSON object,
    /// or for a missing or empty `title`, `eventGuid` or `blockGuid`.
    public static func decode(_ data: Data) throws -> LiveValuePayload?
    public enum DecodeError: Error, Equatable { case invalid }
}

public struct BoostPairing: Equatable, Sendable {
    public static let capacity = 8
    public init()
    /// Adds a payload as the newest. A payload with an equal blockGuid replaces the older one.
    public mutating func receive(_ payload: LiveValuePayload)
    public mutating func clear()
    /// The payload to pay for this relay track, or nil (ADR 0012 §The pairing).
    public func payload(for track: TrackDisplay) -> LiveValuePayload?
}
```

`TrackDisplay` changes:

- Add `public struct ValueIdentity: Equatable, Sendable { public let eventGuid: String; public let blockGuid: String; public init(eventGuid:blockGuid:) }`.
- Add `public let value: ValueIdentity?`. Add the parameter `value: ValueIdentity? = nil` at the end of the initializer, so existing calls compile.
- `decode` reads `track.value` when it is an object with two non-empty strings `eventGuid` and `blockGuid`. Any other shape of `value` gives `value = nil`. It does not throw for it. All present rules stay.

`RelayEvent` changes: add `remoteValueURL` (`/v1/liveitems/{id}/remoteValue`) and `valueEventsURL` (`/v1/liveitems/{id}/events`), in the style of `displayURL`.

Destination rules (ADR 0012 §Payable destinations):

- `type` `node`: `address` lowercased must be exactly 66 hex characters. Else drop the destination.
- `type` `lnaddress`: `address` lowercased must be `name@host` with one `@`, a non-empty name, and a host with a minimum of one dot. Drop it if the host ends with `.invalid`, `.example`, `.test` or `.localhost`, or is `example.com`, `example.net` or `example.org`.
- Any other `type`, or no `type`: drop.
- `split` is a string or a number. It must parse to a finite value greater than 0. Else drop.
- `fee` is true only for the JSON boolean `true`.

Pairing rules:

- With `track.value`: give the payload whose `blockGuid` equals `track.value.blockGuid`, if it is payable. Else nil. Do not fall back to the title.
- Without `track.value`: give the newest payable payload whose `IcySync.normalize(title)` equals `IcySync.normalize(track.title)`. Else nil.

## Acceptance criteria

Mechanical. Each item is a test:

- The publisher V4V payload shape decodes with its node destinations, splits, fee and custom key and value. Use a fixed JSON literal.
- The placeholder payload (title "No V4V track playing", destination `no-v4v-track@example.invalid`) decodes and is not payable.
- A payload with a valid lightning address destination is payable. Each reserved host in the rules is dropped.
- A node address with 64 or 67 characters, or a non-hex character, is dropped. A split of `"0"`, `"-5"`, `"abc"` or absent is dropped.
- `{}` gives nil. A payload without `blockGuid` throws.
- Pairing by title: the newest payable payload with the same normalized title wins. A different title gives nil. A non-payable payload with the same title gives nil.
- Pairing by block ID: the payload with that `blockGuid` is given, also when a newer payload has the same title. A missing `blockGuid` gives nil.
- The list keeps 8 payloads. An equal `blockGuid` replaces the older payload.
- `TrackDisplay.decode` reads `value`, ignores a `value` with an empty `blockGuid` or a third shape, and keeps all present tests passing.
- `RelayEvent` gives both new URLs.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "LiveValueTests|BoostPairingTests|TrackDisplayTests|RelayEventTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A present `TrackDisplay` test must change.
- The API cannot meet a rule.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-001-live-value.md
- docs/adr/0012-auto-boost.md
- CitizenRadio/Core/TrackDisplay.swift, CitizenRadio/Core/RelayEvent.swift, CitizenRadio/Core/IcySync.swift
- Tests/CitizenRadioCoreTests/TrackDisplayTests.swift, Tests/CitizenRadioCoreTests/RelayEventTests.swift

Goal:
- Add LiveValuePayload, LiveValueDestination and BoostPairing, the optional TrackDisplay.value, and the RelayEvent value routes.

Constraints:
- Use the exact API and rules in the task file. Only Foundation.
- Tests use fixed JSON literals and fixed expected values. A test must not repeat the code's calculation.
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
