# Relay display task 001: Parsers

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 1. Model: Haiku.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md) §Configuration, §Transport, §Display data, §Fallback: the ICY title.

## Goal

Add four pure parsers to `CitizenRadioCore`: `RelayEvent`, `EventStreamParser`, `TrackDisplay` and `IcyTitle`, with tests.

## Files to inspect

- `CitizenRadio/Core/NWCConnection.swift` (the pattern for a parser with a `LocalizedError`)
- `Tests/CitizenRadioCoreTests/NWCConnectionTests.swift`

## Files likely to change

- `CitizenRadio/Core/RelayEvent.swift` (new)
- `CitizenRadio/Core/EventStreamParser.swift` (new)
- `CitizenRadio/Core/TrackDisplay.swift` (new)
- `CitizenRadio/Core/IcyTitle.swift` (new)
- `Tests/CitizenRadioCoreTests/RelayEventTests.swift`, `EventStreamParserTests.swift`, `TrackDisplayTests.swift`, `IcyTitleTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Use exactly this API. Each file imports only `Foundation`.

```swift
public struct RelayEvent: Equatable, Sendable {
    public enum ParseError: Error, Equatable, LocalizedError {
        case scheme, path, eventID
        public var errorDescription: String? { get }
    }
    public let origin: URL          // scheme, host and port only, for example https://api.musicindex.org
    public let eventID: String
    public init(uri: String) throws  // throws ParseError
    public var displayURL: URL       // <origin>/v1/liveitems/<eventID>/display
    public var displayEventsURL: URL // <origin>/v1/liveitems/<eventID>/display/events
    public func artworkURL(sha256: String) -> URL  // <origin>/v1/liveitems/<eventID>/artwork/<sha256>
}

public struct ServerSentEvent: Equatable, Sendable {
    public let event: String   // "message" if the event has no event field
    public let id: String?     // the last event ID at dispatch time
    public let data: String
}

public struct EventStreamParser: Sendable {
    public init()
    public private(set) var lastEventID: String?
    /// Takes one line without its line terminator. Gives an event when the line is empty and data is present.
    public mutating func feed(line: String) -> ServerSentEvent?
}

public struct TrackDisplay: Equatable, Sendable {
    public enum Artwork: Equatable, Sendable {
        case relay(sha256: String, mime: String)
        case url(URL)
    }
    public enum DecodeError: Error, Equatable { case invalid }
    public let artist: String
    public let title: String
    public let artwork: Artwork?
    public init(artist: String, title: String, artwork: Artwork?)
    /// Decodes a relay display state. Gives nil for {"track": null}.
    public static func decode(_ data: Data) throws -> TrackDisplay?
}

public struct IcyTrack: Equatable, Sendable {
    public let artist: String?
    public let title: String
    public init(artist: String?, title: String)
}

public enum IcyTitle {
    /// Parses an Icecast StreamTitle. Gives nil for an empty text.
    public static func parse(_ text: String) -> IcyTrack?
}
```

`RelayEvent` rules:

- Remove whitespace at the two ends. The scheme must be `https` (compare without case). Else `.scheme`.
- Accept two path forms. Else `.path`:
  - `/v1/liveitems/<id>`, with or without one trailing `/`, with no query.
  - `/event` with a query item `event_id=<id>`.
- The event ID has 1 to 128 characters from `A-Z`, `a-z`, `0-9`, `-` and `_`. Else `.eventID`.
- `origin` keeps the port if the URI has one.
- Error texts, exactly:
  - `.scheme`: "The track info address must start with https."
  - `.path`: "This is not a relay event address."
  - `.eventID`: "The relay event identifier is not correct."

`EventStreamParser` rules (the WHATWG server-sent events format):

- A line that starts with `:` is a comment. Ignore it.
- Split a line at the first `:` into a field and a value. Remove one space at the start of the value, if present. A line with no `:` is a field with an empty value.
- `event` sets the event name. `data` adds the value to the data buffer. More than one `data` line joins with a line feed. `id` sets `lastEventID`, if the value contains no NUL character. Ignore other fields.
- An empty line dispatches. If the data buffer is empty, it gives nil. Else it gives a `ServerSentEvent` with the event name (default "message"), `lastEventID` and the data. Then it clears the event name and the data buffer, but not `lastEventID`.

`TrackDisplay.decode` rules:

- The input is the JSON object `{"track": …}`. `"track": null` gives nil.
- `artist` and `title` are strings. A missing value gives an empty string.
- `artwork` is `null`, missing, `{"sha256": …, "mime": …}` or `{"url": …}`:
  - `sha256` is 64 lowercase hexadecimal characters, and `mime` is `image/jpeg` or `image/png`. Else throw `.invalid`.
  - `url` uses `http` or `https`, has a host, and has 2,048 characters or less. Else throw `.invalid`. A `data:` URL throws `.invalid`.
- JSON that is not an object with a `track` key throws `.invalid`.

`IcyTitle.parse` rules:

1. If the text is empty after you remove whitespace at the two ends, give nil.
2. Find the first " - " (space, hyphen, space) in the original text, before any trim. Without it, give the trimmed text as the title and nil as the artist.
3. Else the part before " - " is the artist, and the part after it is the title. Remove whitespace at the two ends of each part.
4. If the title part is empty, give the trimmed full text as the title and nil as the artist.
5. If the artist part is empty, give nil as the artist.

Other constraints:

- No logging.
- Prose and comments in ASD-STE100. Write a small number of comments, as in the other core files.

## Acceptance criteria

Mechanical (each one is a test):

- `RelayEvent` accepts `https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w`, the same with a trailing `/`, and `https://api.musicindex.org/event?event_id=DFnUwDM1mzcljaF4pI9Q6w`. All three give the same origin and event ID.
- `RelayEvent` keeps a port: `https://relay.example.com:8443/v1/liveitems/abc` gives the origin `https://relay.example.com:8443`.
- `RelayEvent` rejects `http://…` (`.scheme`), `https://host/other/abc` (`.path`), `https://host/event` with no `event_id` (`.path`), and an ID with `/` or `%` (`.eventID`).
- `displayURL`, `displayEventsURL` and `artworkURL(sha256:)` give the exact URLs above.
- `EventStreamParser` gives this event from the live relay text: `event: display`, `id: 1`, `data: {"track":null}`, then an empty line.
- It joins two `data` lines with a line feed, ignores a comment line, uses "message" when no `event` field is present, keeps `lastEventID` for the next event, and gives nil for an empty line with no data.
- `TrackDisplay.decode` decodes the live relay example (artist "Miles Davis", title "Pharaoh's Dance", relay artwork), a URL artwork, a `null` artwork, and `{"track": null}`. It throws for a `data:` URL, an uppercase or short `sha256`, `mime` `image/gif`, and `[]`.
- `IcyTitle.parse` gives these results:

  | Input | Artist | Title |
  | --- | --- | --- |
  | `Miles Davis - Pharaoh's Dance` | `Miles Davis` | `Pharaoh's Dance` |
  | `Pharaoh's Dance` | nil | `Pharaoh's Dance` |
  | `A - B - C` | `A` | `B - C` |
  | ` - Title` | nil | `Title` |
  | `Artist - ` | nil | `Artist -` |
  | three spaces | result is nil | |
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "RelayEventTests|EventStreamParserTests|TrackDisplayTests|IcyTitleTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A rule in this packet disagrees with the live relay text in the research note.
- `URLComponents` does not give the path or the query as the rules require.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-001-parsers.md
- CitizenRadio/Core/NWCConnection.swift
- Tests/CitizenRadioCoreTests/NWCConnectionTests.swift

Goal:
- Add RelayEvent, EventStreamParser, TrackDisplay and IcyTitle to CitizenRadioCore, with tests.

Constraints:
- Use the exact API, rules and error texts in the task file. Only Foundation. No logging.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "RelayEventTests|EventStreamParserTests|TrackDisplayTests|IcyTitleTests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
