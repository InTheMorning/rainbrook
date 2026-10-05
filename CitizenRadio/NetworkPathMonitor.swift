#if os(iOS)
import Foundation
import Network
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Watches the network path with `NWPathMonitor`.
/// ADR 0008 §Transport: a path change starts a reconnect at once.
final class NetworkPathMonitor: Sendable {
    init() {}

    /// Gives a NetworkPathSummary for each path update. Cancel the consumer task to stop the monitor.
    ///
    /// The monitor starts on a private serial queue. Its `pathUpdateHandler` captures
    /// only the stream's continuation, and holds no other mutable state. The stream's
    /// `onTermination` cancels the monitor.
    func summaries() -> AsyncStream<NetworkPathSummary> {
        let (stream, continuation) = AsyncStream<NetworkPathSummary>.makeStream()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            continuation.yield(
                NetworkPathSummary(
                    isSatisfied: path.status == .satisfied,
                    interfaces: path.availableInterfaces.map(\.name)
                )
            )
        }
        continuation.onTermination = { _ in
            monitor.cancel()
        }
        monitor.start(queue: DispatchQueue(label: "org.citizenradio.CitizenRadio.network-path-monitor"))
        return stream
    }
}
#endif
