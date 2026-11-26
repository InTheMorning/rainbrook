#if os(iOS)
import AVFoundation
import os
#if SWIFT_PACKAGE
import RainbrookCore
#endif

/// Reads the Icecast stream title text from a playing item.
///
/// `AVPlayerItemMetadataOutput` calls the delegate methods of this reader on a private
/// serial queue, not on the main actor. This reader reads the title text in a task, and
/// hands only that text to `onText`. The caller of `onText` decides where the text then
/// goes.
final class IcyMetadataReader: NSObject, AVPlayerItemMetadataOutputPushDelegate, Sendable {
    private let onText: @Sendable (IcyText) -> Void
    /// The task of the newest callback (ADR 0030).
    private let lastTask = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    /// Creates a reader. The reader calls `onText` once for each group that gives an ICY text (ADR 0025, ADR 0027),
    /// in the sequence of the groups. The text has the segment frame of the group, when the group has one (ADR 0030).
    init(onText: @escaping @Sendable (IcyText) -> Void) {
        self.onText = onText
    }

    /// Adds an `AVPlayerItemMetadataOutput` to the item, with this reader as its delegate
    /// on a private serial queue.
    func attach(to item: AVPlayerItem) {
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        let queue = DispatchQueue(label: "org.rainbrook.Rainbrook.icy-metadata")
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
        // ADR 0030: each task waits for the task of the callback before it, so the texts arrive in the
        // sequence of the groups. This method runs on one serial queue, so no other call runs between
        // the read and the write of `lastTask`.
        let previous = lastTask.withLock { $0 }
        let task = Task { [onText] in
            await previous?.value
            for group in groups {
                if let text = await Self.icyText(of: group.items) {
                    onText(text)
                }
            }
        }
        lastTask.withLock { $0 = task }
    }

    /// The ICY text of one metadata group, or nil when the group gives no ICY text.
    /// ADR 0025: a StreamTitle item gives the ICY text. Else the ID3 artist and title items
    /// of an HLS stream give it. IcyTitle.icyText holds the rule.
    /// ADR 0030: the first TXXX item whose value is a musicindex.hls/2 frame gives the segment frame.
    private static func icyText(of candidates: [AVMetadataItem]) async -> IcyText? {
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
        let artist = await string(of: artistItem)
        let title = await string(of: titleItem)
        guard let text = IcyTitle.icyText(streamTitle: streamTitle, artist: artist, title: title) else {
            return nil
        }
        var segmentFrame: SegmentFrame?
        for item in candidates where item.identifier == .id3MetadataUserText {
            if let value = await string(of: item), let frame = SegmentFrame.parse(value) {
                segmentFrame = frame
                break
            }
        }
        return text.with(segmentFrame: segmentFrame)
    }

    /// The string value of an item, or nil when there is no item or no string value.
    private static func string(of item: AVMetadataItem?) async -> String? {
        guard let item else { return nil }
        return (try? await item.load(.stringValue)) ?? nil
    }
}
#endif
