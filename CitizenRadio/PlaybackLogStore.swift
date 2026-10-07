#if os(iOS)
import Foundation
import os
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Keeps the playback log in a file. ADR 0022 §The playback log owns these rules.
///
/// The file is `CitizenRadio/playback-log.json` in the Application Support folder.
/// This actor reads and writes the file off the main actor (ADR 0006).
/// It writes the file a maximum of one time each 5 seconds, and in `flush()`.
actor PlaybackLogStore {
    static let shared = PlaybackLogStore(fileURL: PlaybackLogStore.defaultFileURL())

    /// The minimum time between two scheduled writes.
    private static let writeInterval: Duration = .seconds(5)

    private let fileURL: URL
    private var log = PlaybackLog()
    private var loaded = false
    /// Yes when the log has entries that are not in the file.
    private var unsaved = false
    private var writeTask: Task<Void, Never>?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The log file: `CitizenRadio/playback-log.json` in the Application Support folder.
    static func defaultFileURL() -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return folder
            .appendingPathComponent("CitizenRadio", isDirectory: true)
            .appendingPathComponent("playback-log.json", isDirectory: false)
    }

    /// Reads the file one time. A missing file or a bad file gives an empty log.
    /// Entries that were added before the read stay after the entries of the file.
    func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? PlaybackLog.decode(data) else { return }
        log = PlaybackLog(entries: stored.entries + log.entries)
    }

    /// Adds an entry with the current date, and schedules a write.
    func add(_ text: String) {
        load()
        log.add(PlaybackLog.Entry(date: Date(), text: text))
        unsaved = true
        scheduleWrite()
    }

    /// The entries, oldest first.
    func entries() -> [PlaybackLog.Entry] {
        load()
        return log.entries
    }

    /// Removes all entries, and writes the empty log immediately.
    func clear() {
        load()
        log.clear()
        writeTask?.cancel()
        writeTask = nil
        write()
    }

    /// Writes the unsaved entries immediately. The app calls it when it goes to the background.
    func flush() {
        writeTask?.cancel()
        writeTask = nil
        guard unsaved else { return }
        write()
    }

    /// Starts one write after the write interval, if no write is scheduled.
    /// So the file gets a maximum of one scheduled write each 5 seconds.
    private func scheduleWrite() {
        guard writeTask == nil else { return }
        writeTask = Task {
            do {
                try await Task.sleep(for: Self.writeInterval)
            } catch {
                return
            }
            self.scheduledWriteFired()
        }
    }

    private func scheduledWriteFired() {
        writeTask = nil
        guard unsaved else { return }
        write()
    }

    /// Writes the log to the file, as one atomic write.
    /// Creates the folder of the file when the folder is missing. Ignores a write error.
    private func write() {
        unsaved = false
        guard let data = try? log.encoded() else { return }
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Records the playback events. ADR 0022 §The playback log.
///
/// Each text goes to the `playback` log category and to `PlaybackLogStore`.
/// The caller does not wait for the store. One task gives the texts to the store in sequence.
/// A text must not contain wallet data, a key, a boost message or an invoice.
@MainActor
enum PlaybackDiagnostics {
    private static let log = Logger(subsystem: "org.citizenradio.CitizenRadio", category: "playback")

    /// The texts for the store. One detached task reads them in sequence.
    private static let continuation: AsyncStream<String>.Continuation = {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        Task.detached {
            for await text in stream {
                await PlaybackLogStore.shared.add(text)
            }
        }
        return continuation
    }()

    /// Writes the text to the `playback` log category, and sends it to the store with no wait.
    static func record(_ text: String) {
        log.notice("\(text, privacy: .public)")
        continuation.yield(text)
    }
}
#endif
