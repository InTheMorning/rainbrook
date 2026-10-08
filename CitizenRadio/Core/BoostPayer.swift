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

/// Pays the parts of one boost. ADR 0013 §The payment and ADR 0023 §A lightning address part name the sequence.
///
/// The payer reads the keysend answer of each lightning address part. A part with a correct answer gets
/// a keysend payment. Each other lightning address part gets an invoice. All first payments go through
/// the wallet in one call. Then a lightning address keysend with a wallet error or "not supported" gets
/// an invoice. All these invoices go through the wallet in a second call.
/// `retry(parts:)` sends the retryable parts again (ADR 0016 §The retry).
/// The payer does not record the spending. The caller records `paidSats + unknownSats`
/// in `SpendingLimitStore` (ADR 0013 §The limits).
public actor BoostPayer {
    /// The result, the failure reason and the path of one part that the payer tried to pay.
    private struct Attempt {
        let result: BoostPaymentResult
        let failure: BoostFailure?
        let path: BoostPaymentPath

        init(result: BoostPaymentResult, failure: BoostFailure?, path: BoostPaymentPath) {
            self.result = result
            self.failure = failure
            self.path = path
        }

        /// The attempt of one wallet outcome on the given path.
        init(outcome: NWCPaymentOutcome, path: BoostPaymentPath) {
            self.init(result: BoostPaymentResult(outcome), failure: BoostFailure(outcome), path: path)
        }
    }

    /// The data of a lightning address part for an invoice.
    private struct InvoiceRequest {
        let name: String
        let host: String
        let amountMsat: Int64
        let comment: String
        let payerName: String?
    }

    /// One payment for a wallet call, with its part index.
    private struct WalletItem {
        let index: Int
        let payment: NWCPayment
        let path: BoostPaymentPath
        /// The invoice data when this is a lightning address keysend. Nil for all other payments.
        let fallback: InvoiceRequest?
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
    /// Each part of the boost gets the same `context` in its boost record (ADR 0023 §The boost record).
    public func pay(
        parts: [BoostPart], payload: LiveValuePayload, amountSats: Int, sender: BoostSender, context: BoostContext
    ) async -> BoostResult {
        let payments: [BoostRetryPayment] = parts.map { part in
            let amountMsat = Int64(part.sats) * 1000
            let records = BoostRecord.tlvRecords(
                part: part, payload: payload, totalSats: amountSats, sender: sender, context: context
            )
            switch part.destination.kind {
            case .node(let pubkey):
                return .keysend(pubkey: pubkey, amountMsat: amountMsat, tlvRecords: records)
            case .lightningAddress(let name, let host):
                let comment = LightningAddress.comment(for: sender)
                return .lightningAddress(
                    name: name, host: host, amountMsat: amountMsat, comment: comment,
                    tlvRecords: records, payerName: sender.senderName
                )
            }
        }
        let attempts = await send(payments)

        return BoostResult(parts: parts.indices.map { index in
            let part = parts[index]
            // Each part is sent, so each part has an attempt.
            let attempt = attempts[index] ?? Attempt(result: .failed, failure: .notSent, path: Self.firstPath(of: payments[index]))
            // The initializer keeps the retry data only for a retryable failure.
            return BoostPartResult(
                name: part.destination.name, kind: Self.kind(of: part), sats: part.sats,
                result: attempt.result, failure: attempt.failure, retry: payments[index], attempts: 1,
                path: attempt.path
            )
        })
    }

    /// Sends each retryable part again. Other parts stay unchanged.
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
            let attempt = attempts[index] ?? Attempt(result: .failed, failure: .notSent, path: Self.firstPath(of: payment))
            return BoostPartResult(
                name: part.name, kind: part.kind, sats: part.sats,
                result: attempt.result, failure: attempt.failure, retry: payment, attempts: part.attempts + 1,
                path: attempt.path
            )
        }
    }

    /// Sends the given payments. A nil payment is not sent and gives a nil attempt.
    ///
    /// A lightning address payment with a boost record first reads the keysend answer.
    /// A correct answer gives a keysend payment. Else the part gets a new invoice.
    /// When the LNURL requests or checks fail, the part fails with the reason lightning address,
    /// and the wallet does not get it.
    /// After the first wallet call, a lightning address keysend with a wallet error or "not supported"
    /// gets an invoice. These invoices go in a second wallet call (ADR 0023 §A lightning address part).
    private func send(_ payments: [BoostRetryPayment?]) async -> [Attempt?] {
        var attempts = [Attempt?](repeating: nil, count: payments.count)
        var items: [WalletItem] = []

        for (index, payment) in payments.enumerated() {
            switch payment {
            case nil:
                continue
            case .keysend(let pubkey, let amountMsat, let records)?:
                let keysend = KeysendPayment(amountMsat: amountMsat, pubkey: pubkey, tlvRecords: records)
                items.append(WalletItem(index: index, payment: .keysend(keysend), path: .keysend, fallback: nil))
            case .lightningAddress(let name, let host, let amountMsat, let comment, let records, let payerName)?:
                let request = InvoiceRequest(
                    name: name, host: host, amountMsat: amountMsat, comment: comment, payerName: payerName
                )
                // A part of a history file with no boost record gets only an invoice.
                if let records, !records.isEmpty, let target = await keysendTarget(name: name, host: host) {
                    let keysend = KeysendPayment(
                        amountMsat: amountMsat, pubkey: target.pubkey, tlvRecords: records + target.records
                    )
                    items.append(WalletItem(index: index, payment: .keysend(keysend), path: .keysend, fallback: request))
                } else if let invoice = await invoice(request) {
                    items.append(WalletItem(index: index, payment: .invoice(invoice), path: .invoice, fallback: nil))
                } else {
                    attempts[index] = Attempt(result: .failed, failure: .lightningAddress, path: .invoice)
                }
            }
        }

        var fallbacks: [(index: Int, request: InvoiceRequest)] = []
        for (item, outcome) in await walletOutcomes(items) {
            if let request = item.fallback, Self.permitsInvoice(after: outcome) {
                fallbacks.append((item.index, request))
            } else {
                attempts[item.index] = Attempt(outcome: outcome, path: item.path)
            }
        }

        guard !fallbacks.isEmpty else { return attempts }

        var invoiceItems: [WalletItem] = []
        for fallback in fallbacks {
            if let invoice = await invoice(fallback.request) {
                invoiceItems.append(WalletItem(index: fallback.index, payment: .invoice(invoice), path: .invoice, fallback: nil))
            } else {
                attempts[fallback.index] = Attempt(result: .failed, failure: .lightningAddress, path: .invoice)
            }
        }
        for (item, outcome) in await walletOutcomes(invoiceItems) {
            attempts[item.index] = Attempt(outcome: outcome, path: item.path)
        }
        return attempts
    }

    /// Sends the payments of the items through the wallet in one call, and gives one outcome for each item.
    /// No item gives no wallet call.
    ///
    /// A wallet throw gives the outcome not sent for each item.
    /// A missing outcome gives invalidResponse: the wallet can have sent the payment, so it is not retryable.
    private func walletOutcomes(_ items: [WalletItem]) async -> [(WalletItem, NWCPaymentOutcome)] {
        guard !items.isEmpty else { return [] }
        let outcomes: [NWCPaymentOutcome]
        do {
            outcomes = try await wallet.pay(items.map(\.payment))
        } catch {
            // A throw means that the wallet sent no payment.
            return items.map { ($0, .notSent) }
        }
        return items.enumerated().map { position, item in
            (item, position < outcomes.count ? outcomes[position] : .invalidResponse)
        }
    }

    /// True for the outcomes after which a lightning address keysend gets an invoice (ADR 0023 §A lightning address part).
    /// A paid, unknown or invalid result never gets an invoice, so the part is never paid two times.
    private static func permitsInvoice(after outcome: NWCPaymentOutcome) -> Bool {
        switch outcome {
        case .walletError, .unsupported:
            return true
        case .paid, .timeout, .invalidResponse, .notSent:
            return false
        }
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

    /// The path of a payment before the payer sends it.
    private static func firstPath(of payment: BoostRetryPayment) -> BoostPaymentPath {
        switch payment {
        case .keysend:
            return .keysend
        case .lightningAddress:
            return .invoice
        }
    }

    /// The keysend target of a lightning address (ADR 0023 §A lightning address part).
    /// Gives nil when the request fails, the status is not 200, or a check fails.
    private func keysendTarget(name: String, host: String) async -> LightningAddress.KeysendTarget? {
        do {
            let response = try await fetcher.fetch(LightningAddress.keysendURL(name: name, host: host))
            guard response.status == 200 else { return nil }
            return try LightningAddress.decodeKeysend(response.body)
        } catch {
            return nil
        }
    }

    /// The LNURL-pay invoice for one lightning address part.
    /// Gives nil when a request fails, a status is not 200, or a check fails.
    private func invoice(_ request: InvoiceRequest) async -> String? {
        do {
            let first = try await fetcher.fetch(LightningAddress.wellKnownURL(name: request.name, host: request.host))
            guard first.status == 200 else { return nil }
            let payRequest = try LightningAddress.decodePayRequest(first.body)
            let callback = try LightningAddress.callbackURL(
                for: payRequest, amountMsat: request.amountMsat, comment: request.comment, payerName: request.payerName
            )
            let second = try await fetcher.fetch(callback)
            guard second.status == 200 else { return nil }
            return try LightningAddress.decodeInvoice(second.body, amountMsat: request.amountMsat)
        } catch {
            return nil
        }
    }
}
