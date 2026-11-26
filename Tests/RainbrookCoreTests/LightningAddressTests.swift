import Foundation
import XCTest
@testable import RainbrookCore

final class LightningAddressTests: XCTestCase {
    private let invoice2500u = "lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq"

    private func payRequest(_ json: String) throws -> LightningAddress.PayRequest {
        try LightningAddress.decodePayRequest(Data(json.utf8))
    }

    private func assertFailure(
        _ expected: LightningAddress.Failure, file: StaticString = #filePath, line: UInt = #line,
        _ body: () throws -> Any
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(error as? LightningAddress.Failure, expected, file: file, line: line)
        }
    }

    // MARK: wellKnownURL

    func testWellKnownURL() {
        XCTAssertEqual(
            LightningAddress.wellKnownURL(name: "artist", host: "merchant.io").absoluteString,
            "https://merchant.io/.well-known/lnurlp/artist"
        )
    }

    // MARK: comment

    func testCommentIsTheMessage() {
        let sender = BoostSender(message: "Great set!", senderName: "Maik", appName: "MyApp")

        XCTAssertEqual(LightningAddress.comment(for: sender), "Great set!")
    }

    func testCommentWithoutMessageNamesTheApp() {
        let sender = BoostSender(message: nil, senderName: "Maik", appName: "MyApp")

        XCTAssertEqual(LightningAddress.comment(for: sender), "Boost from MyApp")
    }

    // MARK: decodePayRequest

    func testDecodesPayRequest() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/lnurlp/cb?id=7",
          "minSendable": 1000, "maxSendable": 100000000, "commentAllowed": 10, "metadata": "[]" }
        """)

        XCTAssertEqual(request.callback.absoluteString, "https://merchant.io/lnurlp/cb?id=7")
        XCTAssertEqual(request.minSendable, 1000)
        XCTAssertEqual(request.maxSendable, 100_000_000)
        XCTAssertEqual(request.commentAllowed, 10)
    }

    func testMissingCommentAllowedIsZero() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/cb", "minSendable": 1000, "maxSendable": 1000 }
        """)

        XCTAssertEqual(request.commentAllowed, 0)
    }

    func testPayRequestErrorStatusThrowsServiceError() {
        assertFailure(.serviceError("unknown user")) {
            try self.payRequest(#"{ "status": "ERROR", "reason": "unknown user" }"#)
        }
    }

    func testWrongTagThrowsNotPayRequest() {
        assertFailure(.notPayRequest) {
            try self.payRequest("""
            { "tag": "withdrawRequest", "callback": "https://merchant.io/cb", "minSendable": 1000, "maxSendable": 1000 }
            """)
        }
        assertFailure(.notPayRequest) {
            try self.payRequest(#"{ "callback": "https://merchant.io/cb", "minSendable": 1000, "maxSendable": 1000 }"#)
        }
    }

    func testHTTPCallbackThrowsInsecureCallback() {
        assertFailure(.insecureCallback) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "http://merchant.io/cb", "minSendable": 1000, "maxSendable": 1000 }
            """)
        }
    }

    func testCallbackWithoutHostThrowsInsecureCallback() {
        assertFailure(.insecureCallback) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "https:cb", "minSendable": 1000, "maxSendable": 1000 }
            """)
        }
    }

    func testMinMoreThanMaxThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "https://merchant.io/cb", "minSendable": 2000, "maxSendable": 1000 }
            """)
        }
    }

    func testZeroMinSendableThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "https://merchant.io/cb", "minSendable": 0, "maxSendable": 1000 }
            """)
        }
    }

    func testBooleanSendableThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "https://merchant.io/cb", "minSendable": true, "maxSendable": 1000 }
            """)
        }
    }

    func testFractionalSendableThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "https://merchant.io/cb", "minSendable": 1000, "maxSendable": 1500.5 }
            """)
        }
    }

    func testStringSendableThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "https://merchant.io/cb", "minSendable": "1000", "maxSendable": 1000 }
            """)
        }
    }

    func testBooleanCommentAllowedThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try self.payRequest("""
            { "tag": "payRequest", "callback": "https://merchant.io/cb",
              "minSendable": 1000, "maxSendable": 1000, "commentAllowed": true }
            """)
        }
    }

    func testMissingCallbackThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try self.payRequest(#"{ "tag": "payRequest", "minSendable": 1000, "maxSendable": 1000 }"#)
        }
    }

    func testNonObjectThrowsInvalidResponse() {
        assertFailure(.invalidResponse) { try self.payRequest("[]") }
        assertFailure(.invalidResponse) { try self.payRequest("not json") }
    }

    // MARK: callbackURL

    func testCallbackURLKeepsQueryAndAddsAmount() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/cb?id=7", "minSendable": 1000, "maxSendable": 5000 }
        """)

        let url = try LightningAddress.callbackURL(for: request, amountMsat: 2000, comment: "Boost from Rainbrook")

        XCTAssertEqual(url.absoluteString, "https://merchant.io/cb?id=7&amount=2000")
    }

    func testCallbackURLAddsCommentCutToCommentAllowed() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/cb",
          "minSendable": 1000, "maxSendable": 5000, "commentAllowed": 10 }
        """)

        let url = try LightningAddress.callbackURL(for: request, amountMsat: 1000, comment: "Boost from Rainbrook")

        XCTAssertEqual(url.absoluteString, "https://merchant.io/cb?amount=1000&comment=Boost%20from")
    }

    func testCallbackURLAddsFullCommentWhenItFits() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/cb",
          "minSendable": 1000, "maxSendable": 5000, "commentAllowed": 255 }
        """)

        let url = try LightningAddress.callbackURL(for: request, amountMsat: 5000, comment: "Boost from Rainbrook")

        XCTAssertEqual(url.absoluteString, "https://merchant.io/cb?amount=5000&comment=Boost%20from%20Rainbrook")
    }

    func testCallbackURLCutsA300CharacterCommentTo100() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/cb",
          "minSendable": 1000, "maxSendable": 5000, "commentAllowed": 100 }
        """)
        let comment = String(repeating: "a", count: 100) + String(repeating: "b", count: 200)

        let url = try LightningAddress.callbackURL(for: request, amountMsat: 1000, comment: comment)

        XCTAssertEqual(
            url.absoluteString,
            "https://merchant.io/cb?amount=1000&comment="
                + "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                + "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        )
    }

    func testCallbackURLWithCommentAllowedZeroHasNoComment() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/cb",
          "minSendable": 1000, "maxSendable": 5000, "commentAllowed": 0 }
        """)

        let url = try LightningAddress.callbackURL(for: request, amountMsat: 1000, comment: "Great set!")

        XCTAssertEqual(url.absoluteString, "https://merchant.io/cb?amount=1000")
    }

    func testCallbackURLAmountOutOfRangeThrows() throws {
        let request = try payRequest("""
        { "tag": "payRequest", "callback": "https://merchant.io/cb", "minSendable": 1000, "maxSendable": 5000 }
        """)

        assertFailure(.amountOutOfRange) { try LightningAddress.callbackURL(for: request, amountMsat: 999, comment: "x") }
        assertFailure(.amountOutOfRange) { try LightningAddress.callbackURL(for: request, amountMsat: 5001, comment: "x") }
    }

    // MARK: decodeInvoice

    func testDecodeInvoiceGivesInvoiceWithEqualAmount() throws {
        let json = #"{ "pr": "lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq", "routes": [] }"#

        XCTAssertEqual(try LightningAddress.decodeInvoice(Data(json.utf8), amountMsat: 250_000_000), invoice2500u)
    }

    func testDecodeInvoiceAmountMismatchThrows() {
        let json = #"{ "pr": "lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq" }"#

        assertFailure(.invoiceAmountMismatch) {
            try LightningAddress.decodeInvoice(Data(json.utf8), amountMsat: 100_000)
        }
    }

    func testDecodeInvoiceWithoutAmountThrowsMismatch() {
        let json = #"{ "pr": "lnbc1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq" }"#

        assertFailure(.invoiceAmountMismatch) {
            try LightningAddress.decodeInvoice(Data(json.utf8), amountMsat: 100_000)
        }
    }

    func testDecodeInvoiceErrorStatusThrowsServiceError() {
        assertFailure(.serviceError("amount too low")) {
            try LightningAddress.decodeInvoice(
                Data(#"{ "status": "ERROR", "reason": "amount too low" }"#.utf8), amountMsat: 1000
            )
        }
    }

    func testDecodeInvoiceWithoutStringPrThrowsInvalidResponse() {
        assertFailure(.invalidResponse) {
            try LightningAddress.decodeInvoice(Data(#"{ "routes": [] }"#.utf8), amountMsat: 1000)
        }
        assertFailure(.invalidResponse) {
            try LightningAddress.decodeInvoice(Data(#"{ "pr": 42 }"#.utf8), amountMsat: 1000)
        }
    }

    // MARK: keysendURL and decodeKeysend (ADR 0023)

    /// The Alby keysend answer of 2026-10-07.
    private let albyKeysend = """
    {"status":"OK","tag":"keysend",
     "pubkey":"02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5cc01",
     "customData":[{"customKey":"696969","customValue":"1"}]}
    """

    func testKeysendURL() {
        XCTAssertEqual(
            LightningAddress.keysendURL(name: "caringquiescence333577", host: "getalby.com").absoluteString,
            "https://getalby.com/.well-known/keysend/caringquiescence333577"
        )
    }

    func testDecodeKeysendOfTheAlbyAnswer() throws {
        let target = try LightningAddress.decodeKeysend(Data(albyKeysend.utf8))

        XCTAssertEqual(target.pubkey, "02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5cc01")
        XCTAssertEqual(target.records, [TLVRecord(type: 696_969, value: "31")])
    }

    func testDecodeKeysendGivesALowercasePubkey() throws {
        let target = try LightningAddress.decodeKeysend(Data("""
        {"tag":"keysend","pubkey":"02BABB6A65CCD4C11CAAC12EDBAA77659826C12A9B7FBA6BDC00DA6DD8B5B5CC01"}
        """.utf8))

        XCTAssertEqual(target.pubkey, "02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5cc01")
        XCTAssertEqual(target.records, [])
    }

    func testDecodeKeysendWithAWrongTagThrows() {
        assertFailure(.notKeysend) {
            try LightningAddress.decodeKeysend(Data("""
            {"tag":"payRequest","pubkey":"02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5cc01"}
            """.utf8))
        }
    }

    func testDecodeKeysendWithAShortPubkeyThrows() {
        assertFailure(.invalidResponse) {
            try LightningAddress.decodeKeysend(Data("""
            {"tag":"keysend","pubkey":"02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5cc"}
            """.utf8))
        }
    }

    func testDecodeKeysendWithANonHexPubkeyThrows() {
        assertFailure(.invalidResponse) {
            try LightningAddress.decodeKeysend(Data("""
            {"tag":"keysend","pubkey":"02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5czz"}
            """.utf8))
        }
    }

    func testDecodeKeysendWithStatusErrorThrows() {
        assertFailure(.serviceError("no user")) {
            try LightningAddress.decodeKeysend(Data(#"{"status":"ERROR","reason":"no user"}"#.utf8))
        }
    }

    func testDecodeKeysendOfAnHTMLBodyThrows() {
        assertFailure(.invalidResponse) {
            try LightningAddress.decodeKeysend(Data("<!DOCTYPE html><html><body>Not found</body></html>".utf8))
        }
    }

    func testDecodeKeysendSkipsACustomKeyThatIsNotADecimalNumber() throws {
        let target = try LightningAddress.decodeKeysend(Data("""
        {"tag":"keysend","pubkey":"02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5cc01",
         "customData":[{"customKey":"abc","customValue":"x"},{"customKey":"-5","customValue":"y"},
                       {"customKey":"696969","customValue":"abc"}]}
        """.utf8))

        XCTAssertEqual(target.records, [TLVRecord(type: 696_969, value: "616263")])
    }

    // MARK: payerdata (ADR 0023)

    func testDecodePayRequestReadsPayerDataName() throws {
        let withName = try payRequest("""
        { "tag": "payRequest", "callback": "https://getalby.com/cb", "minSendable": 1000, "maxSendable": 5000,
          "payerData": {"name":{"mandatory":false},"email":{"mandatory":false},"pubkey":{"mandatory":false}} }
        """)
        let withoutName = try payRequest("""
        { "tag": "payRequest", "callback": "https://getalby.com/cb", "minSendable": 1000, "maxSendable": 5000,
          "payerData": {"email":{"mandatory":false}} }
        """)
        let without = try payRequest("""
        { "tag": "payRequest", "callback": "https://getalby.com/cb", "minSendable": 1000, "maxSendable": 5000 }
        """)

        XCTAssertTrue(withName.acceptsPayerName)
        XCTAssertFalse(withoutName.acceptsPayerName)
        XCTAssertFalse(without.acceptsPayerName)
    }

    private func payerDataValue(_ url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "payerdata" }?.value
    }

    func testCallbackURLWithPayerNameAndAcceptsPayerNameHasPayerData() throws {
        let request = LightningAddress.PayRequest(
            callback: URL(string: "https://getalby.com/cb")!, minSendable: 1000, maxSendable: 5000,
            commentAllowed: 0, acceptsPayerName: true
        )

        let url = try LightningAddress.callbackURL(for: request, amountMsat: 1000, comment: "x", payerName: "Maik")

        XCTAssertEqual(payerDataValue(url), #"{"name":"Maik"}"#)
        XCTAssertEqual(url.absoluteString, "https://getalby.com/cb?amount=1000&payerdata=%7B%22name%22:%22Maik%22%7D")
    }

    func testCallbackURLWithoutAcceptsPayerNameOrWithoutANameHasNoPayerData() throws {
        let accepts = LightningAddress.PayRequest(
            callback: URL(string: "https://getalby.com/cb")!, minSendable: 1000, maxSendable: 5000,
            commentAllowed: 0, acceptsPayerName: true
        )
        let declines = LightningAddress.PayRequest(
            callback: URL(string: "https://getalby.com/cb")!, minSendable: 1000, maxSendable: 5000,
            commentAllowed: 0, acceptsPayerName: false
        )

        let noName = try LightningAddress.callbackURL(for: accepts, amountMsat: 1000, comment: "x", payerName: nil)
        let emptyName = try LightningAddress.callbackURL(for: accepts, amountMsat: 1000, comment: "x", payerName: "")
        let notAccepted = try LightningAddress.callbackURL(for: declines, amountMsat: 1000, comment: "x", payerName: "Maik")

        XCTAssertEqual(noName.absoluteString, "https://getalby.com/cb?amount=1000")
        XCTAssertEqual(emptyName.absoluteString, "https://getalby.com/cb?amount=1000")
        XCTAssertEqual(notAccepted.absoluteString, "https://getalby.com/cb?amount=1000")
    }
}
