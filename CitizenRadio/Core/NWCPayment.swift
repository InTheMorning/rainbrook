import Foundation

/// One TLV record of a keysend payment.
public struct TLVRecord: Codable, Equatable, Sendable {
    public let type: UInt64
    /// The value as lowercase hexadecimal text.
    public let value: String

    public init(type: UInt64, value: String) {
        self.type = type
        self.value = value
    }
}

/// The data for one NIP-47 `pay_keysend` request.
public struct KeysendPayment: Equatable, Sendable {
    public let amountMsat: Int64
    public let pubkey: String
    public let tlvRecords: [TLVRecord]

    public init(amountMsat: Int64, pubkey: String, tlvRecords: [TLVRecord]) {
        self.amountMsat = amountMsat
        self.pubkey = pubkey
        self.tlvRecords = tlvRecords
    }
}

/// One payment that `NWCClient.pay(_:requestTimeout:)` sends to the wallet.
///
/// ADR 0012 §The payment names the two kinds of payment.
public enum NWCPayment: Equatable, Sendable {
    case keysend(KeysendPayment)
    case invoice(String)

    /// The NIP-47 method for this payment.
    var method: String {
        switch self {
        case .keysend: "pay_keysend"
        case .invoice: "pay_invoice"
        }
    }

    /// The plaintext content of the NIP-47 request.
    ///
    /// The keys are in alphabetical sequence. A keysend payment with no TLV records
    /// has no `tlv_records` key.
    func requestContent() throws -> String {
        let params: [String: Any]
        switch self {
        case .keysend(let payment):
            var keysend: [String: Any] = ["amount": payment.amountMsat, "pubkey": payment.pubkey]
            if !payment.tlvRecords.isEmpty {
                keysend["tlv_records"] = payment.tlvRecords.map { ["type": $0.type, "value": $0.value] as [String: Any] }
            }
            params = keysend
        case .invoice(let invoice):
            params = ["invoice": invoice]
        }
        let object: [String: Any] = ["method": method, "params": params]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

/// The result of one payment request.
public enum NWCPaymentOutcome: Equatable, Sendable {
    /// The wallet sent a `result` object.
    case paid
    /// The wallet does not list the method. The client sent no request.
    case unsupported
    /// The wallet sent an `error` object, or the relay did not accept the request.
    case walletError(code: String, message: String)
    /// The wallet sent no response in the time limit, or the connection failed after the request.
    /// The wallet can have paid it.
    case timeout
    /// The response content was not a valid NIP-47 response.
    case invalidResponse
    /// The connection failed before this payment, so the client did not send it.
    case notSent
}
