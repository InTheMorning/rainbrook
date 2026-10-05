#if os(iOS)
import AVFoundation
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Reads the Icecast stream title from a playing item, and parses it.
///
/// `AVPlayerItemMetadataOutput` calls the delegate methods of this reader on a private
/// serial queue, not on the main actor. This reader does the parsing in a task, and
/// hands only the parsed `IcyTrack` to `onTrack`. The caller of `onTrack` decides where
/// that value then goes.
final class IcyMetadataReader: NSObject, AVPlayerItemMetadataOutputPushDelegate, Sendable {
    private let onTrack: @Sendable (IcyTrack?) -> Void

    /// Creates a reader. The reader calls `onTrack` once for each parsed title.
    init(onTrack: @escaping @Sendable (IcyTrack?) -> Void) {
        self.onTrack = onTrack
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
        Task { [onTrack] in
            let candidates = groups.flatMap(\.items)
            let item = candidates.first { $0.identifier == .icyMetadataStreamTitle }
                ?? candidates.first { $0.commonKey == .commonKeyTitle }
            guard let item else {
                onTrack(nil)
                return
            }
            let text = (try? await item.load(.stringValue)) ?? nil
            onTrack(text.flatMap(IcyTitle.parse))
        }
    }
}
#endif
