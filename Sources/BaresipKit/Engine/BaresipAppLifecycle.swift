#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit

    /// Follows the app's lifecycle for an engine: takes it offline or pauses it in the background
    /// when no call runs, brings it back online when the app is active again, and disconnects it
    /// when the app terminates.
    ///
    /// - The app moves to the background with no call: what happens is ``backgroundBehavior``.
    ///   With ``BackgroundBehavior/goOffline`` every registered account unregisters, so the app is
    ///   not reachable until it returns. With ``BackgroundBehavior/suspend`` the engine is suspended
    ///   (``BaresipEngine/suspend()``) and its registrations stay on the server, so a VoIP push can
    ///   still announce a call. A call that ends while the app is in the background does the same.
    /// - The app becomes active again: the transports open again and the accounts register.
    /// - The app terminates: the engine stops, which ends the calls and unregisters every account
    ///   (``BaresipEngine/stop(timeout:)``).
    ///
    /// iOS tells a suspended app nothing when it is removed from the app switcher; a registration
    /// that is still on the server then stays until it expires. Each behaviour can be turned off,
    /// and an app can call the engine itself instead of using this type.
    ///
    /// ```swift
    /// let lifecycle = BaresipAppLifecycle(engine: engine)
    /// lifecycle.backgroundBehavior = .goOffline
    /// lifecycle.start()
    /// ```
    @MainActor
    public final class BaresipAppLifecycle {
        /// What happens in the background while no call runs.
        public enum BackgroundBehavior: Sendable, Equatable {
            /// Nothing: the engine stays as it is.
            case stayOnline
            /// The engine is suspended and its registrations stay on the server, so a VoIP push
            /// can announce a call.
            case suspend
            /// Every registered account unregisters; nobody can reach the app until it is active
            /// again.
            case goOffline
        }

        /// What the lifecycle did to the engine.
        public enum Change: Sendable, Equatable {
            /// The engine was suspended in the background.
            case suspended
            /// The accounts unregistered in the background.
            case wentOffline
            /// The app is active again: the transports opened and the accounts register.
            case backOnline
            /// The engine stopped because the app terminates.
            case disconnected
        }

        /// The engine whose lifecycle is followed.
        public let engine: BaresipEngine

        /// What happens in the background while no call runs. ``BackgroundBehavior/suspend`` by
        /// default.
        public var backgroundBehavior: BackgroundBehavior = .suspend

        /// Whether the engine stops, unregistering its accounts, when the app terminates. On by
        /// default.
        public var disconnectsOnTermination = true

        /// How long going offline and termination wait for the accounts to unregister.
        ///
        /// iOS ends the process as soon as the termination notification returns, so termination
        /// waits on the main thread, for at most this long plus one second.
        public var unregisterTimeout: Duration = .seconds(2)

        /// Whether the lifecycle suspended the engine or took it offline and has not brought it
        /// back yet.
        public private(set) var isAway = false

        /// Whether going offline asks iOS for background time, so the unregistration is sent.
        /// Off in unit tests, which have no app.
        var usesBackgroundTasks = true

        private var isInBackground = false
        /// Set while the lifecycle goes away, so two attempts do not both run.
        private var isGoingAway = false
        /// The accounts that unregistered in the background, to register again.
        private var offlineAccounts: [BaresipAccountID] = []
        private let observers = NotificationObservers()
        private var eventTask: Task<Void, Never>?
        private var changeHandler: (@MainActor (Change) -> Void)?

        /// Creates the lifecycle for an engine. Call ``start()`` to begin following the app.
        ///
        /// - Parameter engine: The engine.
        public init(engine: BaresipEngine) {
            self.engine = engine
        }

        /// Sets a handler called after the lifecycle changed the engine, for example to log it.
        ///
        /// - Parameter handler: The handler, or `nil` to remove it.
        public func setChangeHandler(_ handler: (@MainActor (Change) -> Void)?) {
            changeHandler = handler
        }

        /// Starts following the app's lifecycle and the engine's calls.
        public func start() {
            guard observers.isEmpty else { return }
            isInBackground = UIApplication.shared.applicationState == .background
            let center = NotificationCenter.default
            observers.add(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil,
                                             queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.didEnterBackground() }
                })
            observers.add(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil,
                                             queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.didBecomeActive() }
                })
            observers.add(center.addObserver(forName: UIApplication.willTerminateNotification, object: nil,
                                             queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.willTerminate() }
                })
            let events = engine.events
            eventTask = Task { [weak self] in
                for await event in events {
                    guard let self else { return }
                    if case .call(_, .released, _) = event {
                        await goAwayIfIdle()
                    }
                }
            }
        }

        /// Stops following the app. An engine that is away stays away.
        public func stop() {
            observers.removeAll()
            eventTask?.cancel()
            eventTask = nil
        }

        func didEnterBackground() {
            isInBackground = true
            Task { await goAwayIfIdle() }
        }

        func didBecomeActive() {
            isInBackground = false
            guard isAway else { return }
            isAway = false
            let accounts = offlineAccounts
            offlineAccounts = []
            Task {
                if accounts.isEmpty {
                    try? await engine.resumeFromBackground()
                } else {
                    await engine.networkDidChange(reregister: false, updateCalls: false)
                    for account in accounts {
                        try? await engine.register(accountID: account)
                    }
                }
                changeHandler?(.backOnline)
            }
        }

        /// Stops the engine before the process ends. iOS gives the app a few seconds here, so this
        /// waits for the engine on the main thread; the engine works on its own queue.
        func willTerminate() {
            guard disconnectsOnTermination else { return }
            stop()
            let engine = engine
            let timeout = unregisterTimeout
            let done = DispatchSemaphore(value: 0)
            Task.detached {
                await engine.stop(timeout: timeout)
                done.signal()
            }
            let seconds = Double(timeout.components.seconds) + 1
            _ = done.wait(timeout: .now() + seconds)
            changeHandler?(.disconnected)
        }

        func goAwayIfIdle() async {
            guard backgroundBehavior != .stayOnline, isInBackground, !isAway, !isGoingAway,
                  engine.state == .running || engine.state == .ready else { return }
            isGoingAway = true
            defer { isGoingAway = false }
            guard await engine.activeCalls().isEmpty, isInBackground else { return }
            switch backgroundBehavior {
            case .stayOnline:
                return
            case .suspend:
                do {
                    try await engine.suspend()
                } catch {
                    return
                }
                isAway = true
                changeHandler?(.suspended)
            case .goOffline:
                offlineAccounts = await unregisterAll()
                isAway = true
                changeHandler?(.wentOffline)
            }
            if !isInBackground {
                didBecomeActive()
            }
        }

        /// Unregisters every registered account and waits until they are unregistered or the
        /// timeout passed.
        ///
        /// - Returns: The accounts that were registered.
        private func unregisterAll() async -> [BaresipAccountID] {
            let backgroundTask = beginBackgroundTask()
            defer { endBackgroundTask(backgroundTask) }
            let registered = await engine.accounts()
                .filter { $0.value == .registered || $0.value == .registering }
                .map(\.key)
            for account in registered {
                try? await engine.unregister(accountID: account)
            }
            let deadline = ContinuousClock.now.advanced(by: unregisterTimeout)
            while ContinuousClock.now < deadline {
                let states = await engine.accounts()
                let pending = registered.contains { states[$0] == .registered || states[$0] == .unregistering }
                if !pending {
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            return registered
        }

        private func beginBackgroundTask() -> BackgroundTaskBox {
            let box = BackgroundTaskBox()
            guard usesBackgroundTasks else { return box }
            box.identifier = UIApplication.shared.beginBackgroundTask(withName: "BaresipKit unregister") {
                MainActor.assumeIsolated { box.end() }
            }
            return box
        }

        private func endBackgroundTask(_ box: BackgroundTaskBox) {
            box.end()
        }
    }

    /// A background task that is ended once, by whichever comes first: the work or iOS.
    @MainActor
    private final class BackgroundTaskBox {
        var identifier: UIBackgroundTaskIdentifier = .invalid

        func end() {
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }
#endif
