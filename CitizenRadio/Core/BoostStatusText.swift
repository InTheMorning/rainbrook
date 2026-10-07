import Foundation

/// The user texts for the boost result line in Settings.
/// ADR 0012 §The limits names the reasons. The task 005 packet gives the texts.
public enum BoostStatusText {
    /// The text after a boost.
    public static func text(for result: BoostResult) -> String {
        guard result.paidParts > 0 || result.unknownParts > 0 else {
            return "The boost failed. No payment was sent."
        }
        var sentences: [String] = []
        if result.paidParts > 0 {
            sentences.append("Boosted \(result.paidSats) sats.")
        }
        let failed = result.totalParts - result.paidParts - result.unknownParts
        if failed > 0 {
            sentences.append("\(failed) of \(result.totalParts) payments failed.")
        }
        if result.unknownParts > 0 {
            sentences.append("The result of \(result.unknownParts) payments is not known.")
        }
        return sentences.joined(separator: " ")
    }

    /// The text for a boost that did not occur. Gives nil when the reason needs no message.
    public static func text(for reason: BoostSkipReason) -> String? {
        switch reason {
        case .overDailyLimit(let remainingSats):
            return "No boost. Only \(remainingSats) sats of the daily limit remain."
        case .nothingToPay:
            return "No boost. The track has no payment destination."
        case .tooShort(let seconds):
            return "No boost. The track played for less than \(seconds) seconds."
        case .disabled, .noTrack, .noPayload, .alreadyPaid:
            return nil
        }
    }

    /// The text when no wallet is connected.
    public static let noWallet = "No boost. Connect a wallet."
}
