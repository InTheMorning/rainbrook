import Foundation

/// A wallet that sends payments. `NWCClient` conforms.
public protocol WalletPaying: Sendable {
    /// Sends the payments and gives one outcome for each payment, in the payment sequence.
    /// A throw means that the wallet sent no payment.
    func pay(_ payments: [NWCPayment]) async throws -> [NWCPaymentOutcome]
}

extension NWCClient: WalletPaying {
    /// Sends the payments with the time limit of ADR 0012 §The payment for each request.
    public func pay(_ payments: [NWCPayment]) async throws -> [NWCPaymentOutcome] {
        try await pay(payments, requestTimeout: .seconds(30))
    }
}

/// The result of one boost.
public struct BoostResult: Equatable, Sendable {
    /// The sum of the parts with the outcome `.paid`.
    public let paidSats: Int
    /// The sum of the parts with the outcome `.timeout`. The wallet can have paid them.
    public let unknownSats: Int
    public let paidParts: Int
    public let unknownParts: Int
    public let totalParts: Int

    public init(paidSats: Int, unknownSats: Int, paidParts: Int, unknownParts: Int, totalParts: Int) {
        self.paidSats = paidSats
        self.unknownSats = unknownSats
        self.paidParts = paidParts
        self.unknownParts = unknownParts
        self.totalParts = totalParts
    }
}

/// Pays the parts of one boost. ADR 0012 §The payment names the sequence.
///
/// The payer gets an invoice for each lightning address part, then sends all parts
/// through the wallet in one call. The payer does not retry a failed part.
/// The payer does not record the spending. The caller records `paidSats + unknownSats`
/// in `SpendingLimitStore` (ADR 0012 §The limits).
public actor BoostPayer {
    private let wallet: any WalletPaying
    private let fetcher: any SnapshotFetching

    public init(wallet: any WalletPaying, fetcher: any SnapshotFetching) {
        self.wallet = wallet
        self.fetcher = fetcher
    }

    /// Never throws. A failed part counts as not paid.
    public func pay(parts: [BoostPart], payload: LiveValuePayload, amountSats: Int) async -> BoostResult {
        // The payments and the sats of each payment, in the part sequence, without the failed parts.
        var payments: [NWCPayment] = []
        var paymentSats: [Int] = []

        for part in parts {
            let amountMsat = Int64(part.sats) * 1000
            switch part.destination.kind {
            case .node(let pubkey):
                let records = BoostRecord.tlvRecords(part: part, payload: payload, totalSats: amountSats)
                payments.append(.keysend(KeysendPayment(amountMsat: amountMsat, pubkey: pubkey, tlvRecords: records)))
                paymentSats.append(part.sats)
            case .lightningAddress(let name, let host):
                guard let invoice = await invoice(name: name, host: host, amountMsat: amountMsat) else {
                    continue
                }
                payments.append(.invoice(invoice))
                paymentSats.append(part.sats)
            }
        }

        guard !payments.isEmpty else {
            return BoostResult(paidSats: 0, unknownSats: 0, paidParts: 0, unknownParts: 0, totalParts: parts.count)
        }

        let outcomes: [NWCPaymentOutcome]
        do {
            outcomes = try await wallet.pay(payments)
        } catch {
            return BoostResult(paidSats: 0, unknownSats: 0, paidParts: 0, unknownParts: 0, totalParts: parts.count)
        }

        var paidSats = 0
        var unknownSats = 0
        var paidParts = 0
        var unknownParts = 0
        // A payment with no outcome counts as failed.
        for (sats, outcome) in zip(paymentSats, outcomes) {
            switch outcome {
            case .paid:
                paidSats += sats
                paidParts += 1
            case .timeout:
                unknownSats += sats
                unknownParts += 1
            case .unsupported, .walletError, .invalidResponse, .notSent:
                break
            }
        }
        return BoostResult(
            paidSats: paidSats, unknownSats: unknownSats,
            paidParts: paidParts, unknownParts: unknownParts, totalParts: parts.count
        )
    }

    /// The LNURL-pay invoice for one lightning address part.
    /// Gives nil when a request fails, a status is not 200, or a check fails.
    private func invoice(name: String, host: String, amountMsat: Int64) async -> String? {
        do {
            let first = try await fetcher.fetch(LightningAddress.wellKnownURL(name: name, host: host))
            guard first.status == 200 else { return nil }
            let request = try LightningAddress.decodePayRequest(first.body)
            let callback = try LightningAddress.callbackURL(for: request, amountMsat: amountMsat)
            let second = try await fetcher.fetch(callback)
            guard second.status == 200 else { return nil }
            return try LightningAddress.decodeInvoice(second.body, amountMsat: amountMsat)
        } catch {
            return nil
        }
    }
}
