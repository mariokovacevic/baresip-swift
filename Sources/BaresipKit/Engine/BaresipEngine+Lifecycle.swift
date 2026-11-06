extension BaresipEngine {
    /// Starts the engine: loads modules, opens transports and starts the engine thread.
    ///
    /// - Throws: ``BaresipError`` when the engine is not idle or a module fails to load.
    public func start() async throws {
        try await run { try $0.start() }
    }

    /// Stops the engine. Calls are hung up and accounts unregister, within `timeout`.
    ///
    /// - Parameter timeout: The longest time to wait for unregistration.
    public func stop(timeout: Duration = .seconds(3)) async {
        _ = try? await run { try $0.stop(timeout: timeout) }
    }

    /// Prepares the engine for an incoming call announced by a VoIP push.
    ///
    /// Call this from the PushKit handler before reporting the call to CallKit. The engine
    /// resumes if it was suspended and refreshes registrations so the INVITE can arrive.
    ///
    /// - Throws: ``BaresipError`` when the engine is not running.
    public func prepareForPushWakeUp() async throws {
        try await run { try $0.prepareForPushWakeUp() }
    }

    /// Suspends the engine when the app moves to the background without an active call.
    ///
    /// - Throws: ``BaresipError`` when the engine is not running.
    public func suspend() async throws {
        try await run { try $0.suspend() }
    }

    /// Resumes an engine suspended with ``suspend()``.
    ///
    /// - Throws: ``BaresipError`` when the engine is not suspended.
    public func resumeFromBackground() async throws {
        try await run { try $0.resume() }
    }

    /// The previous name of ``resumeFromBackground()``.
    @available(*, deprecated, renamed: "resumeFromBackground()")
    public func resume() async throws {
        try await resumeFromBackground()
    }

    /// Tells the engine that the network path changed, for example from `NWPathMonitor`.
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
