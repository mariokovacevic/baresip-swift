import Foundation
import AVFoundation
import BaresipKit

/// Where call audio is played.
public enum BaresipAudioRoute: Sendable, Equatable {
    /// The receiver at the top of the phone.
    case earpiece
    /// The built-in loudspeaker.
    case speaker
    /// A Bluetooth headset or car kit.
    case bluetooth
    /// Wired or USB headphones.
    case wiredHeadset
    /// Another output, with its AVFoundation port type.
    case other(String)
}

/// Configures the `AVAudioSession` for VoIP and keeps the engine informed about it.
///
/// With CallKit, iOS activates the session; forward the provider's activation callbacks with
/// ``didActivateFromCallKit()`` and ``didDeactivateFromCallKit()``. Without CallKit, or to hear
/// an early media preview before answering, call ``activate()`` yourself.
///
/// ```swift
/// let audio = BaresipAudioSessionController(engine: engine)
/// try audio.configureForVoIP()
/// ```
@MainActor
public final class BaresipAudioSessionController {
    private let engine: BaresipEngine
    private let session: AVAudioSession
    private let observers = NotificationObservers()
    private let onRouteChange: (@MainActor (BaresipAudioRoute) -> Void)?

    /// Creates the controller and starts observing route changes and interruptions.
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
    nonisolated public static func voipCategoryOptions(allowBluetooth: Bool, defaultToSpeaker: Bool) -> AVAudioSession.CategoryOptions {
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
    /// - Parameters:
    ///   - allowBluetooth: Whether Bluetooth routes are allowed.
    ///   - defaultToSpeaker: Whether audio starts on the loudspeaker.
    /// - Throws: The `AVAudioSession` error.
    public func configureForVoIP(allowBluetooth: Bool = true, defaultToSpeaker: Bool = false) throws {
        let options = Self.voipCategoryOptions(allowBluetooth: allowBluetooth, defaultToSpeaker: defaultToSpeaker)
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
    }

    /// Activates the session and tells the engine. Use this without CallKit.
    ///
    /// - Throws: The `AVAudioSession` error.
    public func activate() async throws {
        try session.setActive(true, options: [])
        await engine.audioSessionDidActivate()
    }

    /// Tells the engine and deactivates the session, letting other apps resume their audio.
    public func deactivate() async {
        await engine.audioSessionDidDeactivate()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Forwards `provider(_:didActivate:)` from CallKit to the engine.
    public func didActivateFromCallKit() async {
        await engine.audioSessionDidActivate()
    }

    /// Forwards `provider(_:didDeactivate:)` from CallKit to the engine.
    public func didDeactivateFromCallKit() async {
        await engine.audioSessionDidDeactivate()
    }

    /// Routes audio to the loudspeaker or back to the default route.
    ///
    /// - Parameter enabled: `true` for the loudspeaker.
    /// - Throws: The `AVAudioSession` error.
    public func setSpeakerEnabled(_ enabled: Bool) throws {
        try session.overrideOutputAudioPort(enabled ? .speaker : .none)
    }

    /// The current output route.
    public var currentRoute: BaresipAudioRoute {
        guard let output = session.currentRoute.outputs.first else { return .other("none") }
        switch output.portType {
        case .builtInReceiver: return .earpiece
        case .builtInSpeaker: return .speaker
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE: return .bluetooth
        case .headphones, .usbAudio: return .wiredHeadset
        default: return .other(output.portType.rawValue)
        }
    }

    private func observe() {
        let center = NotificationCenter.default
        observers.add(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.engine.audioRouteDidChange()
                self.onRouteChange?(self.currentRoute)
            }
        })
        observers.add(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: session, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.engine.audioInterruption(began: type == .began)
            }
        })
    }
}

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
