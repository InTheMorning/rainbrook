#if os(iOS)
import Foundation
import os
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Decides and pays the boosts of one playback session. ADR 0012 owns the rules.
///
/// `TrackInfoModel` gives the ICY texts, the relay tracks and the live value payloads to this model.
/// This model runs on the main actor and does no blocking work. The Keychain read occurs in
/// `WalletStore`. The NWC payments and the LNURL requests occur in `BoostPayer` and `NWCClient`.
@MainActor
final class BoostModel: ObservableObject {
    /// The result of the last boost, for the Wallet section.
    @Published private(set) var status: String?

    private static let log = Logger(subsystem: "org.citizenradio.CitizenRadio", category: "boost")

    private let walletStore: WalletStore
    private let connector: any RelayConnecting
    private let fetcher: any SnapshotFetching

    private var trigger = BoostTrigger()
    private var pairing = BoostPairing()
    /// ADR 0012 §The limits: the blocks of this session that the app paid or started to pay.
    private var paidBlocks = Set<String>()
    /// The amounts of the boosts that are still paying. The limit check counts them,
    /// so two boosts at the same time cannot go over the daily limit (ADR 0012 §The limits).
    private var reservedSats = 0

    init(
        walletStore: WalletStore = WalletStore(secrets: KeychainSecretStore()),
        connector: any RelayConnecting = URLSessionRelayConnector(),
        fetcher: any SnapshotFetching = URLSessionSnapshotFetcher()
    ) {
        self.walletStore = walletStore
        self.connector = connector
        self.fetcher = fetcher
    }

    // MARK: - Inputs

    /// Gives an ICY text to the trigger. A completed track starts a boost.
    func icyText(_ text: String) {
        guard let completed = trigger.receiveIcyText(text) else { return }
        boost(completed)
    }

    /// Gives the relay track that ICY sync selected to the trigger.
    func selectedTrack(_ track: TrackDisplay?) {
        trigger.selectedTrack(track)
    }

    /// Keeps a live value payload for the pairing.
    func payload(_ payload: LiveValuePayload) {
        pairing.receive(payload)
    }

    /// Ends the session. The candidate, the payloads and the paid blocks are cleared.
    func sessionEnded() {
        trigger.endSession()
        pairing.clear()
        paidBlocks.removeAll()
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
            pay(parts: parts, payload: payload, amountSats: amountSats)
        }
    }

    /// Pays one boost in a task. Two boosts can run at the same time. Each boost has its own payer.
    private func pay(parts: [BoostPart], payload: LiveValuePayload, amountSats: Int) {
        let walletStore = self.walletStore
        let connector = self.connector
        let fetcher = self.fetcher
        Task { [weak self] in
            let connection: NWCConnection?
            do {
                connection = try await walletStore.connection()
            } catch {
                connection = nil
            }
            guard let connection else {
                Self.log.notice("Boost not paid: no wallet")
                self?.reservedSats -= amountSats
                self?.status = BoostStatusText.noWallet
                return
            }
            let client = NWCClient(connection: connection, connector: connector, timeout: .seconds(30))
            let payer = BoostPayer(wallet: client, fetcher: fetcher)
            let result = await payer.pay(
                parts: parts, payload: payload, amountSats: amountSats, sender: BoostSender(settings: BoostSettings())
            )

            // ADR 0012 §The limits: a part with an unknown result can be paid, so it counts.
            let spent = result.paidSats + result.unknownSats
            if spent > 0 {
                SpendingLimitStore().record(spent, on: SpendingLimit.dayKey(for: Date()))
            }
            self?.reservedSats -= amountSats
            Self.log.notice(
                "Boost done: \(result.paidParts, privacy: .public) of \(result.totalParts, privacy: .public) parts paid, \(result.unknownParts, privacy: .public) unknown, \(result.paidSats, privacy: .public) sats paid"
            )
            self?.status = BoostStatusText.text(for: result)
        }
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
