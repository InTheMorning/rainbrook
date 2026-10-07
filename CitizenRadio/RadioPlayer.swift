#if os(iOS)
import AVFoundation
import Combine
import MediaPlayer
import os
import UIKit
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@MainActor
final class RadioPlayer: ObservableObject {
    static let shared = RadioPlayer()
    /// Playback events for a diagnosis on the device, with `idevicesyslog`. No URL and no title.
    private static let log = Logger(subsystem: "org.citizenradio.CitizenRadio", category: "playback")

    struct PlaybackError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @Published private(set) var state: PlaybackState = .stopped {
        didSet { updateChime() }
    }
    /// The raw ICY text from the stream. Nil means no ICY text in this session.
    @Published private(set) var icyText: String?
    /// ADR 0017 §The fallback: true while the alternate stream plays. Stop and each new Play set it to false.
    @Published private(set) var usingAlternateStream = false
    /// ADR 0021 §The status: true during a drop while the network path is not satisfied.
    @Published private(set) var waitingForNetwork = false

    private let audioSession = AVAudioSession.sharedInstance()
    private var player: AVPlayer?
    /// The station and its primary stream for the same-station check at the start of `play()`.
    private var activeStationID: UUID?
    private var activeURL: URL?
    /// ADR 0017 §The fallback: the streams of the station, and the index of the stream that plays.
    private var streams: [URL] = []
    private var streamIndex = 0
    private var request = PlaybackRequest()
    /// Changes at each Play, Stop and interruption. `playAndWait()` waits on this value.
    private var playbackID = UUID()
    /// Changes at each new player item, also at a fallback. Each item callback examines this value.
    private var sessionID = UUID()
    private var itemObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var sessionSubscriptions = Set<AnyCancellable>()
    private var itemSubscriptions = Set<AnyCancellable>()
    private var connectionTimeout: Task<Void, Never>?
    /// The time that a connection or a stall can take before playback stops with an error.
    private static let connectionTimeoutSeconds = 20
    private var currentOutputIDs = Set<String>()
    private var interruptedOutputIDs = Set<String>()
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var chime: AVAudioPlayer?
    private var icyReader: IcyMetadataReader?
    // Audio session activation can block, so it never runs on the main thread.
    private let sessionQueue = DispatchQueue(label: "org.citizenradio.CitizenRadio.audio-session")
    private var sessionActive = false
    private var nowPlayingTitle = TrackLines.defaultTitle
    private var nowPlayingArtist = TrackLines.defaultNowPlayingArtist
    /// ADR 0019: the album for Now Playing, or nil when the track has no album.
    private var nowPlayingAlbum: String?
    private var nowPlayingImage: UIImage?
    /// ADR 0021: the last `isSatisfied` value of the network path. The start value is true.
    private var pathSatisfied = true
    /// ADR 0021: the subscription to the network path. It stays for the life of the player.
    private var pathTask: Task<Void, Never>?
    /// ADR 0021 §Two phases: true after the stream that plays gives its first `.playing`.
    /// A new Play, Stop and a fallback set it to false.
    private var hasPlayed = false
    /// ADR 0021 §The stall budget: the task of the drop that runs, or nil when no drop runs.
    private var dropTask: Task<Void, Never>?
    private var budget = StallBudget()
    /// ADR 0021 §The chime: the seconds since the drop started, or nil when no drop runs.
    private var dropSeconds: Int? {
        didSet { updateChime() }
    }
    /// ADR 0021 §The stall budget: true when the new item for the same stream
    /// waits for a satisfied network path.
    private var newItemWaitsForPath = false
    /// ADR 0021 §The stall budget: the `dropSeconds` value when the last new item of the drop started.
    /// A new item starts a minimum of `newItemIntervalSeconds` after the one before it.
    private var lastNewItemSecond: Int?
    private static let newItemIntervalSeconds = 5
    /// ADR 0021 §The stall budget: a stall that lasts this time with a satisfied path also gets a new item.
    /// AVPlayer can stop loading a live HLS item after a network change, with no item failure.
    private static let stalledItemSeconds = 4

    private init() {
        updateOutput()
        observeAudioSession()
        installRemoteCommands()
        observeNetworkPath()
    }

    func playFromControls() {
        do {
            try play()
        } catch {
            fail(error.localizedDescription)
        }
    }

    func playAndWait() async throws {
        try Task.checkCancellation()
        do {
            try play()
        } catch {
            fail(error.localizedDescription)
            throw error
        }
        // ADR 0017 §The fallback: a fallback changes sessionID, so wait on playbackID.
        let expectedID = playbackID
        while playbackID == expectedID {
            if state == .playing { return }
            if let message = state.errorMessage { throw PlaybackError(message: message) }
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                if playbackID == expectedID { stop() }
                throw error
            }
        }
        if let message = state.errorMessage { throw PlaybackError(message: message) }
        throw PlaybackError(message: "Playback stopped before the stream started.")
    }

    func stop() {
        request.stop()
        interruptedOutputIDs.removeAll()
        releasePlayer()
        usingAlternateStream = false
        state = .stopped
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        deactivateSession()
    }

    /// ADR 0020 §Stream quality: a saved quality change applies to the item that plays, with no restart.
    func setQuality(_ quality: StreamQuality) {
        player?.currentItem?.preferredPeakBitRate = quality.peakBitRate
    }

    /// Gives the seconds of loaded audio after the play position, or 0 without an item.
    func bufferedAheadSeconds() -> Double {
        guard let item = player?.currentItem else { return 0 }
        let ranges = item.loadedTimeRanges.map { value -> ClosedRange<Double> in
            let range = value.timeRangeValue
            let start = range.start.seconds
            return start...(start + range.duration.seconds)
        }
        return LoadedAudio.bufferedAhead(currentTime: item.currentTime().seconds, loadedRanges: ranges)
    }

    /// Stores the track for Now Playing. ADR 0008 §Player screen and Now Playing.
    /// ADR 0019: `album` is nil when the track has no album.
    ///
    /// Now Playing changes only while playback is active. `stop()` clears Now Playing,
    /// and a track change after that must not show it again.
    func setNowPlayingTrack(title: String, artist: String, album: String?, image: UIImage?) {
        nowPlayingTitle = title
        nowPlayingArtist = artist
        nowPlayingAlbum = album
        nowPlayingImage = image
        guard state.canStop else { return }
        updateNowPlaying()
    }

    private func play() throws {
        guard let station = StationStore().selected else {
            throw PlaybackError(message: "Open CitizenRadio and add a station first.")
        }
        // ADR 0017 §The station list: a tap on a different station starts it.
        if request.wantsPlayback, activeStationID == station.id, activeURL == station.stream {
            return
        }
        // A change from a playing station to a different station starts a new session
        // for the track info and the boosts. After an interruption, no station is active.
        if request.wantsPlayback, activeStationID != nil {
            stop()
        }

        releasePlayer()
        request.stop()
        request.play()
        activeStationID = station.id
        activeURL = station.stream
        streams = station.streams
        streamIndex = 0
        usingAlternateStream = false
        let url = station.stream
        sessionActive = false
        state = .connecting
        updateNowPlaying()
        startConnectionTimeout()
        let expectedID = sessionID
        let queue = sessionQueue
        Task { @MainActor [weak self] in
            do {
                try await Self.activateSession(on: queue)
            } catch {
                guard let self, self.sessionID == expectedID else { return }
                self.fail(error.localizedDescription)
                return
            }
            guard let self, self.sessionID == expectedID, self.request.wantsPlayback else { return }
            self.sessionActive = true
            self.updateChime()
            self.startPlayer(url: url, expectedID: expectedID)
        }
    }

    private nonisolated static func activateSession(on queue: DispatchQueue) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .default)
                    try session.setActive(true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startPlayer(url: URL, expectedID: UUID) {
        let item = AVPlayerItem(url: url)
        // ADR 0020 §Stream quality and §The HLS live offset: these three properties apply
        // to the primary stream and to the alternate stream.
        item.preferredPeakBitRate = StreamQualitySetting().quality.peakBitRate
        item.configuredTimeOffsetFromLive = CMTime(seconds: Double(HLSBufferSetting().buffer.seconds), preferredTimescale: 1)
        // ADR 0020 §The HLS live offset: the offset applies at the start only. With the preserve property on,
        // AVPlayer jumped back during and after a network gap, because the live edge it knew stopped moving.
        item.automaticallyPreservesTimeOffsetFromLive = false
        // ADR 0020 §The HLS live offset: AVPlayer loads this much audio ahead. Without it, iOS selects
        // a smaller amount, and the cushion does not fill.
        item.preferredForwardBufferDuration = Double(HLSBufferSetting().buffer.seconds)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        player = newPlayer

        let reader = IcyMetadataReader { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self, self.sessionID == expectedID else { return }
                self.icyText = text
            }
        }
        reader.attach(to: item)
        icyReader = reader

        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshPlayback(expectedID: expectedID)
            }
        }
        playbackObservation = newPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshPlayback(expectedID: expectedID)
            }
        }
        observeItem(item, expectedID: expectedID)
        observeItemLogs(item, expectedID: expectedID)
        updateOutput()
        updateNowPlaying()
        Self.log.notice("New item: stream \(self.streamIndex, privacy: .public), played \(self.hasPlayed, privacy: .public), drop \(self.dropSeconds ?? -1, privacy: .public) s")
        newPlayer.play()
    }

    /// Logs one event with the play position: the seconds behind the live edge and the buffered seconds.
    private func logPosition(_ event: String) {
        guard let item = player?.currentItem else {
            Self.log.notice("\(event, privacy: .public): no item")
            return
        }
        let now = item.currentTime().seconds
        let liveEdge = item.seekableTimeRanges.last.map { CMTimeRangeGetEnd($0.timeRangeValue).seconds }
        let behind = liveEdge.map { $0 - now } ?? -1
        let buffered = item.loadedTimeRanges.last.map { CMTimeRangeGetEnd($0.timeRangeValue).seconds - now } ?? -1
        let status = player?.timeControlStatus.rawValue ?? -1
        let reason = player?.reasonForWaitingToPlay?.rawValue ?? "none"
        Self.log.notice("\(event, privacy: .public): status \(status, privacy: .public), waiting \(reason, privacy: .public), behind live \(behind, format: .fixed(precision: 1), privacy: .public) s, buffered \(buffered, format: .fixed(precision: 1), privacy: .public) s, path \(self.pathSatisfied, privacy: .public)")
    }

    private func refreshPlayback(expectedID: UUID) {
        guard sessionID == expectedID, request.wantsPlayback, let player else { return }
        logPosition("Status change")
        if player.currentItem?.status == .failed {
            let error = player.currentItem?.error as NSError?
            Self.log.notice("Item failed: \(error?.domain ?? "none", privacy: .public) \(error?.code ?? 0, privacy: .public)")
            // ADR 0021 §The stall budget: in the played phase, an item failure is a drop.
            if hasPlayed {
                startDrop(newItem: true)
            } else {
                streamFailed("The stream could not play. Check the URL, network connection, and stream format.")
            }
            return
        }
        if player.timeControlStatus == .playing {
            hasPlayed = true
            endDrop()
            state = .playing
            connectionTimeout?.cancel()
            connectionTimeout = nil
        } else if hasPlayed {
            startDrop(newItem: false)
            return
        } else {
            state = .connecting
            startConnectionTimeout()
        }
        updateNowPlaying()
    }

    /// The 20-second limit of the start phase. ADR 0021 §Two phases: it does not run in the played phase.
    private func startConnectionTimeout() {
        guard connectionTimeout == nil, !hasPlayed else { return }
        let expectedID = sessionID
        let seconds = Self.connectionTimeoutSeconds
        connectionTimeout = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            } catch {
                return
            }
            guard let self, self.sessionID == expectedID,
                  self.request.wantsPlayback, !self.hasPlayed, self.state != .playing else { return }
            self.streamFailed("The stream did not respond within \(seconds) seconds. Check your connection, then tap Play.")
        }
    }

    private func observeItem(_ item: AVPlayerItem, expectedID: UUID) {
        for name in [AVPlayerItem.failedToPlayToEndTimeNotification, AVPlayerItem.didPlayToEndTimeNotification] {
            NotificationCenter.default.publisher(for: name, object: item)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    guard let self, self.sessionID == expectedID, self.request.wantsPlayback else { return }
                    let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
                    Self.log.notice("Item end: \(notification.name.rawValue, privacy: .public), \(error?.domain ?? "none", privacy: .public) \(error?.code ?? 0, privacy: .public)")
                    // ADR 0021 §The stall budget: in the played phase, an item failure or an end of the stream is a drop.
                    if self.hasPlayed {
                        self.startDrop(newItem: true)
                        return
                    }
                    self.streamFailed("The live stream ended. Tap Play to connect again.")
                }
                .store(in: &itemSubscriptions)
        }
        NotificationCenter.default.publisher(for: AVPlayerItem.playbackStalledNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.sessionID == expectedID, self.request.wantsPlayback else { return }
                self.logPosition("Stall")
                // ADR 0021 §The stall budget: in the played phase, a stall is a drop.
                if self.hasPlayed {
                    self.startDrop(newItem: false)
                    self.player?.play()
                    return
                }
                self.state = .connecting
                self.updateNowPlaying()
                self.startConnectionTimeout()
                self.player?.play()
            }
            .store(in: &itemSubscriptions)
    }

    /// Logs the access log, the error log and the time jumps of one item, for a diagnosis on the device.
    private func observeItemLogs(_ item: AVPlayerItem, expectedID: UUID) {
        NotificationCenter.default.publisher(for: AVPlayerItem.newAccessLogEntryNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.sessionID == expectedID, let event = item.accessLog()?.events.last else { return }
                Self.log.notice("Access log: indicated \(Int(event.indicatedBitrate), privacy: .public), observed \(Int(event.observedBitrate), privacy: .public), switch \(Int(event.switchBitrate), privacy: .public), stalls \(event.numberOfStalls, privacy: .public)")
            }
            .store(in: &itemSubscriptions)
        NotificationCenter.default.publisher(for: AVPlayerItem.newErrorLogEntryNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.sessionID == expectedID, let event = item.errorLog()?.events.last else { return }
                Self.log.notice("Error log: \(event.errorDomain, privacy: .public) \(event.errorStatusCode, privacy: .public)")
            }
            .store(in: &itemSubscriptions)
        NotificationCenter.default.publisher(for: AVPlayerItem.timeJumpedNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.sessionID == expectedID else { return }
                self.logPosition("Time jump")
            }
            .store(in: &itemSubscriptions)
    }

    private func observeAudioSession() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    self.stop()
                }
                self.updateOutput()
            }
            .store(in: &sessionSubscriptions)

        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &sessionSubscriptions)

        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.state.canStop {
                    self.fail("The audio service restarted. Tap Play to connect again.")
                }
                self.updateOutput()
            }
            .store(in: &sessionSubscriptions)
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            guard request.wantsPlayback else { return }
            interruptedOutputIDs = currentOutputIDs
            request.interruptionBegan()
            releasePlayer()
            state = .interrupted
            updateNowPlaying()
        case .ended:
            guard state == .interrupted else { return }
            let rawOptions = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            updateOutput()
            let sameOutput = !currentOutputIDs.isEmpty && currentOutputIDs == interruptedOutputIDs
            let resume = request.interruptionEnded(
                shouldResume: options.contains(.shouldResume),
                sameOutput: sameOutput
            )
            if resume {
                playFromControls()
            } else {
                stop()
            }
        @unknown default:
            stop()
        }
    }

    /// ADR 0017 §The fallback: the one path for a failure of the stream that plays.
    ///
    /// The player item failed, the connection time limit ended, or the stream ended.
    /// If the station has a next stream, this function starts it. Else it calls `fail`.
    /// The fallback keeps the active audio session and the playback request.
    private func streamFailed(_ message: String) {
        let nextIndex = streamIndex + 1
        // Before the audio session is active, the stream is not the cause of the failure.
        guard sessionActive, request.wantsPlayback, nextIndex < streams.count else {
            fail(message)
            return
        }
        streamIndex = nextIndex
        // ADR 0021 §Two phases: a fallback starts a new start phase.
        endDrop()
        hasPlayed = false
        // releaseItem() sets a new session identifier. Then the callbacks of the previous item do nothing.
        releaseItem()
        usingAlternateStream = true
        state = .connecting
        updateNowPlaying()
        startConnectionTimeout()
        startPlayer(url: streams[nextIndex], expectedID: sessionID)
    }

    /// Releases the player, the item and the station of the session.
    private func releasePlayer() {
        playbackID = UUID()
        // ADR 0021 §Two phases: Stop, a new Play and an interruption end the played phase.
        endDrop()
        hasPlayed = false
        releaseItem()
        activeStationID = nil
        activeURL = nil
        streams = []
        streamIndex = 0
    }

    /// Releases the player and the item only. It sets a new session identifier.
    private func releaseItem() {
        sessionID = UUID()
        connectionTimeout?.cancel()
        connectionTimeout = nil
        itemObservation?.invalidate()
        itemObservation = nil
        playbackObservation?.invalidate()
        playbackObservation = nil
        itemSubscriptions.removeAll()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        icyReader = nil
        icyText = nil
    }

    private func fail(_ message: String) {
        stop()
        state = .failed(message)
    }

    private func deactivateSession() {
        sessionActive = false
        sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func updateOutput() {
        currentOutputIDs = Set(audioSession.currentRoute.outputs.map(\.uid))
    }

    private func updateChime() {
        // AVAudioPlayer activates an inactive session on the calling thread, so wait for activation.
        // ADR 0021 §The chime: nil in the start phase. In the played phase with no drop, use 0.
        let seconds = hasPlayed ? (dropSeconds ?? 0) : nil
        guard sessionActive,
              ChimeSetting.shouldPlay(state: state, enabled: ChimeSetting().isEnabled, dropSeconds: seconds) else {
            chime?.stop()
            chime = nil
            return
        }
        guard chime == nil,
              let url = Bundle.main.url(forResource: "forcdchime", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.play()
        chime = player
    }

    // MARK: - ADR 0021: drops in the played phase

    /// Starts the subscription to the network path. It stays for the life of the player.
    private func observeNetworkPath() {
        let monitor = NetworkPathMonitor()
        pathTask = Task { @MainActor [weak self] in
            for await summary in monitor.summaries() {
                guard let self else { return }
                self.networkPathChanged(satisfied: summary.isSatisfied)
            }
        }
    }

    /// ADR 0021 §The stall budget: a satisfied path during a drop starts playback at once.
    private func networkPathChanged(satisfied: Bool) {
        pathSatisfied = satisfied
        logPosition("Path change")
        updateWaitingForNetwork()
        guard satisfied, dropTask != nil, request.wantsPlayback else { return }
        if newItemWaitsForPath {
            startNewItemIfDue()
        } else {
            player?.play()
        }
    }

    /// Starts a drop in the played phase, if no drop runs. The state is `.connecting`.
    ///
    /// newItem: true for an item failure or an end of the stream. Then this function releases
    /// the item and makes a new item for the same stream. The same budget continues.
    private func startDrop(newItem: Bool) {
        if dropTask == nil {
            Self.log.notice("Drop started: new item \(newItem, privacy: .public)")
        }
        state = .connecting
        if dropTask == nil {
            budget = StallBudget()
            dropSeconds = 0
            let expectedID = playbackID
            dropTask = Task { @MainActor [weak self] in
                while true {
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        return
                    }
                    guard let self, self.playbackID == expectedID, self.request.wantsPlayback else { return }
                    self.dropSeconds = (self.dropSeconds ?? 0) + 1
                    if self.budget.tick(pathSatisfied: self.pathSatisfied) {
                        self.endDrop()
                        self.streamFailed(
                            "The stream did not respond within \(StallBudget.limitSeconds) seconds. Check your connection, then tap Play."
                        )
                        return
                    }
                    // A stalled item gets a new item, and a new item that waited for its interval starts now.
                    self.replaceStalledItemIfDue()
                    self.startNewItemIfDue()
                }
            }
        }
        if newItem {
            // releaseItem() sets a new session identifier. Then the callbacks of the previous item do nothing.
            releaseItem()
            newItemWaitsForPath = true
            startNewItemIfDue()
        }
        updateWaitingForNetwork()
        updateNowPlaying()
    }

    /// ADR 0021 §The stall budget: a stall with a satisfied path gets a new item for the same stream.
    /// The first one comes after `stalledItemSeconds` of drop. While the stall continues, each next one
    /// comes `newItemIntervalSeconds` after the one before it.
    private func replaceStalledItemIfDue() {
        guard dropTask != nil, !newItemWaitsForPath, pathSatisfied, request.wantsPlayback else { return }
        let now = dropSeconds ?? 0
        if let lastNewItemSecond {
            guard now - lastNewItemSecond >= Self.newItemIntervalSeconds else { return }
        } else {
            guard now >= Self.stalledItemSeconds else { return }
        }
        logPosition("Stalled item replaced")
        // releaseItem() sets a new session identifier. Then the callbacks of the stalled item do nothing.
        releaseItem()
        newItemWaitsForPath = true
        startNewItemIfDue()
        updateNowPlaying()
    }

    /// Makes a new item for the stream that played, and starts it, when the path is satisfied
    /// and the interval since the last new item of the drop has ended.
    /// So a stream that fails at once does not get a new request each second.
    private func startNewItemIfDue() {
        guard newItemWaitsForPath, pathSatisfied, request.wantsPlayback,
              streams.indices.contains(streamIndex) else { return }
        let now = dropSeconds ?? 0
        if let lastNewItemSecond, now - lastNewItemSecond < Self.newItemIntervalSeconds {
            return
        }
        lastNewItemSecond = now
        newItemWaitsForPath = false
        startPlayer(url: streams[streamIndex], expectedID: sessionID)
    }

    /// Ends the drop that runs: cancels its task, and clears `dropSeconds` and the budget.
    private func endDrop() {
        dropTask?.cancel()
        dropTask = nil
        budget = StallBudget()
        newItemWaitsForPath = false
        lastNewItemSecond = nil
        if dropSeconds != nil {
            dropSeconds = nil
        }
        updateWaitingForNetwork()
    }

    private func updateWaitingForNetwork() {
        let waiting = dropTask != nil && !pathSatisfied
        if waitingForNetwork != waiting {
            waitingForNetwork = waiting
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyArtist: nowPlayingArtist,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
        if let nowPlayingImage {
            info[MPMediaItemPropertyArtwork] = Self.makeArtwork(nowPlayingImage)
        }
        // ADR 0019: set the album title when there is one. A new dictionary with no
        // key removes it when there is none, because this call replaces the full dictionary.
        if let nowPlayingAlbum {
            info[MPMediaItemPropertyAlbumTitle] = nowPlayingAlbum
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Makes the Now Playing artwork.
    ///
    /// MediaPlayer calls the request handler on a thread that is not the main thread.
    /// A closure that is made in a `@MainActor` context is main-actor isolated in Swift 6,
    /// and that call then stops the app with a runtime check. So this function is
    /// `nonisolated`, and the handler gives only the image that it captured.
    private nonisolated static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false

        let playTarget = center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.playFromControls() }
            return .success
        }
        remoteTargets.append((center.playCommand, playTarget))
        for command in [center.pauseCommand, center.stopCommand] {
            let target = command.addTarget { [weak self] _ in
                Task { @MainActor [weak self] in self?.stop() }
                return .success
            }
            remoteTargets.append((command, target))
        }
        let toggleTarget = center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.state.canStop {
                    self.stop()
                } else {
                    self.playFromControls()
                }
            }
            return .success
        }
        remoteTargets.append((center.togglePlayPauseCommand, toggleTarget))
    }
}
#endif
