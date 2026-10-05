import Foundation

/// The user texts for the relay status in the Track info section of Settings.
/// ADR 0008 §Transport names the two errors that stop the client.
public enum RelayStatusText {
    /// The text for Settings, or nil when no message is necessary.
    public static func message(for status: EventStreamStatus?) -> String? {
        switch status {
        case .stopped(.notFound):
            return "The relay does not know this event. Examine the track info address."
        case .stopped(.notReserved):
            return "The relay event is not reserved. Ask the stream producer to reserve it."
        case .waiting:
            return "The relay is not available. CitizenRadio tries again."
        case .connecting, .live, .stopped(.requested), nil:
            return nil
        }
    }
}
