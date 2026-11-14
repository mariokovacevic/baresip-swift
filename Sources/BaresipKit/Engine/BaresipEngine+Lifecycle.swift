extension BaresipEngine {
    /// Starts the engine: loads modules, opens transports and starts the engine thread.
    ///
    /// Only one engine may run per process.
    ///
    /// - Throws: ``BaresipError`` when the engine is not idle, another engine is running
    ///   (``BaresipError/Code/busy``) or the core cannot start.
    public func start() async throws {
        try await run { try $0.start() }
    }

    /// Stops the engine. Calls are hung up and accounts unregister, within `timeout`.
    ///
    /// The engine's accounts are removed; add them again after the next ``start()``.
    ///
    /// - Parameter timeout: The longest time to wait for unregistration.
    public func stop(timeout: Duration = .seconds(3)) async {
        _ = try? await run { try $0.stop(timeout: timeout) }
    }

    /// Prepares the engine for an incoming call announced by a VoIP push.
    ///
    /// A running engine sends a REGISTER for every account that is registered or registering,
    /// so the INVITE can arrive on a fresh connection; an account you unregistered stays
    /// unregistered. A stopped engine is started, without accounts: add and register them
    /// afterwards. Report the call to CallKit first, inside the PushKit delegate method; this
    /// method suspends and must not delay the report.
    ///
    /// - Throws: ``BaresipError`` when the engine cannot start or a REGISTER cannot be sent.
    public func prepareForPushWakeUp() async throws {
        try await run { try $0.prepareForPushWakeUp() }
    }

    /// Tells the engine that the app moved to the background without an active call.
    ///
    /// The core keeps its transports and registrations as they are, so this has no effect on
    /// the network today; ``resumeFromBackground()`` does the work when the app comes back.
    ///
    /// - Throws: ``BaresipError`` when the core reports an error.
    public func suspend() async throws {
        try await run { try $0.suspend() }
    }

    /// Brings the engine back after the app returns to the foreground.
    ///
    /// The engine opens its SIP transports again on the current local addresses and registers
    /// every account again, whether or not ``suspend()`` was called before.
    ///
    /// - Throws: ``BaresipError`` when the engine is not running.
    public func resumeFromBackground() async throws {
        try await run { try $0.resume() }
    }

    /// Tells the engine that the network path changed, for example from `NWPathMonitor`.
    ///
    /// The engine reads the local addresses again and opens its transports on them, so this
    /// also brings up an engine that was started without a network.
    ///
    /// - Parameters:
    ///   - reregister: Whether accounts register again on the new address.
    ///   - updateCalls: Whether active calls move to the new address, restarting ICE when used.
    public func networkDidChange(reregister: Bool = true, updateCalls: Bool = true) async {
        _ = try? await run { try $0.networkChanged(reregister: reregister, updateCalls: updateCalls) }
    }

    /// Tells the engine that the audio session was activated, for example by CallKit.
    public func audioSessionDidActivate() async {
        _ = try? await run { try $0.audioSessionActivated() }
    }

    /// Tells the engine that the audio session was deactivated.
    public func audioSessionDidDeactivate() async {
        _ = try? await run { try $0.audioSessionDeactivated() }
    }

    /// Tells the engine that the audio route changed, so audio units are restarted.
    public func audioRouteDidChange() async {
        _ = try? await run { try $0.audioRouteChanged() }
    }

    /// Tells the engine that an audio interruption began or ended.
    ///
    /// - Parameter began: `true` when the interruption began.
    public func audioInterruption(began: Bool) async {
        _ = try? await run { try $0.audioInterruption(began: began) }
    }
}
