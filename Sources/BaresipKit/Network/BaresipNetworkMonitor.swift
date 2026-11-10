import Foundation
import Network

/// A summary of one `NWPath` update, for logging or display.
public struct BaresipNetworkPath: Sendable, Equatable {
    /// The available interface types, comma-separated, for example `"wifi,cellular"`.
    public let interfaceSummary: String
    /// Whether the path is usable.
    public let isSatisfied: Bool
}

/// Watches the network path and tells a ``BaresipEngine`` when it is worth reacting to.
///
/// Wraps `NWPathMonitor`: it ignores the first path (the one in effect when the engine
/// started), unsatisfied paths, and repeats of the same interface summary, then calls
/// ``BaresipEngine/networkDidChange(reregister:updateCalls:)`` for the rest.
///
/// ```swift
/// let monitor = BaresipNetworkMonitor(engine: engine)
/// monitor.setChangeHandler { path in print("network: \(path.interfaceSummary)") }
/// monitor.start()
/// ```
public final class BaresipNetworkMonitor: @unchecked Sendable {
    // SAFETY: `pathMonitor`, `lastPath` and `changeHandler` are read and written only while
    // holding `lock`.

    private let engine: BaresipEngine
    private let reregister: Bool
    private let updateCalls: Bool
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "baresipkit.networkmonitor")
    private var pathMonitor: NWPathMonitor?
    private var lastPath: BaresipNetworkPath?
    private var changeHandler: (@Sendable (BaresipNetworkPath) -> Void)?

    /// Creates a monitor for `engine`. Call ``start()`` to begin watching.
    ///
    /// - Parameters:
    ///   - engine: The engine to notify of network changes.
    ///   - reregister: Whether accounts register again on the new address.
    ///   - updateCalls: Whether active calls move to the new address.
    public init(engine: BaresipEngine, reregister: Bool = true, updateCalls: Bool = true) {
        self.engine = engine
        self.reregister = reregister
        self.updateCalls = updateCalls
    }

    deinit {
        pathMonitor?.cancel()
    }

    /// Sets a handler called with every path update, satisfied or not, for logging.
    ///
    /// - Parameter handler: The handler, or `nil` to remove one.
    public func setChangeHandler(_ handler: (@Sendable (BaresipNetworkPath) -> Void)?) {
        lock.withLock { changeHandler = handler }
    }

    /// Starts watching the network path. Does nothing if already started.
    public func start() {
        lock.withLock {
            guard pathMonitor == nil else { return }
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.pathUpdated(path)
            }
            monitor.start(queue: queue)
            pathMonitor = monitor
        }
    }

    /// Stops watching the network path.
    public func stop() {
        lock.withLock {
            pathMonitor?.cancel()
            pathMonitor = nil
            lastPath = nil
        }
    }

    private func pathUpdated(_ path: NWPath) {
        let current = BaresipNetworkPath(
            interfaceSummary: path.availableInterfaces.map { "\($0.type)" }.joined(separator: ","),
            isSatisfied: path.status == .satisfied
        )
        let (handler, notify) = lock.withLock {
            () -> ((@Sendable (BaresipNetworkPath) -> Void)?, Bool) in
            let previous = lastPath
            lastPath = current
            return (changeHandler, BaresipNetworkMonitor.shouldNotifyEngine(current: current, previous: previous))
        }
        handler?(current)
        guard notify else { return }
        let reregister = reregister
        let updateCalls = updateCalls
        Task { [engine] in
            await engine.networkDidChange(reregister: reregister, updateCalls: updateCalls)
        }
    }

    /// Decides whether a path update is worth telling the engine about.
    ///
    /// Pulled out of ``pathUpdated(_:)`` so the decision can be unit tested without
    /// `NWPathMonitor`. `previous` is `nil` for the first update, which is never notified:
    /// it is the path already in effect when monitoring started.
    static func shouldNotifyEngine(current: BaresipNetworkPath, previous: BaresipNetworkPath?) -> Bool {
        guard let previous, current.isSatisfied else { return false }
        return current.interfaceSummary != previous.interfaceSummary
    }
}
