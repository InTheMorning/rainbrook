#if os(iOS)
import Foundation
#if SWIFT_PACKAGE
import RainbrookCore
#endif

/// Opens a server-sent event stream with `URLSession`.
/// ADR 0008 §Transport: the app target supplies the byte stream for `EventStreamClient`.
struct URLSessionLineStreamOpener: LineStreamOpening {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func open(_ url: URL, lastEventID: String?) async throws -> LineStreamResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let lastEventID {
            request.setValue(lastEventID, forHTTPHeaderField: "Last-Event-ID")
        }

        let (bytes, response) = try await session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            bytes.task.cancel()
            let (lines, continuation) = AsyncThrowingStream<String, Error>.makeStream()
            continuation.finish()
            return LineStreamResponse(status: status, lines: lines)
        }
        return LineStreamResponse(status: status, lines: Self.lineStream(from: bytes))
    }

    /// Splits the byte stream into lines, and gives the lines through a stream.
    ///
    /// The `lines` property on `AsyncBytes` drops an empty line. An empty line ends
    /// each server-sent event. So this method reads the raw bytes itself.
    ///
    /// It ends a line at each line feed. It removes one trailing carriage return.
    /// It decodes the line as UTF-8. It gives a last group of bytes with no final
    /// line feed as a last line.
    ///
    /// The byte read runs in a task. The stream's `onTermination` cancels that task
    /// and the data task. So a canceled consumer stops the network read.
    /// When the read ends or fails, this method finishes the stream. It gives the
    /// error to the stream if the read failed.
    private static func lineStream(from bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let readTask = Task {
            var line: [UInt8] = []
            do {
                for try await byte in bytes {
                    if byte == 10 {
                        continuation.yield(Self.decodedLine(from: line))
                        line.removeAll(keepingCapacity: true)
                    } else {
                        line.append(byte)
                    }
                }
                if !line.isEmpty {
                    continuation.yield(Self.decodedLine(from: line))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in
            readTask.cancel()
            bytes.task.cancel()
        }
        return stream
    }

    /// Removes one trailing carriage return, then decodes the bytes as UTF-8.
    private static func decodedLine(from bytes: [UInt8]) -> String {
        var bytes = bytes
        if bytes.last == 13 {
            bytes.removeLast()
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Fetches one JSON snapshot with `URLSession`.
struct URLSessionSnapshotFetcher: SnapshotFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(_ url: URL) async throws -> (status: Int, body: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (body, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, body)
    }
}
#endif
