#if os(iOS)
import AVFoundation
import Combine
import MediaPlayer
import os
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@MainActor
final class RadioPlayer: ObservableObject {
    static let shared = RadioPlayer()

    struct PlaybackError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @Published private(set) var state: PlaybackState = .stopped {
        didSet { updateChime() }
    }

    private let audioSession = AVAudioSession.sharedInstance()
    private var player: AVPlayer?
    private var activeURL: URL?
    private var request = PlaybackRequest()
    private var sessionID = UUID()
    private var itemObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?
    private var bufferTarget = 0
    private var waitingForBuffer = false
    private var bufferWaitExpired = false
    private var bufferWait: Task<Void, Never>?
    private let bufferLog = Logger(subsystem: "org.citizenradio.CitizenRadio", category: "buffer")
    private var sessionSubscriptions = Set<AnyCancellable>()
    private var itemSubscriptions = Set<AnyCancellable>()
    private var connectionTimeout: Task<Void, Never>?
    private var currentOutputIDs = Set<String>()
    private var interruptedOutputIDs = Set<String>()
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var chime: AVAudioPlayer?

    private init() {
        updateOutput()
        observeAudioSession()
        installRemoteCommands()
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
        let expectedID = sessionID
        while sessionID == expectedID {
            if state == .playing { return }
            if let message = state.errorMessage { throw PlaybackError(message: message) }
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                if sessionID == expectedID { stop() }
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
        state = .stopped
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        deactivateSession()
    }

    private func play() throws {
        let address = try StreamStore().address()
        if request.wantsPlayback, activeURL == address.url, player != nil {
            return
        }

        releasePlayer()
        request.stop()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)

        request.play()
        activeURL = address.url
        state = .connecting
        bufferTarget = BufferSetting().seconds
        waitingForBuffer = bufferTarget > 0
        let item = AVPlayerItem(url: address.url)
        if bufferTarget > 0 {
            item.preferredForwardBufferDuration = Double(bufferTarget + 10)
        }
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        player = newPlayer
        let expectedID = sessionID

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
        bufferObservation = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.startWhenBuffered(expectedID: expectedID)
            }
        }
        observeItem(item, expectedID: expectedID)
        updateOutput()
        updateNowPlaying()
        startConnectionTimeout()
        if waitingForBuffer {
            startBufferWait(expectedID: expectedID)
        } else {
            newPlayer.play()
        }
    }

    private func startBufferWait(expectedID: UUID) {
        bufferWait?.cancel()
        bufferWaitExpired = false
        let seconds = BufferSetting.maxWaitSeconds(target: bufferTarget)
        bufferWait = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            } catch {
                return
            }
            guard let self, self.sessionID == expectedID, self.waitingForBuffer else { return }
            self.bufferLog.notice("Buffer wait expired after \(seconds, privacy: .public) s")
            self.bufferWaitExpired = true
            self.startWhenBuffered(expectedID: expectedID)
        }
    }

    private func startWhenBuffered(expectedID: UUID) {
        guard sessionID == expectedID, request.wantsPlayback, waitingForBuffer,
              let player, let item = player.currentItem else { return }
        guard item.status == .readyToPlay else {
            bufferLog.notice("Buffer check: item status \(item.status.rawValue, privacy: .public)")
            return
        }
        let ranges = item.loadedTimeRanges.map { value -> ClosedRange<Double> in
            let range = value.timeRangeValue
            let start = range.start.seconds
            return start...(start + range.duration.seconds)
        }
        let now = item.currentTime().seconds
        let ahead = BufferSetting.bufferedAhead(currentTime: now, loadedRanges: ranges)
        bufferLog.notice("Buffer check: time \(now, privacy: .public), ranges \(ranges.description, privacy: .public), ahead \(ahead, privacy: .public), target \(self.bufferTarget, privacy: .public)")
        guard BufferSetting.shouldStart(bufferedAhead: ahead, target: bufferTarget, waitExpired: bufferWaitExpired) else { return }
        waitingForBuffer = false
        bufferWait?.cancel()
        bufferWait = nil
        player.play()
    }

    private func refreshPlayback(expectedID: UUID) {
        guard sessionID == expectedID, request.wantsPlayback, let player else { return }
        if player.currentItem?.status == .failed {
            fail("The stream could not play. Check the URL, network connection, and stream format.")
            return
        }
        startWhenBuffered(expectedID: expectedID)
        if player.timeControlStatus == .playing {
            state = .playing
            connectionTimeout?.cancel()
            connectionTimeout = nil
        } else {
            state = .connecting
            startConnectionTimeout()
        }
        updateNowPlaying()
    }

    private func startConnectionTimeout() {
        guard connectionTimeout == nil else { return }
        let expectedID = sessionID
        let seconds = BufferSetting.timeoutSeconds(target: bufferTarget)
        connectionTimeout = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            } catch {
                return
            }
            guard let self, self.sessionID == expectedID,
                  self.request.wantsPlayback, self.state != .playing else { return }
            self.fail("The stream did not respond within \(seconds) seconds. Check your connection, then tap Play.")
        }
    }

    private func observeItem(_ item: AVPlayerItem, expectedID: UUID) {
        for name in [AVPlayerItem.failedToPlayToEndTimeNotification, AVPlayerItem.didPlayToEndTimeNotification] {
            NotificationCenter.default.publisher(for: name, object: item)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self, self.sessionID == expectedID, self.request.wantsPlayback else { return }
                    self.fail("The live stream ended. Tap Play to connect again.")
                }
                .store(in: &itemSubscriptions)
        }
        NotificationCenter.default.publisher(for: AVPlayerItem.playbackStalledNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.sessionID == expectedID, self.request.wantsPlayback else { return }
                self.state = .connecting
                self.updateNowPlaying()
                self.startConnectionTimeout()
                if self.bufferTarget > 0 {
                    self.waitingForBuffer = true
                    self.player?.pause()
                    self.startBufferWait(expectedID: expectedID)
                } else {
                    self.player?.play()
                }
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

    private func releasePlayer() {
        sessionID = UUID()
        connectionTimeout?.cancel()
        connectionTimeout = nil
        itemObservation?.invalidate()
        itemObservation = nil
        playbackObservation?.invalidate()
        playbackObservation = nil
        bufferObservation?.invalidate()
        bufferObservation = nil
        waitingForBuffer = false
        bufferWait?.cancel()
        bufferWait = nil
        itemSubscriptions.removeAll()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        activeURL = nil
    }

    private func fail(_ message: String) {
        stop()
        state = .failed(message)
    }

    private func deactivateSession() {
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func updateOutput() {
        currentOutputIDs = Set(audioSession.currentRoute.outputs.map(\.uid))
    }

    private func updateChime() {
        guard ChimeSetting.shouldPlay(state: state, enabled: ChimeSetting().isEnabled) else {
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

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "CitizenRadio",
            MPMediaItemPropertyArtist: "Live radio",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
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
