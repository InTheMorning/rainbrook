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
/// through the wallet in one call. `retry(parts:)` sends the retryable parts again (ADR 0016 §The retry).
/// The payer does not record the spending. The caller records `paidSats + unknownSats`
/// in `SpendingLimitStore` (ADR 0013 §The limits).
public actor BoostPayer {
    /// The result and the failure reason of one part that the payer tried to pay.
    private struct Attempt {
        let result: BoostPaymentResult
        let failure: BoostFailure?
    }

    private let wallet: any WalletPaying
    private let fetcher: any SnapshotFetching

    public init(wallet: any WalletPaying, fetcher: any SnapshotFetching) {
        self.wallet = wallet
        self.fetcher = fetcher
    }

    /// Never throws. A failed part counts as not paid.
    /// The result has one part result for each part, in the part sequence.
    /// A part with a retryable failure keeps the data to send it again.
    public func pay(
        parts: [BoostPart], payload: LiveValuePayload, amountSats: Int, sender: BoostSender
    ) async -> BoostResult {
        let payments: [BoostRetryPayment] = parts.map { part in
            let amountMsat = Int64(part.sats) * 1000
            switch part.destination.kind {
            case .node(let pubkey):
                let records = BoostRecord.tlvRecords(
                    part: part, payload: payload, totalSats: amountSats, sender: sender
                )
                return .keysend(pubkey: pubkey, amountMsat: amountMsat, tlvRecords: records)
            case .lightningAddress(let name, let host):
                let comment = LightningAddress.comment(for: sender)
                return .lightningAddress(name: name, host: host, amountMsat: amountMsat, comment: comment)
            }
        }
        let attempts = await send(payments)

        return BoostResult(parts: parts.indices.map { index in
            let part = parts[index]
            // Each part is sent, so each part has an attempt.
            let attempt = attempts[index] ?? Attempt(result: .failed, failure: .notSent)
            // The initializer keeps the retry data only for a retryable failure.
            return BoostPartResult(
                name: part.destination.name, kind: Self.kind(of: part), sats: part.sats,
                result: attempt.result, failure: attempt.failure, retry: payments[index], attempts: 1
            )
        })
    }

    /// Sends each retryable part again, in one wallet call. Other parts stay unchanged.
    /// Gives the full list in the same sequence. A retried part has attempts + 1.
    ///
    /// A part with the result unknown or confirmed is never sent.
    /// A failed part with no retry data is never sent.
    public func retry(parts: [BoostPartResult]) async -> [BoostPartResult] {
        let payments: [BoostRetryPayment?] = parts.map { $0.isRetryable ? $0.retry : nil }
        let attempts = await send(payments)

        return parts.indices.map { index in
            let part = parts[index]
            guard let payment = payments[index] else { return part }
            let attempt = attempts[index] ?? Attempt(result: .failed, failure: .notSent)
            return BoostPartResult(
                name: part.name, kind: part.kind, sats: part.sats,
                result: attempt.result, failure: attempt.failure, retry: payment, attempts: part.attempts + 1
            )
        }
    }

    /// Sends the given payments through the wallet in one call.
    /// A nil payment is not sent and gives a nil attempt.
    ///
    /// A lightning address payment first gets a new invoice. When the LNURL requests or checks fail,
    /// the part fails with the reason lightning address, and the wallet does not get it.
    /// A wallet throw gives the reason not sent for each part in the call.
    private func send(_ payments: [BoostRetryPayment?]) async -> [Attempt?] {
        var attempts = [Attempt?](repeating: nil, count: payments.count)
        // The wallet payments, in the part sequence.
        var walletPayments: [NWCPayment] = []
        // The index of the part of each wallet payment.
        var walletParts: [Int] = []

        for (index, payment) in payments.enumerated() {
            switch payment {
            case nil:
                continue
            case .keysend(let pubkey, let amountMsat, let records)?:
                walletPayments.append(.keysend(KeysendPayment(amountMsat: amountMsat, pubkey: pubkey, tlvRecords: records)))
                walletParts.append(index)
            case .lightningAddress(let name, let host, let amountMsat, let comment)?:
                guard let invoice = await invoice(name: name, host: host, amountMsat: amountMsat, comment: comment) else {
                    attempts[index] = Attempt(result: .failed, failure: .lightningAddress)
                    continue
                }
                walletPayments.append(.invoice(invoice))
                walletParts.append(index)
            }
        }

        guard !walletPayments.isEmpty else { return attempts }

        let outcomes: [NWCPaymentOutcome]
        do {
            outcomes = try await wallet.pay(walletPayments)
        } catch {
            // A throw means that the wallet sent no payment.
            for index in walletParts {
                attempts[index] = Attempt(result: .failed, failure: .notSent)
            }
            return attempts
        }

        for (position, index) in walletParts.enumerated() {
            guard position < outcomes.count else {
                // The wallet gave no outcome for this payment. It can have sent it,
                // so the part is failed with a reason that is not retryable.
                attempts[index] = Attempt(result: .failed, failure: .invalidResponse)
                continue
            }
            let outcome = outcomes[position]
            attempts[index] = Attempt(result: BoostPaymentResult(outcome), failure: BoostFailure(outcome))
        }
        return attempts
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
