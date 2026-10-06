import Foundation

/// Pairs a completed relay track with its live value payload.
/// ADR 0012 §The pairing names the rules this type enforces.
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
    /// ADR 0012 §The pairing names the rules.
    public func payload(for track: TrackDisplay) -> LiveValuePayload? {
        if let value = track.value {
            guard let match = payloads.first(where: { $0.blockGuid == value.blockGuid }),
                  match.isPayable else {
                return nil
            }
            return match
        }

        let normalizedTitle = IcySync.normalize(track.title)
        return payloads.first { $0.isPayable && IcySync.normalize($0.title) == normalizedTitle }
    }
}
