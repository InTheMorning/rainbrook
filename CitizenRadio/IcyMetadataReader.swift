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

    /// Creates a reader. The reader calls `onText` once for each group that gives an ICY text (ADR 0025).
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
        // so the task can take them. The task reads the items only inside the task.
        // ADR 0025: a StreamTitle item gives the ICY text. Else the ID3 artist and title items
        // of an HLS stream give it. IcyTitle.text holds the rule.
        Task { [onText] in
            let candidates = groups.flatMap(\.items)
            let streamTitleItem = candidates.first { $0.identifier == .icyMetadataStreamTitle }
            let streamTitle: String?
            if let streamTitleItem {
                // An item with no string value is an empty ICY text.
                streamTitle = ((try? await streamTitleItem.load(.stringValue)) ?? nil) ?? ""
            } else {
                streamTitle = nil
            }
            let artistItem = candidates.first { $0.identifier == .id3MetadataLeadPerformer }
                ?? candidates.first { $0.commonKey == .commonKeyArtist }
            let titleItem = candidates.first { $0.identifier == .id3MetadataTitleDescription }
                ?? candidates.first { $0.commonKey == .commonKeyTitle }
            let artist = await Self.string(of: artistItem)
            let title = await Self.string(of: titleItem)
            guard let text = IcyTitle.text(streamTitle: streamTitle, artist: artist, title: title) else {
                return
            }
            onText(text)
        }
    }

    /// The string value of an item, or nil when there is no item or no string value.
    private static func string(of item: AVMetadataItem?) async -> String? {
        guard let item else { return nil }
        return (try? await item.load(.stringValue)) ?? nil
    }
}
#endif
