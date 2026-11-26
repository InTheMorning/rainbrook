import Foundation
import XCTest

final class AudioSessionThreadTests: XCTestCase {
    /// Each `setActive(` call in the app sources must run inside a dispatch queue block.
    func testAudioSessionActivationRunsOffTheMainThread() throws {
        let appDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Rainbrook")
        let files = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        var calls = 0
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("setActive(") {
                calls += 1
                let context = lines[max(0, index - 4)..<index].joined(separator: "\n")
                XCTAssertTrue(
                    context.contains(".async {"),
                    """
                    ADR 0006: \(file.lastPathComponent):\(index + 1) calls setActive outside a dispatch queue block. \
                    Audio session activation can block the main thread. \
                    Call it on RadioPlayer.sessionQueue, as activateSession(on:) and deactivateSession() do.
                    """
                )
            }
        }
        XCTAssertGreaterThan(calls, 0, "The test found no setActive calls. Examine the source path.")
    }
}
