import Foundation

final class NotificationObservers: @unchecked Sendable {
    // SAFETY: tokens are added on the main actor during init and removed only in deinit, after
    // the owning controller is gone; NotificationCenter.removeObserver is thread-safe.
    private var tokens: [NSObjectProtocol] = []

    func add(_ token: NSObjectProtocol) {
        tokens.append(token)
    }

    deinit {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
