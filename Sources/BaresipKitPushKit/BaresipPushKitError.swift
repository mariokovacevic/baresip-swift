/// An error of ``BaresipPushKitAdapter`` that comes neither from PushKit nor from the engine.
public enum BaresipPushKitError: Error, Sendable, Equatable {
    /// The asynchronous push handler did not return before its deadline, so a placeholder call
    /// was reported for the push.
    case reportTimedOut
}
