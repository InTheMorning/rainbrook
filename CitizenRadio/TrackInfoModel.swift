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
/// ADR 0012 owns the rules for the live value client and the inputs of `boost`.
@MainActor
final class TrackInfoModel: ObservableObject {
    @Published private(set) var lines = TrackLines.select(relay: nil, icy: nil)
    @Published private(set) var image: UIImage?
    @Published private(set) var relayStatus: EventStreamStatus?
    /// Decides and pays the boosts of the session.
    let boost: BoostModel

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
    /// The value is yes when the display client stopped on a 404 or a 409. The client stays until playback stops or the event changes.
    private var relayStopped = false
    private var updatesTask: Task<Void, Never>?
    /// ADR 0012: the live value client. It runs only while the display client runs and Auto-boost is on.
    private var valueClient: EventStreamClient?
    private var valueUpdatesTask: Task<Void, Never>?
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
        self.boost = BoostModel()
        self.player = player
        self.loader = loader
        self.monitor = monitor
        self.opener = opener
        self.fetcher = fetcher
        // ADR 0017 §The station: the Track info of the selected station gives the event.
        self.event = StationStore().selected?.event

        // The settings sheet shows the boost result. Send a change of this model when the result changes.
        boost.$status
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscriptions)
        // The player screen reads the manual boost target. The settings sheet reads the history.
        boost.$manualTarget
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscriptions)
        boost.$history
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscriptions)
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
        player.$usingAlternateStream
            .sink { [weak self] usingAlternate in
                guard usingAlternate else { return }
                self?.alternateStreamStarted()
            }
            .store(in: &subscriptions)
    }

    deinit {
        updatesTask?.cancel()
        valueUpdatesTask?.cancel()
        pathTask?.cancel()
        artworkTask?.cancel()
        for apply in pending {
            apply.task.cancel()
        }
        if let client {
            Task { await client.stop() }
        }
        if let valueClient {
            Task { await valueClient.stop() }
        }
    }

    /// Reads the Track info and Auto-boost settings again. If the event changed, the relay client starts again.
    /// If only the Auto-boost setting changed, the live value client starts or stops.
    func reloadSettings() {
        let newEvent = StationStore().selected?.event
        guard newEvent != event else {
            updateValueClient()
            return
        }
        event = newEvent
        stopRelay()
        relayStatus = nil
        sync.clearStates()
        setRelayTrack(nil)
        // ADR 0012 §The trigger: a change of the Track info event ends the session.
        boost.sessionEnded()
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
            // ADR 0012 §The trigger: Stop and a playback error end the session.
            boost.sessionEnded()
        }
    }

    /// ADR 0017 §The fallback: the alternate stream starts a new ICY session and a new trigger session.
    /// The list of display states, the relay client, the pairing and the paid blocks stay.
    private func alternateStreamStarted() {
        sync.resetIcy()
        setRelayTrack(nil)
        boost.streamChanged()
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
            // ADR 0018 §The replay on connect: the replay count is IcySync.capacity.
            // GET /display has no seq on 2026-10-06, so this replay does not occur at this time.
            replayCount: IcySync.capacity,
            opener: opener,
            fetcher: fetcher
        )
        self.client = client
        relayStopped = false

        updatesTask = Task { [weak self] in
            let updates = await client.start()
            for await update in updates {
                guard let self, self.client === client else { return }
                self.handle(update)
            }
        }

        let monitor = self.monitor
        pathTask = Task { [weak self] in
            var previous: NetworkPathSummary?
            for await summary in monitor.summaries() {
                if NetworkPathSummary.shouldReconnect(from: previous, to: summary) {
                    await client.networkChanged()
                    if let valueClient = self?.valueClient {
                        await valueClient.networkChanged()
                    }
                }
                previous = summary
            }
        }

        updateValueClient()
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
        relayStopped = false
        stopValueClient()
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
        case .replay(let streamed):
            // ADR 0018 §The replay on connect: a replayed state goes only into the ICY sync list.
            // It does not go to the timed apply, and it does not set the relay track.
            let track: TrackDisplay?
            do {
                track = try TrackDisplay.decode(Data(streamed.data.utf8))
            } catch {
                return
            }
            sync.receive(track)
            if sync.hasIcy {
                // ADR 0011: the ICY text releases the state.
                updateLines()
            }
        case .status(let status):
            relayStatus = status
            switch status {
            case .stopped(.notFound), .stopped(.notReserved):
                pathTask?.cancel()
                pathTask = nil
                relayStopped = true
                stopValueClient()
                cancelPendingApplies()
                sync.clearStates()
                setRelayTrack(nil)
                // ADR 0012: no relay tracks are available, so the boost session ends.
                boost.sessionEnded()
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

    // MARK: - Live value client

    /// Starts or stops the live value client. It runs while the display client runs and Auto-boost is on.
    private func updateValueClient() {
        let shouldRun = client != nil && !relayStopped && BoostSettings().isEnabled
        if shouldRun {
            startValueClient()
        } else {
            stopValueClient()
        }
    }

    /// Starts one live value client for the configured event. It does nothing when a client exists.
    private func startValueClient() {
        guard valueClient == nil, let event else { return }
        let valueClient = EventStreamClient(
            // ADR 0018 §The value snapshot: GET /metadata is on the instant timeline, as GET /display is.
            snapshotURL: event.metadataURL,
            streamURL: event.valueEventsURL,
            eventName: "remoteValue",
            // ADR 0018 §The replay on connect: the replay count is BoostPairing.capacity.
            replayCount: BoostPairing.capacity,
            continueCodes: ["metadata_not_found"],
            opener: opener,
            fetcher: fetcher
        )
        self.valueClient = valueClient

        valueUpdatesTask = Task { [weak self] in
            let updates = await valueClient.start()
            for await update in updates {
                guard let self, self.valueClient === valueClient else { return }
                self.handleValue(update)
            }
        }
    }

    private func stopValueClient() {
        valueUpdatesTask?.cancel()
        valueUpdatesTask = nil
        if let valueClient {
            Task { await valueClient.stop() }
        }
        valueClient = nil
    }

    /// Gives each live value payload to the boost model. An empty or invalid payload is ignored.
    /// ADR 0018: a replayed payload goes into the pairing, as each other payload does.
    private func handleValue(_ update: EventStreamUpdate) {
        let decoded: LiveValuePayload?
        switch update {
        case .snapshot(let snapshot):
            decoded = try? LiveValuePayload.decodeMetadataSnapshot(snapshot)
        case .event(let streamed), .replay(let streamed):
            decoded = try? LiveValuePayload.decode(Data(streamed.data.utf8))
        case .status:
            return
        }
        guard let payload = decoded else { return }
        boost.payload(payload)
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
        // ADR 0016 §The switch back: give the relay track that the sync selects for this text.
        boost.icyText(text, track: sync.relayTrack)
        if firstIcyText {
            // ADR 0011 §The session: the first ICY text cancels the pending timed applies.
            cancelPendingApplies()
        }
        updateLines()
    }

    private func updateLines() {
        // ADR 0012 §The trigger: give each change of the ICY sync selection to the boost model.
        boost.selectedTrack(sync.relayTrack)
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
        // ADR 0015 §Display: Now Playing gets the first frame of an animated image.
        // ADR 0019: Now Playing gets the album of the lines, or nil when there is no album.
        player.setNowPlayingTrack(
            title: lines.title,
            artist: lines.nowPlayingArtist,
            album: lines.album,
            image: image?.images?.first ?? image
        )
    }
}
#endif
