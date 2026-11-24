#if os(iOS)
import Foundation
import os
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Decides and pays the auto-boosts and the manual boosts of one playback session. ADR 0013 owns the rules.
///
/// `TrackInfoModel` gives the ICY texts, the relay tracks and the live value payloads to this model.
/// This model runs on the main actor and does no blocking work. The Keychain read occurs in
/// `WalletStore`. The NWC payments and the LNURL requests occur in `BoostPayer` and `NWCClient`.
/// The history file read and write occur in the history store actor.
@MainActor
final class BoostModel: ObservableObject {
    /// The result of the last boost, for the Wallet section.
    @Published private(set) var status: String?
    /// The relay track that a manual boost can pay now, or nil.
    /// It is the current track when the pairing gives a payable payload for it (ADR 0013 §Manual boost).
    @Published private(set) var manualTarget: TrackDisplay?
    /// The boost history, newest first (ADR 0013 §The history).
    @Published private(set) var history: [BoostHistoryEntry] = []
    /// The ids of the history entries with a retry that runs (ADR 0016 §The retry).
    @Published private(set) var retryingEntries: Set<UUID> = []

    private static let log = Logger(subsystem: "org.citizenradio.CitizenRadio", category: "boost")

    /// ADR 0016 §The retry: the first automatic retry occurs 60 seconds after the boost.
    /// The second automatic retry occurs 600 seconds after the first retry.
    private static let automaticRetryDelays: [Duration] = [.seconds(60), .seconds(600)]

    private let walletStore: WalletStore
    private let connector: any RelayConnecting
    private let fetcher: any SnapshotFetching
    private let historyStore: any BoostHistoryStoring

    private var trigger = BoostTrigger()
    private var pairing = BoostPairing()
    /// ADR 0012 §The limits: the blocks of this session that the app paid or started to pay.
    private var paidBlocks = Set<String>()
    /// The amounts of the boosts that are still paying. The limit check counts them,
    /// so two boosts at the same time cannot go over the daily limit (ADR 0012 §The limits).
    private var reservedSats = 0
    /// The relay track that ICY sync selected last, also nil.
    private var currentTrack: TrackDisplay?
    /// ADR 0028: true when the value block of `currentTrack` ended.
    private var currentValueEnded = false

    init(
        walletStore: WalletStore = WalletStore(secrets: KeychainSecretStore()),
        connector: any RelayConnecting = URLSessionRelayConnector(),
        fetcher: any SnapshotFetching = URLSessionSnapshotFetcher(),
        history: any BoostHistoryStoring = BoostHistoryFileStore(fileURL: BoostModel.historyFileURL())
    ) {
        self.walletStore = walletStore
        self.connector = connector
        self.fetcher = fetcher
        self.historyStore = history

        // The store is an actor, so the file read occurs off the main actor.
        Task { [weak self] in
            let loaded = await history.load()
            guard let self else { return }
            // A boost can end before the file loads. Keep its entries first, then the older entries
            // of the file, with no duplicate.
            let known = Set(self.history.map(\.id))
            let merged = self.history + loaded.entries.filter { !known.contains($0.id) }
            self.history = BoostHistory(entries: merged).entries
        }
    }

    /// The history file: `CitizenRadio/boost-history.json` in the Application Support folder.
    nonisolated static func historyFileURL() -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return folder
            .appendingPathComponent("CitizenRadio", isDirectory: true)
            .appendingPathComponent("boost-history.json", isDirectory: false)
    }

    // MARK: - Inputs

    /// Gives an ICY text and its relay track to the trigger. A completed track starts a boost.
    /// ADR 0016 §The minimum play time: the time is the phone monotonic clock.
    /// So the trigger can give the play time of the candidate that the text completes.
    func icyText(_ text: String, track: TrackDisplay?) {
        let time = ProcessInfo.processInfo.systemUptime
        guard let completed = trigger.receiveIcyText(text, track: track, at: time) else { return }
        boost(completed)
    }

    /// Gives the relay track that ICY sync selected to the trigger.
    /// Also keeps the track, also nil, as the current track for a manual boost.
    /// ADR 0024 §The chapter change: a new chapter state can complete a candidate. That starts a boost.
    /// `valueEnded` is true when the value block of the track ended (ADR 0028). Then no manual target exists.
    /// The trigger gets the track with no change, so an auto-boost of the song that ended stays.
    func selectedTrack(_ track: TrackDisplay?, valueEnded: Bool = false) {
        let time = ProcessInfo.processInfo.systemUptime
        let completed = trigger.selectedTrack(track, at: time)
        currentTrack = track
        currentValueEnded = valueEnded
        updateManualTarget()
        if let completed {
            boost(completed)
        }
    }

    /// Keeps a live value payload for the pairing.
    func payload(_ payload: LiveValuePayload) {
        pairing.receive(payload)
        updateManualTarget()
    }

    /// ADR 0017 §The fallback: a change to the alternate stream ends the trigger session only.
    /// The trigger drops its candidate. The pairing, the paid blocks and the history stay.
    func streamChanged() {
        trigger.endSession()
    }

    /// Ends the session. The candidate, the payloads and the paid blocks are cleared.
    func sessionEnded() {
        trigger.endSession()
        pairing.clear()
        paidBlocks.removeAll()
        updateManualTarget()
    }

    /// Sets `manualTarget` to the current track when the pairing gives a payable payload for it.
    /// The value changes only when it is different, so the views do not update without a change.
    private func updateManualTarget() {
        var target: TrackDisplay?
        if let currentTrack, !currentValueEnded, pairing.payload(for: currentTrack) != nil {
            target = currentTrack
        }
        if target != manualTarget {
            manualTarget = target
        }
    }

    // MARK: - Boost

    private func boost(_ completed: BoostTrigger.Completed) {
        let settings = BoostSettings()
        let amountSats = settings.amountSats
        let day = SpendingLimit.dayKey(for: Date())
        let decision = BoostPlan.decide(
            enabled: settings.isEnabled,
            amountSats: amountSats,
            track: completed.track,
            pairing: pairing,
            paidBlocks: paidBlocks,
            limit: SpendingLimitStore().limit.recording(reservedSats, on: day),
            day: day,
            playedSeconds: completed.playedSeconds,
            minimumPlaySeconds: settings.minimumPlaySeconds
        )

        switch decision {
        case .skip(let reason):
            // ADR 0016 §The minimum play time: a tooShort skip adds no block to paidBlocks.
            // So a later full play of the same block can still boost.
            Self.log.notice("Boost skipped: \(Self.reasonName(reason), privacy: .public)")
            if let text = BoostStatusText.text(for: reason) {
                status = text
            }
        case .pay(let payload, let parts):
            // Add the block before the payment starts, so a second completed track cannot pay it again.
            paidBlocks.insert(payload.blockGuid)
            reservedSats += amountSats
            Self.log.notice("Boost started: \(amountSats, privacy: .public) sats, \(parts.count, privacy: .public) parts")
            // The task keeps the model until the payment and the history write are complete.
            Task {
                await self.payAutoBoost(parts: parts, payload: payload, amountSats: amountSats, track: completed.track)
            }
        }
    }

    /// Pays one auto-boost, then sets the status and adds the history entry.
    /// Two boosts can run at the same time. Each boost has its own payer.
    private func payAutoBoost(parts: [BoostPart], payload: LiveValuePayload, amountSats: Int, track: TrackDisplay?) async {
        let sender = BoostSender(settings: BoostSettings())
        let context = Self.context(action: .auto)
        guard let result = await pay(
            parts: parts, payload: payload, amountSats: amountSats, sender: sender, context: context
        ) else {
            status = BoostStatusText.noWallet
            return
        }
        status = BoostStatusText.text(for: result)
        if let track {
            await addHistoryEntry(kind: .auto, track: track, amountSats: amountSats, message: sender.message, result: result)
        }
    }

    // MARK: - Manual boost

    /// The parts that a manual boost of the amount pays for the track, or an empty list.
    /// The boost sheet shows them before Send (ADR 0013 §Manual boost).
    func manualParts(track: TrackDisplay?, amountSats: Int) -> [BoostPart] {
        guard case .pay(_, let parts) = BoostPlan.decideManual(amountSats: amountSats, track: track, pairing: pairing) else {
            return []
        }
        return parts
    }

    /// The result of one manual boost for the boost sheet.
    struct ManualBoostOutcome {
        let text: String
        /// The history entry of the boost, or nil when the app made no entry.
        let entryID: UUID?
    }

    /// Sends one manual boost for the given track, and gives the result text for the boost sheet.
    ///
    /// The boost sheet gives the track of the moment that it opened. Usually this track is `manualTarget`.
    /// ADR 0013 §The limits: the daily limit does not stop a manual boost, but its sats count.
    /// A skipped boost gives no history entry.
    func sendManualBoost(track: TrackDisplay?, amountSats: Int, message: String) async -> ManualBoostOutcome {
        let decision = BoostPlan.decideManual(amountSats: amountSats, track: track, pairing: pairing)
        switch decision {
        case .skip(let reason):
            Self.log.notice("Manual boost skipped: \(Self.reasonName(reason), privacy: .public)")
            return ManualBoostOutcome(text: BoostStatusText.text(for: reason) ?? "No boost. No V4V track plays.", entryID: nil)
        case .pay(let payload, let parts):
            let settingsSender = BoostSender(settings: BoostSettings())
            let sender = BoostSender(
                message: String(message.prefix(BoostSettings.maxMessageLength)),
                senderName: settingsSender.senderName,
                appName: settingsSender.appName
            )
            // An auto-boost at the same time counts this amount in its limit check.
            reservedSats += amountSats
            Self.log.notice("Manual boost started: \(amountSats, privacy: .public) sats, \(parts.count, privacy: .public) parts")
            let context = Self.context(action: .boost)
            guard let result = await pay(
                parts: parts, payload: payload, amountSats: amountSats, sender: sender, context: context
            ) else {
                status = BoostStatusText.noWallet
                return ManualBoostOutcome(text: BoostStatusText.noWallet, entryID: nil)
            }
            let text = BoostStatusText.text(for: result)
            status = text
            var entryID: UUID?
            if let track {
                entryID = await addHistoryEntry(kind: .manual, track: track, amountSats: amountSats, message: sender.message, result: result)
            }
            return ManualBoostOutcome(text: text, entryID: entryID)
        }
    }

    // MARK: - Payment and history

    /// The record data of one boost: the action, a new UUID and the name of the selected station.
    /// ADR 0023 §The boost record. Each split of the boost gets this value.
    private static func context(action: BoostAction) -> BoostContext {
        BoostContext(action: action, uuid: UUID(), stationName: StationStore().selected?.name)
    }

    /// Pays the parts of one boost. The auto-boost and the manual boost use this path.
    ///
    /// The caller adds `amountSats` to `reservedSats` before this call. This method removes it on each path.
    /// Gives nil when no wallet is connected. Then no payment starts.
    private func pay(
        parts: [BoostPart], payload: LiveValuePayload, amountSats: Int, sender: BoostSender, context: BoostContext
    ) async -> BoostResult? {
        defer { reservedSats -= amountSats }
        let connection: NWCConnection?
        do {
            connection = try await walletStore.connection()
        } catch {
            connection = nil
        }
        guard let connection else {
            Self.log.notice("Boost not paid: no wallet")
            return nil
        }
        let client = NWCClient(connection: connection, connector: connector, timeout: .seconds(30))
        let payer = BoostPayer(wallet: client, fetcher: fetcher)
        let result = await payer.pay(
            parts: parts, payload: payload, amountSats: amountSats, sender: sender, context: context
        )

        // ADR 0013 §The limits: a part with an unknown result can be paid, so it counts.
        let spent = result.paidSats + result.unknownSats
        if spent > 0 {
            SpendingLimitStore().record(spent, on: SpendingLimit.dayKey(for: Date()))
        }
        Self.log.notice(
            "Boost done: \(result.paidParts, privacy: .public) of \(result.totalParts, privacy: .public) parts paid, \(result.unknownParts, privacy: .public) unknown, \(result.paidSats, privacy: .public) sats paid"
        )
        // ADR 0023: the log gives only the number of lightning address parts on each path.
        let addressParts = result.parts.filter { $0.kind == .lightningAddress }
        let keysendCount = addressParts.filter { $0.path == .keysend }.count
        let invoiceCount = addressParts.filter { $0.path == .invoice }.count
        Self.log.notice(
            "Boost lightning address paths: \(keysendCount, privacy: .public) keysend, \(invoiceCount, privacy: .public) invoice"
        )
        return result
    }

    /// Adds one entry to the history list, then to the history store.
    /// The store is an actor, so the file write occurs off the main actor.
    /// Gives the id of the new entry.
    @discardableResult
    private func addHistoryEntry(
        kind: BoostHistoryEntry.Kind, track: TrackDisplay, amountSats: Int, message: String?, result: BoostResult
    ) async -> UUID {
        let entry = BoostHistoryEntry(
            date: Date(),
            kind: kind,
            title: track.title,
            artist: track.artist.isEmpty ? nil : track.artist,
            amountSats: amountSats,
            message: message,
            parts: result.parts
        )
        // The list on the main actor is the source for the screen. Two boosts that end at the same
        // time are added in the sequence that they end, so a newer entry is never lost from the list.
        var updated = BoostHistory(entries: history)
        updated.add(entry)
        history = updated.entries
        // The store actor writes the file off the main actor.
        _ = await historyStore.add(entry)
        if entry.hasRetryableParts {
            startAutomaticRetry(entryID: entry.id)
        }
        return entry.id
    }

    // MARK: - Retry

    /// Sends the retryable parts of one history entry again. This is the manual retry (ADR 0016 §The retry).
    /// It does nothing when the entry has no retryable part or when a retry of the entry runs.
    func retry(entryID: UUID) async {
        _ = await retryEntry(id: entryID, automaticAttempt: nil)
    }

    /// Starts the automatic retries of one entry (ADR 0016 §The retry).
    ///
    /// The task waits 60 seconds and sends the retryable parts again. If a part stays retryable,
    /// it waits 600 seconds more and sends them again. Then it stops.
    /// The end of a session does not cancel the task. The task stops when the app ends.
    /// `Task.sleep` does not block the main actor.
    private func startAutomaticRetry(entryID: UUID) {
        Task { [weak self] in
            for (index, delay) in Self.automaticRetryDelays.enumerated() {
                try? await Task.sleep(for: delay)
                guard let self else { return }
                let continues = await self.retryEntry(id: entryID, automaticAttempt: index + 1)
                guard continues else { return }
            }
        }
    }

    /// Sends the retryable parts of one entry again. The manual retry and the automatic retry use this path.
    ///
    /// `automaticAttempt` is the number of the automatic retry, or nil for a manual retry.
    /// Gives false when the automatic retries of the entry must stop.
    private func retryEntry(id: UUID, automaticAttempt: Int?) async -> Bool {
        let attemptText = automaticAttempt.map { "automatic \($0)" } ?? "manual"
        guard let entry = history.first(where: { $0.id == id }), entry.hasRetryableParts else { return false }
        // Only one retry of an entry runs at a time. An automatic retry skips this attempt
        // when a manual retry of the entry runs, and the next automatic retry can occur.
        guard !retryingEntries.contains(id) else {
            Self.log.notice("Boost retry skipped: \(attemptText, privacy: .public), a retry runs")
            return true
        }
        retryingEntries.insert(id)
        defer { retryingEntries.remove(id) }

        let amountSats = entry.retryableSats
        let day = SpendingLimit.dayKey(for: Date())
        // ADR 0016 §The limits of a retry: the daily limit stops only an automatic retry of an auto-boost.
        // The boosts that pay at this time count.
        if automaticAttempt != nil, entry.kind == .auto {
            let limit = SpendingLimitStore().limit.recording(reservedSats, on: day)
            guard limit.permits(amountSats, on: day) else {
                Self.log.notice("Boost retry stopped: \(attemptText, privacy: .public), over the daily limit")
                status = BoostStatusText.text(for: .overDailyLimit(remainingSats: limit.remaining(on: day)))
                return false
            }
        }

        // An auto-boost at the same time counts this amount in its limit check.
        reservedSats += amountSats
        defer { reservedSats -= amountSats }

        let connection: NWCConnection?
        do {
            connection = try await walletStore.connection()
        } catch {
            connection = nil
        }
        guard let connection else {
            Self.log.notice("Boost retry not sent: \(attemptText, privacy: .public), no wallet")
            status = BoostStatusText.noWallet
            return false
        }
        let retryCount = entry.parts.filter(\.isRetryable).count
        Self.log.notice(
            "Boost retry started: \(attemptText, privacy: .public), \(retryCount, privacy: .public) parts, \(amountSats, privacy: .public) sats"
        )
        let client = NWCClient(connection: connection, connector: connector, timeout: .seconds(30))
        let payer = BoostPayer(wallet: client, fetcher: fetcher)
        let newParts = await payer.retry(parts: entry.parts)

        // ADR 0016 §The limits of a retry: record only the parts that changed in this retry.
        // A part that changed from failed to confirmed or unknown counts. An unknown part can be paid.
        var spent = 0
        for (old, new) in zip(entry.parts, newParts)
        where old.result == .failed && (new.result == .confirmed || new.result == .unknown) {
            spent += new.sats
        }
        if spent > 0 {
            SpendingLimitStore().record(spent, on: SpendingLimit.dayKey(for: Date()))
        }

        // The retry updates the same entry. It adds no new entry.
        let updatedEntry = entry.replacingParts(newParts)
        var updated = BoostHistory(entries: history)
        updated.update(updatedEntry)
        history = updated.entries
        // The store actor writes the file off the main actor.
        _ = await historyStore.update(updatedEntry)

        let result = BoostResult(parts: newParts)
        Self.log.notice(
            "Boost retry done: \(attemptText, privacy: .public), \(result.paidParts, privacy: .public) of \(result.totalParts, privacy: .public) parts paid, \(result.unknownParts, privacy: .public) unknown, \(spent, privacy: .public) sats recorded"
        )
        status = BoostStatusText.retryText(for: result)
        return updatedEntry.hasRetryableParts
    }

    /// The name of a skip reason for the log. It contains no title and no key.
    private static func reasonName(_ reason: BoostSkipReason) -> String {
        switch reason {
        case .disabled: "disabled"
        case .noTrack: "noTrack"
        case .noPayload: "noPayload"
        case .alreadyPaid: "alreadyPaid"
        case .tooShort: "tooShort"
        case .overDailyLimit: "overDailyLimit"
        case .nothingToPay: "nothingToPay"
        }
    }
}
#endif
