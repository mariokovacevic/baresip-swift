import Foundation

package final class NotificationObservers: @unchecked Sendable {
    // SAFETY: tokens are added and removed on the main actor while the owner lives, and removed
    // in deinit only after the owner is gone; NotificationCenter.removeObserver is thread-safe.
    private var tokens: [NSObjectProtocol] = []

    package init() {}

    package var isEmpty: Bool {
        tokens.isEmpty
    }

    package func add(_ token: NSObjectProtocol) {
        tokens.append(token)
    }

    package func removeAll() {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
        tokens.removeAll()
    }

    deinit {
        removeAll()
    }
}
