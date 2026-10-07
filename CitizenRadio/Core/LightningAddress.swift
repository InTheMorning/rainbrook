import Foundation

/// The LNURL-pay rules for a lightning address (LUD-06, LUD-12 and LUD-16).
/// ADR 0013 §The payment names the checks. This type makes no request.
public enum LightningAddress {
    /// The fields of a LUD-06 payRequest response that the app uses.
    public struct PayRequest: Equatable, Sendable {
        public let callback: URL
        public let minSendable: Int64
        public let maxSendable: Int64
        public let commentAllowed: Int
    }

    public enum Failure: Error, Equatable {
        case invalidResponse, notPayRequest, insecureCallback, amountOutOfRange, invoiceAmountMismatch
        case serviceError(String)
    }

    /// The comment that the app sends when the service permits a comment.
    /// It is the boost message. With no message, it is "Boost from" and the app name.
    public static func comment(for sender: BoostSender) -> String {
        sender.message ?? "Boost from \(sender.appName)"
    }

    /// The LUD-16 address: https://{host}/.well-known/lnurlp/{name}.
    public static func wellKnownURL(name: String, host: String) -> URL {
        let safeHost = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? host
        let safeName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        // The percent encoding makes a correct URL from each name and host.
        // The fallback uses a reserved host, so a request to it cannot pay.
        return URL(string: "https://\(safeHost)/.well-known/lnurlp/\(safeName)")
            ?? URL(string: "https://invalid.invalid")!
    }

    /// Decodes a LUD-06 payRequest response.
    public static func decodePayRequest(_ data: Data) throws -> PayRequest {
        let object = try decodeObject(data)

        guard object["tag"] as? String == "payRequest" else {
            throw Failure.notPayRequest
        }

        guard let callbackText = object["callback"] as? String else {
            throw Failure.invalidResponse
        }
        guard let callback = URL(string: callbackText),
              callback.scheme?.lowercased() == "https",
              let host = callback.host, !host.isEmpty else {
            throw Failure.insecureCallback
        }

        guard let minSendable = integer(object["minSendable"]),
              let maxSendable = integer(object["maxSendable"]),
              minSendable > 0, maxSendable > 0, minSendable <= maxSendable else {
            throw Failure.invalidResponse
        }

        var commentAllowed = 0
        if let raw = object["commentAllowed"] {
            guard let value = integer(raw), value >= 0, let count = Int(exactly: value) else {
                throw Failure.invalidResponse
            }
            commentAllowed = count
        }

        return PayRequest(
            callback: callback, minSendable: minSendable,
            maxSendable: maxSendable, commentAllowed: commentAllowed
        )
    }

    /// The callback URL with the amount and, if the service permits it, the comment.
    /// The comment is cut to `commentAllowed` characters. A `commentAllowed` of 0 gives no comment.
    public static func callbackURL(for request: PayRequest, amountMsat: Int64, comment: String) throws -> URL {
        guard amountMsat >= request.minSendable, amountMsat <= request.maxSendable else {
            throw Failure.amountOutOfRange
        }
        guard var components = URLComponents(url: request.callback, resolvingAgainstBaseURL: false) else {
            throw Failure.invalidResponse
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "amount", value: String(amountMsat)))
        if request.commentAllowed > 0 {
            items.append(URLQueryItem(name: "comment", value: String(comment.prefix(request.commentAllowed))))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw Failure.invalidResponse
        }
        return url
    }

    /// The invoice of a LUD-06 callback response.
    /// The BOLT11 amount of the invoice must be equal to the requested amount.
    public static func decodeInvoice(_ data: Data, amountMsat: Int64) throws -> String {
        let object = try decodeObject(data)
        guard let invoice = object["pr"] as? String else {
            throw Failure.invalidResponse
        }
        guard Bolt11.amountMsat(invoice) == amountMsat else {
            throw Failure.invoiceAmountMismatch
        }
        return invoice
    }

    /// Decodes a JSON object. A LUD-06 error response throws serviceError with its reason.
    private static func decodeObject(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let object = json as? [String: Any] else {
            throw Failure.invalidResponse
        }
        if object["status"] as? String == "ERROR" {
            throw Failure.serviceError(object["reason"] as? String ?? "")
        }
        return object
    }

    /// Reads a JSON number that is an integer. Gives nil for a JSON boolean and for all other shapes.
    ///
    /// `JSONSerialization` gives an `NSNumber` for a number and for a boolean.
    /// A JSON boolean has the type code `c`, and a JSON number never has it.
    private static func integer(_ raw: Any?) -> Int64? {
        guard let number = raw as? NSNumber,
              String(cString: number.objCType) != "c" else {
            return nil
        }
        let double = number.doubleValue
        guard double.isFinite, double == double.rounded(.towardZero),
              double >= -9_223_372_036_854_775_808.0, double < 9_223_372_036_854_775_808.0 else {
            return nil
        }
        let value = number.int64Value
        guard Double(value) == double else { return nil }
        return value
    }
}
