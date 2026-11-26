import Foundation

/// Reads the amount of a BOLT11 invoice.
/// The type does not examine the signature or the checksum.
public enum Bolt11 {
    /// The network names after "ln". The longer names come first.
    private static let networks = ["bcrt", "bc", "tbs", "tb", "sb"]

    /// The invoice amount in millisats, or nil for no amount or an invalid amount.
    public static func amountMsat(_ invoice: String) -> Int64? {
        let text = invoice.lowercased()
        guard text.hasPrefix("ln"), let separator = text.lastIndex(of: "1") else {
            return nil
        }
        let prefix = text[text.index(text.startIndex, offsetBy: 2)..<separator]
        guard let network = networks.first(where: { prefix.hasPrefix($0) }) else {
            return nil
        }
        var amount = prefix.dropFirst(network.count)

        var multiplier: Character?
        if let last = amount.last, "munp".contains(last) {
            multiplier = last
            amount = amount.dropLast()
        }

        guard let first = amount.first, first != "0",
              amount.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int64(amount) else {
            return nil
        }

        switch multiplier {
        case nil: return multiply(value, by: 100_000_000_000)
        case "m": return multiply(value, by: 100_000_000)
        case "u": return multiply(value, by: 100_000)
        case "n": return multiply(value, by: 100)
        case "p": return value % 10 == 0 ? value / 10 : nil
        default: return nil
        }
    }

    /// The value multiplied by the factor, or nil for an overflow.
    private static func multiply(_ value: Int64, by factor: Int64) -> Int64? {
        let (product, overflow) = value.multipliedReportingOverflow(by: factor)
        return overflow ? nil : product
    }
}
