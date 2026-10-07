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

    private static let log = Logger(subsystem: "org.citizenradio.CitizenRadio", category: "boost")

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

    /// Gives an ICY text to the trigger. A completed track starts a boost.
    func icyText(_ text: String) {
        guard let completed = trigger.receiveIcyText(text) else { return }
        boost(completed)
    }

    /// Gives the relay track that ICY sync selected to the trigger.
    /// Also keeps the track, also nil, as the current track for a manual boost.
    func selectedTrack(_ track: TrackDisplay?) {
        trigger.selectedTrack(track)
        currentTrack = track
        updateManualTarget()
    }

    /// Keeps a live value payload for the pairing.
    func payload(_ payload: LiveValuePayload) {
        pairing.receive(payload)
        updateManualTarget()
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
        if let currentTrack, pairing.payload(for: currentTrack) != nil {
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
            day: day
        )

        switch decision {
        case .skip(let reason):
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
        guard let result = await pay(parts: parts, payload: payload, amountSats: amountSats, sender: sender) else {
            status = BoostStatusText.noWallet
            return
        }
        status = BoostStatusText.text(for: result)
        if let track {
            await addHistoryEntry(kind: .auto, track: track, amountSats: amountSats, message: sender.message, result: result)
        }
    }

    // MARK: - Manual boost

    /// Sends one manual boost for the given track, and gives the result text for the boost sheet.
    ///
    /// The boost sheet gives the track of the moment that it opened. Usually this track is `manualTarget`.
    /// ADR 0013 §The limits: the daily limit does not stop a manual boost, but its sats count.
    /// A skipped boost gives no history entry.
    func sendManualBoost(track: TrackDisplay?, amountSats: Int, message: String) async -> String {
        let decision = BoostPlan.decideManual(amountSats: amountSats, track: track, pairing: pairing)
        switch decision {
        case .skip(let reason):
            Self.log.notice("Manual boost skipped: \(Self.reasonName(reason), privacy: .public)")
            return BoostStatusText.text(for: reason) ?? "No boost. No V4V track plays."
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
            guard let result = await pay(parts: parts, payload: payload, amountSats: amountSats, sender: sender) else {
                status = BoostStatusText.noWallet
                return BoostStatusText.noWallet
            }
            let text = BoostStatusText.text(for: result)
            status = text
            if let track {
                await addHistoryEntry(kind: .manual, track: track, amountSats: amountSats, message: sender.message, result: result)
            }
            return text
        }
    }

    // MARK: - Payment and history

    /// Pays the parts of one boost. The auto-boost and the manual boost use this path.
    ///
    /// The caller adds `amountSats` to `reservedSats` before this call. This method removes it on each path.
    /// Gives nil when no wallet is connected. Then no payment starts.
    private func pay(
        parts: [BoostPart], payload: LiveValuePayload, amountSats: Int, sender: BoostSender
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
        let result = await payer.pay(parts: parts, payload: payload, amountSats: amountSats, sender: sender)

        // ADR 0013 §The limits: a part with an unknown result can be paid, so it counts.
        let spent = result.paidSats + result.unknownSats
        if spent > 0 {
            SpendingLimitStore().record(spent, on: SpendingLimit.dayKey(for: Date()))
        }
        Self.log.notice(
            "Boost done: \(result.paidParts, privacy: .public) of \(result.totalParts, privacy: .public) parts paid, \(result.unknownParts, privacy: .public) unknown, \(result.paidSats, privacy: .public) sats paid"
        )
        return result
    }

    /// Adds one entry to the history list, then to the history store.
    /// The store is an actor, so the file write occurs off the main actor.
    private func addHistoryEntry(
        kind: BoostHistoryEntry.Kind, track: TrackDisplay, amountSats: Int, message: String?, result: BoostResult
    ) async {
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
    }

    /// The name of a skip reason for the log. It contains no title and no key.
    private static func reasonName(_ reason: BoostSkipReason) -> String {
        switch reason {
        case .disabled: "disabled"
        case .noTrack: "noTrack"
        case .noPayload: "noPayload"
        case .alreadyPaid: "alreadyPaid"
        case .overDailyLimit: "overDailyLimit"
        case .nothingToPay: "nothingToPay"
        }
    }
}
#endif
