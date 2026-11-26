import Foundation

/// One part of a boost: the destination and the sats it gets.
public struct BoostPart: Equatable, Sendable {
    public let destination: LiveValueDestination
    public let sats: Int
}

/// One payable destination in the split that the boost sheet shows.
///
/// `percent` is the share of the amount that the `split` values give, before rounding.
/// `sats` is what the app pays. It is 0 for a part that rounds down to less than 1 sat.
public struct BoostShare: Equatable, Sendable {
    public let destination: LiveValueDestination
    public let percent: Double
    public let sats: Int
}

/// Divides a boost amount among the payable destinations.
/// ADR 0012 §The split names the rules this type enforces.
public enum BoostSplit {
    /// The parts of the boost, in destination order.
    ///
    /// The function calculates in millisats. It rounds each part down to full sats.
    /// It leaves out a part of 0 sats. The sum of the parts is not more than the amount.
    public static func parts(amountSats: Int, destinations: [LiveValueDestination]) -> [BoostPart] {
        shares(amountSats: amountSats, destinations: destinations)
            .filter { $0.sats > 0 }
            .map { BoostPart(destination: $0.destination, sats: $0.sats) }
    }

    /// Each payable destination with its percentage and its paid sats, in destination order.
    ///
    /// A share of 0 sats stays in the result. It gives an empty result when `parts` gives no parts
    /// for a reason other than rounding: an amount of 0, an overflow, or fee splits over 100 %.
    public static func shares(amountSats: Int, destinations: [LiveValueDestination]) -> [BoostShare] {
        guard amountSats > 0 else { return [] }
        let (total, overflow) = Int64(amountSats).multipliedReportingOverflow(by: 1000)
        guard !overflow else { return [] }

        // The millisats of each destination, in destination order.
        var msats = [Int64](repeating: 0, count: destinations.count)
        var percents = [Double](repeating: 0, count: destinations.count)

        var feeSum: Int64 = 0
        var feePercent = 0.0
        for (index, destination) in destinations.enumerated() where destination.fee {
            guard let part = share(of: total, split: destination.split, divisor: 100) else {
                return []
            }
            let (sum, sumOverflow) = feeSum.addingReportingOverflow(part)
            guard !sumOverflow, sum <= total else { return [] }
            feeSum = sum
            msats[index] = part
            if isUsable(destination.split) {
                percents[index] = destination.split
                feePercent += destination.split
            }
        }

        let rest = total - feeSum
        let restPercent = max(0, 100 - feePercent)
        let splitSum = destinations
            .filter { !$0.fee && isUsable($0.split) }
            .reduce(0.0) { $0 + $1.split }
        if splitSum > 0, splitSum.isFinite {
            var assigned: Int64 = 0
            for (index, destination) in destinations.enumerated() where !destination.fee {
                guard let part = share(of: rest, split: destination.split, divisor: splitSum) else {
                    continue
                }
                // A floating point error must not make the sum more than the remaining millisats.
                let capped = min(part, rest - assigned)
                assigned += capped
                msats[index] = capped
                if isUsable(destination.split) {
                    percents[index] = restPercent * destination.split / splitSum
                }
            }
        }

        return destinations.enumerated().map { index, destination in
            BoostShare(destination: destination, percent: percents[index], sats: Int(msats[index] / 1000))
        }
    }

    /// True for a split that is finite and more than 0.
    private static func isUsable(_ split: Double) -> Bool {
        split.isFinite && split > 0
    }

    /// floor(amount * split / divisor) in millisats.
    /// Gives 0 for a split that is not usable. Gives nil when the result is too large for Int64.
    private static func share(of amount: Int64, split: Double, divisor: Double) -> Int64? {
        guard isUsable(split) else { return 0 }
        let value = (Double(amount) * split / divisor).rounded(.down)
        guard value.isFinite, value < 9_223_372_036_854_775_807.0 else { return nil }
        return Int64(value)
    }
}
