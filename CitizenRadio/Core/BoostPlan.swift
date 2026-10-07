import Foundation

/// The reason that the app does not pay a boost.
public enum BoostSkipReason: Equatable, Sendable {
    case disabled, noTrack, noPayload, alreadyPaid, overDailyLimit(remainingSats: Int), nothingToPay
}

/// The decision for one completed track.
public enum BoostDecision: Equatable, Sendable {
    case pay(payload: LiveValuePayload, parts: [BoostPart])
    case skip(BoostSkipReason)
}

/// Decides if the app pays a boost for a completed track.
/// ADR 0013 §The pairing, §The split, §Manual boost and §The limits name the rules.
public enum BoostPlan {
    /// The decision. The rules apply in this sequence:
    /// disabled, noTrack, noPayload, alreadyPaid, overDailyLimit, nothingToPay.
    public static func decide(
        enabled: Bool, amountSats: Int, track: TrackDisplay?, pairing: BoostPairing,
        paidBlocks: Set<String>, limit: SpendingLimit, day: String
    ) -> BoostDecision {
        guard enabled else { return .skip(.disabled) }
        guard let track else { return .skip(.noTrack) }
        guard let payload = pairing.payload(for: track) else { return .skip(.noPayload) }
        guard !paidBlocks.contains(payload.blockGuid) else { return .skip(.alreadyPaid) }
        guard limit.permits(amountSats, on: day) else {
            return .skip(.overDailyLimit(remainingSats: limit.remaining(on: day)))
        }
        let parts = BoostSplit.parts(amountSats: amountSats, destinations: payload.destinations)
        guard !parts.isEmpty else { return .skip(.nothingToPay) }
        return .pay(payload: payload, parts: parts)
    }

    /// A manual boost: no enabled check, no paid block check and no daily limit check (ADR 0013 §The limits).
    /// The rules apply in this sequence: noTrack, noPayload, nothingToPay.
    public static func decideManual(amountSats: Int, track: TrackDisplay?, pairing: BoostPairing) -> BoostDecision {
        guard let track else { return .skip(.noTrack) }
        guard let payload = pairing.payload(for: track) else { return .skip(.noPayload) }
        let parts = BoostSplit.parts(amountSats: amountSats, destinations: payload.destinations)
        guard !parts.isEmpty else { return .skip(.nothingToPay) }
        return .pay(payload: payload, parts: parts)
    }
}
