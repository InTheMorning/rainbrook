import Foundation

/// A wallet that sends payments. `NWCClient` conforms.
public protocol WalletPaying: Sendable {
    /// Sends the payments and gives one outcome for each payment, in the payment sequence.
    /// A throw means that the wallet sent no payment.
    func pay(_ payments: [NWCPayment]) async throws -> [NWCPaymentOutcome]
}

extension NWCClient: WalletPaying {
    /// Sends the payments with the time limit of ADR 0013 §The payment for each request.
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
    /// One result for each part, in the part sequence. ADR 0013 §The history names the results.
    public let parts: [BoostPartResult]

    /// A result with the part results. The counts come from the part results:
    /// a confirmed part is paid, and an unknown part has an unknown result.
    public init(parts: [BoostPartResult]) {
        let paid = parts.filter { $0.result == .confirmed }
        let unknown = parts.filter { $0.result == .unknown }
        self.paidSats = paid.reduce(0) { $0 + $1.sats }
        self.unknownSats = unknown.reduce(0) { $0 + $1.sats }
        self.paidParts = paid.count
        self.unknownParts = unknown.count
        self.totalParts = parts.count
        self.parts = parts
    }
}

/// Pays the parts of one boost. ADR 0013 §The payment names the sequence.
///
/// The payer gets an invoice for each lightning address part, then sends all parts
/// through the wallet in one call. The payer does not retry a failed part.
/// The payer does not record the spending. The caller records `paidSats + unknownSats`
/// in `SpendingLimitStore` (ADR 0013 §The limits).
public actor BoostPayer {
    private let wallet: any WalletPaying
    private let fetcher: any SnapshotFetching

    public init(wallet: any WalletPaying, fetcher: any SnapshotFetching) {
        self.wallet = wallet
        self.fetcher = fetcher
    }

    /// Never throws. A failed part counts as not paid.
    /// The result has one part result for each part, in the part sequence.
    public func pay(
        parts: [BoostPart], payload: LiveValuePayload, amountSats: Int, sender: BoostSender
    ) async -> BoostResult {
        // The payments, in the part sequence, without the parts that failed before the wallet.
        var payments: [NWCPayment] = []
        // The index of the part of each payment.
        var paymentParts: [Int] = []
        // The result of each part. A part that is not sent stays failed.
        var results = [BoostPaymentResult](repeating: .failed, count: parts.count)

        for (index, part) in parts.enumerated() {
            let amountMsat = Int64(part.sats) * 1000
            switch part.destination.kind {
            case .node(let pubkey):
                let records = BoostRecord.tlvRecords(
                    part: part, payload: payload, totalSats: amountSats, sender: sender
                )
                payments.append(.keysend(KeysendPayment(amountMsat: amountMsat, pubkey: pubkey, tlvRecords: records)))
                paymentParts.append(index)
            case .lightningAddress(let name, let host):
                let comment = LightningAddress.comment(for: sender)
                guard let invoice = await invoice(name: name, host: host, amountMsat: amountMsat, comment: comment) else {
                    continue
                }
                payments.append(.invoice(invoice))
                paymentParts.append(index)
            }
        }

        if !payments.isEmpty {
            // A throw means that the wallet sent no payment, so each sent part stays failed.
            if let outcomes = try? await wallet.pay(payments) {
                // A payment with no outcome stays failed.
                for (index, outcome) in zip(paymentParts, outcomes) {
                    results[index] = BoostPaymentResult(outcome)
                }
            }
        }

        return BoostResult(parts: zip(parts, results).map { part, result in
            BoostPartResult(name: part.destination.name, kind: Self.kind(of: part), sats: part.sats, result: result)
        })
    }

    /// The kind of the part result for a part.
    private static func kind(of part: BoostPart) -> BoostPartResult.Kind {
        switch part.destination.kind {
        case .node:
            return .keysend
        case .lightningAddress:
            return .lightningAddress
        }
    }

    /// The LNURL-pay invoice for one lightning address part.
    /// Gives nil when a request fails, a status is not 200, or a check fails.
    private func invoice(name: String, host: String, amountMsat: Int64, comment: String) async -> String? {
        do {
            let first = try await fetcher.fetch(LightningAddress.wellKnownURL(name: name, host: host))
            guard first.status == 200 else { return nil }
            let request = try LightningAddress.decodePayRequest(first.body)
            let callback = try LightningAddress.callbackURL(for: request, amountMsat: amountMsat, comment: comment)
            let second = try await fetcher.fetch(callback)
            guard second.status == 200 else { return nil }
            return try LightningAddress.decodeInvoice(second.body, amountMsat: amountMsat)
        } catch {
            return nil
        }
    }
}
