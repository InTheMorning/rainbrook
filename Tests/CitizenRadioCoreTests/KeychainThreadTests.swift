import Foundation
import XCTest

final class KeychainThreadTests: XCTestCase {
    /// Each `SecItem` function call in the app sources must run in a dispatch queue block.
    func testKeychainCallsRunOffTheMainThread() throws {
        let appDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../CitizenRadio")
        let files = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        var calls = 0
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated()
            where line.range(of: #"SecItem(CopyMatching|Update|Add|Delete)\("#, options: .regularExpression) != nil {
                calls += 1
                let context = lines[max(0, index - 4)..<index].joined(separator: "\n")
                XCTAssertTrue(
                    context.contains(".async {"),
                    """
                    ADR 0007 §Storage: \(file.lastPathComponent):\(index + 1) calls SecItem outside a dispatch queue block. \
                    Keychain calls can block the main thread. \
                    Call it on the KeychainSecretStore queue.
                    """
                )
            }
        }
        XCTAssertGreaterThan(calls, 0, "The test found no SecItem calls. Examine the source path.")
    }
}
