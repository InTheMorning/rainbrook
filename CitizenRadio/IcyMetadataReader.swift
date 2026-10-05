#if os(iOS)
import AVFoundation
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Reads the Icecast stream title text from a playing item.
///
/// `AVPlayerItemMetadataOutput` calls the delegate methods of this reader on a private
/// serial queue, not on the main actor. This reader reads the title text in a task, and
/// hands only that text to `onText`. The caller of `onText` decides where the text then
/// goes.
final class IcyMetadataReader: NSObject, AVPlayerItemMetadataOutputPushDelegate, Sendable {
    private let onText: @Sendable (String) -> Void

    /// Creates a reader. The reader calls `onText` once for each group with a StreamTitle item.
    init(onText: @escaping @Sendable (String) -> Void) {
        self.onText = onText
    }

    /// Adds an `AVPlayerItemMetadataOutput` to the item, with this reader as its delegate
    /// on a private serial queue.
    func attach(to item: AVPlayerItem) {
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        let queue = DispatchQueue(label: "org.citizenradio.CitizenRadio.icy-metadata")
        output.setDelegate(self, queue: queue)
        item.add(output)
    }

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: sending [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        // AVMetadataItem is not Sendable. AVFoundation sends the groups to this method,
        // so the task can take them. The task reads the title only inside the task.
        Task { [onText] in
            let candidates = groups.flatMap(\.items)
            let item = candidates.first { $0.identifier == .icyMetadataStreamTitle }
                ?? candidates.first { $0.commonKey == .commonKeyTitle }
            guard let item else {
                return
            }
            let text = (try? await item.load(.stringValue)) ?? nil
            onText(text ?? "")
        }
    }
}
#endif
