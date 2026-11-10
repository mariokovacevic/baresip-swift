#if os(iOS)
    import Foundation
    import AVFoundation
    import BaresipKit

    /// Configures the `AVAudioSession` for VoIP and keeps the engine informed about it.
    ///
    /// With CallKit, iOS activates the session; forward the provider's activation callbacks with
    /// ``didActivateFromCallKit()`` and ``didDeactivateFromCallKit()``. Without CallKit, or to hear
    /// an early media preview before answering, call ``activate()`` yourself.
    ///
    /// An interruption pauses the engine's audio. When it ends and iOS says the app should resume,
    /// the controller activates the session again if ``activate()`` had activated it, and then
    /// resumes the engine; a session activated by CallKit resumes with the next
    /// ``didActivateFromCallKit()``. After a reset of the media services the controller applies
    /// the category from ``configureForVoIP(allowBluetooth:defaultToSpeaker:)`` again and restarts
    /// the engine's audio.
    ///
    /// ```swift
    /// let audio = BaresipAudioSessionController(engine: engine)
    /// try audio.configureForVoIP()
    /// ```
    @MainActor
    public final class BaresipAudioSessionController {
        let engine: BaresipEngine
        let session: AVAudioSession
        var activation = SessionActivation.inactive
        var voipOptions: AVAudioSession.CategoryOptions?
        private let observers = NotificationObservers()
        private let onRouteChange: (@MainActor (BaresipAudioRoute) -> Void)?

        /// Creates the controller and starts observing route changes, interruptions and resets of
        /// the media services.
        ///
        /// - Parameters:
        ///   - engine: The engine to inform.
        ///   - session: The audio session, the shared instance by default.
        ///   - onRouteChange: Called on the main actor with the new route after each change.
        public init(engine: BaresipEngine, session: AVAudioSession = .sharedInstance(),
                    onRouteChange: (@MainActor (BaresipAudioRoute) -> Void)? = nil) {
            self.engine = engine
            self.session = session
            self.onRouteChange = onRouteChange
            observe()
        }

        /// The category options for a VoIP session.
        ///
        /// - Parameters:
        ///   - allowBluetooth: Whether Bluetooth HFP and A2DP routes are allowed.
        ///   - defaultToSpeaker: Whether audio starts on the loudspeaker.
        /// - Returns: The options for `setCategory(_:mode:options:)`.
        public nonisolated static func voipCategoryOptions(
            allowBluetooth: Bool,
            defaultToSpeaker: Bool
        ) -> AVAudioSession.CategoryOptions {
            var options: AVAudioSession.CategoryOptions = []
            if allowBluetooth {
                #if compiler(>=6.2)
                    options.insert(.allowBluetoothHFP)
                #else
                    options.insert(.allowBluetooth)
                #endif
                options.insert(.allowBluetoothA2DP)
            }
            if defaultToSpeaker {
                options.insert(.defaultToSpeaker)
            }
            return options
        }

        /// Sets the `playAndRecord` category with the `voiceChat` mode.
        ///
        /// The controller applies the same category again after a reset of the media services.
        ///
        /// - Parameters:
        ///   - allowBluetooth: Whether Bluetooth routes are allowed.
        ///   - defaultToSpeaker: Whether audio starts on the loudspeaker.
        /// - Throws: The `AVAudioSession` error.
        public func configureForVoIP(allowBluetooth: Bool = true, defaultToSpeaker: Bool = false) throws {
            let options = Self.voipCategoryOptions(allowBluetooth: allowBluetooth, defaultToSpeaker: defaultToSpeaker)
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
            voipOptions = options
        }

        /// Activates the session and tells the engine. Use this without CallKit.
        ///
        /// After an interruption that ended without iOS asking the app to resume, call this again
        /// to continue the call's audio.
        ///
        /// - Throws: The `AVAudioSession` error.
        public func activate() async throws {
            try await Self.setActive(true, options: [], on: session)
            activation = .controller
            await engine.audioSessionDidActivate()
        }

        /// Tells the engine and deactivates the session, letting other apps resume their audio.
        public func deactivate() async {
            activation = .inactive
            await engine.audioSessionDidDeactivate()
            try? await Self.setActive(false, options: [.notifyOthersOnDeactivation], on: session)
        }

        /// Calls `setActive` off the main thread. It blocks until the audio system has switched
        /// the session, which can take long enough to freeze the UI.
        nonisolated static func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions,
                                          on session: AVAudioSession) async throws {
            #if !compiler(>=6.2)
                // SAFETY: AVAudioSession is thread-safe; older SDKs do not mark it Sendable.
                nonisolated(unsafe) let session = session
            #endif
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try session.setActive(active, options: options)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        /// Forwards `provider(_:didActivate:)` from CallKit to the engine.
        public func didActivateFromCallKit() async {
            activation = .callKit
            await engine.audioSessionDidActivate()
        }

        /// Forwards `provider(_:didDeactivate:)` from CallKit to the engine.
        public func didDeactivateFromCallKit() async {
            activation = .inactive
            await engine.audioSessionDidDeactivate()
        }

        /// Whether a route change needs the engine to restart its audio units.
        ///
        /// Only a device that appeared or went away does. Starting the voice-processing audio unit
        /// itself posts category and configuration changes; restarting on those restarts the unit
        /// again and again, about once a second, and call audio breaks up. Switching between the
        /// earpiece, the loudspeaker and an already connected headset is followed by the unit.
        ///
        /// - Parameter reason: The reason from the route change notification.
        /// - Returns: `true` when the engine should restart its audio units.
        nonisolated static func restartsAudio(_ reason: AVAudioSession.RouteChangeReason?) -> Bool {
            switch reason {
            case .newDeviceAvailable, .oldDeviceUnavailable: return true
            default: return false
            }
        }

        private func observe() {
            let center = NotificationCenter.default
            observers.add(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                             object: session, queue: .main) { [weak self] note in
                    let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                    let reason = raw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if Self.restartsAudio(reason) {
                            await engine.audioRouteDidChange()
                        }
                        onRouteChange?(currentRoute)
                    }
                })
            observers.add(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                             object: session, queue: .main) { [weak self] note in
                    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                    let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                    Task { @MainActor [weak self] in
                        await self?.interruption(type, options: options)
                    }
                })
            let reset = AVAudioSession.mediaServicesWereResetNotification
            let resetObserver = center.addObserver(forName: reset, object: session, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.mediaServicesWereReset()
                }
            }
            observers.add(resetObserver)
        }
    }
#endif
