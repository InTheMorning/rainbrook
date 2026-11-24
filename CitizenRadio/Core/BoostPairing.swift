import Foundation

/// Pairs a completed relay track with its live value payload.
/// ADR 0013 §The pairing and ADR 0026 name the rules this type enforces.
public struct BoostPairing: Equatable, Sendable {
    /// The highest number of payloads that the list keeps.
    public static let capacity = 8

    /// The payloads, newest first. The list holds a maximum of `capacity` payloads.
    /// No two payloads share a blockGuid.
    private var payloads: [LiveValuePayload] = []

    public init() {}

    /// Adds a payload as the newest. A payload with an equal blockGuid replaces the older one.
    public mutating func receive(_ payload: LiveValuePayload) {
        payloads.removeAll { $0.blockGuid == payload.blockGuid }
        payloads.insert(payload, at: 0)
        if payloads.count > Self.capacity {
            payloads.removeLast(payloads.count - Self.capacity)
        }
    }

    /// Removes all stored payloads.
    public mutating func clear() {
        payloads.removeAll()
    }

    /// The payload to pay for this relay track, or nil.
    /// ADR 0013 §The pairing and ADR 0026 name the rules.
    public func payload(for track: TrackDisplay) -> LiveValuePayload? {
        if let value = track.value {
            guard let match = payloads.first(where: { $0.blockGuid == value.blockGuid }),
                  match.isPayable else {
                return nil
            }
            return match
        }

        // ADR 0026 §The title pairing: the key of the track first, then its title.
        // The key is the song line, or "artist - title" (IcySync.key).
        for text in [IcySync.key(of: track), IcySync.normalize(track.title)] {
            if let match = payloads.first(where: { $0.isPayable && IcySync.normalize($0.title) == text }) {
                return match
            }
        }
        return nil
    }
}
