#if os(iOS)
import Combine
import Foundation
import UIKit
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Connects the relay display, the ICY title and the artwork to the player screen and Now Playing.
///
/// ADR 0008 owns the data rules. ADR 0011 owns the rules for a session with ICY.
/// This model runs on the main actor and does no blocking work. `EventStreamClient`,
/// `ArtworkLoader` and the URLSession types do the network, stream and image work.
@MainActor
final class TrackInfoModel: ObservableObject {
    @Published private(set) var lines = TrackLines.select(relay: nil, icy: nil)
    @Published private(set) var image: UIImage?
    @Published private(set) var relayStatus: EventStreamStatus?

    /// One streamed display state that waits for the buffered audio.
    private struct PendingApply {
        let id: UInt64
        let track: TrackDisplay?
        let task: Task<Void, Never>
    }

    private let player: RadioPlayer
    private let loader: ArtworkLoader
    private let monitor: NetworkPathMonitor
    private let opener: any LineStreamOpening
    private let fetcher: any SnapshotFetching

    private var event: RelayEvent?
    private var playbackActive = false
    private var relayTrack: TrackDisplay?
    /// ADR 0011: the display states and the ICY text of this playback session.
    private var sync = IcySync()
    private var client: EventStreamClient?
    private var updatesTask: Task<Void, Never>?
    private var pathTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var pending: [PendingApply] = []
    private var nextApplyID: UInt64 = 0
    private var subscriptions = Set<AnyCancellable>()

    init(
        player: RadioPlayer,
        loader: ArtworkLoader = ArtworkLoader(),
        monitor: NetworkPathMonitor = NetworkPathMonitor(),
        opener: any LineStreamOpening = URLSessionLineStreamOpener(),
        fetcher: any SnapshotFetching = URLSessionSnapshotFetcher()
    ) {
        self.player = player
        self.loader = loader
        self.monitor = monitor
        self.opener = opener
        self.fetcher = fetcher
        self.event = RelayEventStore().event

        // RadioPlayer is on the main actor, so these values arrive on the main thread.
        // A @Published publisher sends the new value before the property changes, so use the value.
        player.$state
            .sink { [weak self] state in
                self?.playbackChanged(state)
            }
            .store(in: &subscriptions)
        player.$icyText
            .sink { [weak self] text in
                self?.icyTextChanged(text)
            }
            .store(in: &subscriptions)
    }

    deinit {
        updatesTask?.cancel()
        pathTask?.cancel()
        artworkTask?.cancel()
        for apply in pending {
            apply.task.cancel()
        }
        if let client {
            Task { await client.stop() }
        }
    }

    /// Reads the Track info setting again. If the event changed, the relay client starts again.
    func reloadSettings() {
        let newEvent = RelayEventStore().event
        guard newEvent != event else { return }
        event = newEvent
        stopRelay()
        relayStatus = nil
        sync.clearStates()
        setRelayTrack(nil)
        if playbackActive {
            startRelay()
        }
    }

    // MARK: - Playback and relay client

    private func playbackChanged(_ state: PlaybackState) {
        playbackActive = state == .connecting || state == .playing
        if playbackActive {
            startRelay()
        } else {
            stopRelay()
            // ADR 0011 §The session: Stop starts a new session with no ICY.
            sync = IcySync()
            setRelayTrack(nil)
        }
    }

    /// Starts one client for the configured event. It does nothing when a client exists.
    ///
    /// A client that stopped on a relay error stays until playback stops or the event changes.
    /// So a change between `connecting` and `playing` does not send the same request again.
    private func startRelay() {
        guard client == nil, let event else { return }
        let client = EventStreamClient(
            snapshotURL: event.displayURL,
            streamURL: event.displayEventsURL,
            eventName: "display",
            opener: opener,
            fetcher: fetcher
        )
        self.client = client

        updatesTask = Task { [weak self] in
            let updates = await client.start()
            for await update in updates {
                guard let self, self.client === client else { return }
                self.handle(update)
            }
        }

        let monitor = self.monitor
        pathTask = Task {
            var previous: NetworkPathSummary?
            for await summary in monitor.summaries() {
                if NetworkPathSummary.shouldReconnect(from: previous, to: summary) {
                    await client.networkChanged()
                }
                previous = summary
            }
        }
    }

    private func stopRelay() {
        updatesTask?.cancel()
        updatesTask = nil
        pathTask?.cancel()
        pathTask = nil
        cancelPendingApplies()
        if let client {
            Task { await client.stop() }
        }
        client = nil
        // Keep a relay error for Settings. Other statuses are not true after a stop.
        if case .stopped = relayStatus {} else {
            relayStatus = nil
        }
    }

    private func handle(_ update: EventStreamUpdate) {
        switch update {
        case .snapshot(let data):
            let track: TrackDisplay?
            do {
                track = try TrackDisplay.decode(data)
            } catch {
                return
            }
            sync.receive(track)
            if sync.hasIcy {
                // ADR 0011: the ICY text releases the state. No timed apply.
                updateLines()
            } else {
                cancelPendingApplies()
                setRelayTrack(track)
            }
        case .event(let streamed):
            let track: TrackDisplay?
            do {
                track = try TrackDisplay.decode(Data(streamed.data.utf8))
            } catch {
                return
            }
            sync.receive(track)
            if sync.hasIcy {
                // ADR 0011: the ICY text releases the state. No timed apply.
                updateLines()
            } else {
                let delay = DisplayTiming.delay(bufferedAhead: player.bufferedAheadSeconds())
                schedule(track, after: delay)
            }
        case .status(let status):
            relayStatus = status
            switch status {
            case .stopped(.notFound), .stopped(.notReserved):
                pathTask?.cancel()
                pathTask = nil
                cancelPendingApplies()
                sync.clearStates()
                setRelayTrack(nil)
            case .waiting:
                // ADR 0011 §The session: with ICY, backoff keeps the list and the selection.
                guard !sync.hasIcy else { break }
                // ADR 0008 §Fallback: without ICY, backoff gives no relay track.
                // The next snapshot gives the relay track again.
                cancelPendingApplies()
                setRelayTrack(nil)
            default:
                break
            }
        }
    }

    // MARK: - Delayed applies

    /// Applies a streamed display state after the delay. Each apply is a task that sleeps.
    private func schedule(_ track: TrackDisplay?, after delay: Duration) {
        nextApplyID &+= 1
        let id = nextApplyID
        let task = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            self?.firePendingApply(id)
        }
        pending.append(PendingApply(id: id, track: track, task: task))
    }

    /// Applies one pending state. The states that arrived before it are older, so they are canceled.
    private func firePendingApply(_ id: UInt64) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let track = pending[index].track
        for older in pending[..<index] {
            older.task.cancel()
        }
        pending.removeSubrange(...index)
        setRelayTrack(track)
    }

    private func cancelPendingApplies() {
        for apply in pending {
            apply.task.cancel()
        }
        pending.removeAll()
    }

    // MARK: - Lines, artwork and Now Playing

    private func setRelayTrack(_ track: TrackDisplay?) {
        relayTrack = track
        updateLines()
    }

    /// Gives an ICY text to the sync. A nil text changes nothing, because Stop makes a new sync.
    private func icyTextChanged(_ text: String?) {
        guard let text else { return }
        let firstIcyText = !sync.hasIcy
        sync.receiveIcyText(text)
        if firstIcyText {
            // ADR 0011 §The session: the first ICY text cancels the pending timed applies.
            cancelPendingApplies()
        }
        updateLines()
    }

    private func updateLines() {
        let newLines = sync.hasIcy ? sync.lines : TrackLines.select(relay: relayTrack, icy: nil)
        guard newLines != lines else { return }
        let artworkChanged = newLines.artwork != lines.artwork
        lines = newLines
        if artworkChanged {
            loadArtwork()
        }
        updateNowPlaying()
    }

    /// Loads the artwork of `lines`. A result for an older artwork is ignored.
    private func loadArtwork() {
        artworkTask?.cancel()
        artworkTask = nil
        guard let artwork = lines.artwork, let event else {
            image = nil
            return
        }
        let loader = self.loader
        artworkTask = Task { [weak self] in
            let loaded = await loader.image(for: artwork, event: event)
            guard let self, !Task.isCancelled, self.lines.artwork == artwork else { return }
            self.image = loaded
            self.updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        player.setNowPlayingTrack(title: lines.title, artist: lines.nowPlayingArtist, image: image)
    }
}
#endif
