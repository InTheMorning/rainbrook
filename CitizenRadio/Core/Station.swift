import Foundation

/// A station the app can play. ADR 0017 §The station.
public struct Station: Codable, Equatable, Sendable, Identifiable {
    /// The highest number of characters that the name keeps.
    public static let maxNameLength = 40

    public let id: UUID
    public let name: String
    public let stream: URL
    public let alternateStream: URL?
    /// The relay event URI text, or nil.
    public let trackInfo: String?

    /// The primary stream, then the alternate stream if there is one.
    public var streams: [URL] {
        guard let alternateStream else { return [stream] }
        return [stream, alternateStream]
    }

    /// The relay event, or nil.
    public var event: RelayEvent? {
        guard let trackInfo else { return nil }
        return try? RelayEvent(uri: trackInfo)
    }

    /// Validates the texts. Each text is trimmed first.
    /// - name: An empty name gives the host of the stream. A longer name is cut to maxNameLength.
    /// - streamText: StreamAddress rules apply.
    /// - alternateStreamText: An empty text gives nil. Else StreamAddress rules apply.
    ///   The result must be different from the stream.
    /// - trackInfoText: An empty text gives nil. Else RelayEvent(uri:) must parse.
    public init(
        id: UUID = UUID(),
        name: String,
        streamText: String,
        alternateStreamText: String,
        trackInfoText: String
    ) throws {
        let streamAddress: StreamAddress
        do {
            streamAddress = try StreamAddress(streamText)
        } catch let error as StreamAddress.ValidationError {
            throw StationError.stream(error)
        }

        let alternateURL = try Self.validatedAlternate(alternateStreamText, stream: streamAddress.url)
        let trackInfo = try Self.validatedTrackInfo(trackInfoText)

        self.id = id
        self.name = Self.resolvedName(name, host: streamAddress.url.host ?? "")
        self.stream = streamAddress.url
        self.alternateStream = alternateURL
        self.trackInfo = trackInfo
    }

    /// Checks the alternate stream text. An empty text gives nil.
    private static func validatedAlternate(_ text: String, stream: URL) throws -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let alternateAddress: StreamAddress
        do {
            alternateAddress = try StreamAddress(trimmed)
        } catch let error as StreamAddress.ValidationError {
            throw StationError.alternateStream(error)
        }

        guard alternateAddress.url != stream else {
            throw StationError.sameStreams
        }
        return alternateAddress.url
    }

    /// Checks the Track info text. An empty text gives nil.
    private static func validatedTrackInfo(_ text: String) throws -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard (try? RelayEvent(uri: trimmed)) != nil else {
            throw StationError.trackInfo
        }
        return trimmed
    }

    /// Resolves the name. An empty name gives the host. A long name is cut.
    private static func resolvedName(_ name: String, host: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return host }
        guard trimmed.count > Self.maxNameLength else { return trimmed }
        return String(trimmed.prefix(Self.maxNameLength))
    }
}

/// An error from a station field. ADR 0017 §The station.
public enum StationError: LocalizedError, Equatable {
    case stream(StreamAddress.ValidationError)
    case alternateStream(StreamAddress.ValidationError)
    case sameStreams
    case trackInfo
    case listFull

    public var errorDescription: String? {
        switch self {
        case .stream(let error):
            return error.errorDescription
        case .alternateStream(let error):
            return Self.alternateDescription(error)
        case .sameStreams:
            return "The alternate stream must be different from the stream."
        case .trackInfo:
            return "Enter a correct relay event address, or leave Track info empty."
        case .listFull:
            return "Delete a station first. The list already has \(StationStore.maximumCount) stations."
        }
    }

    /// This text names "alternate". The operator can then tell this error from a stream error.
    private static func alternateDescription(_ error: StreamAddress.ValidationError) -> String {
        switch error {
        case .empty:
            return "Enter an alternate stream URL, or leave it empty."
        case .invalidURL:
            return "Enter a complete HTTP or HTTPS alternate stream URL."
        case .credentials:
            return "Use an alternate stream URL without a username or password."
        case .fragment:
            return "Remove the fragment after the # character from the alternate stream URL."
        }
    }
}
