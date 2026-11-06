import Foundation
import AVFoundation
import BaresipKit

public enum BaresipAudioRoute: Sendable, Equatable {
    case earpiece
    case speaker
    case bluetooth
    case wiredHeadset
    case other(String)
}

@MainActor
public final class BaresipAudioSessionController {
    private let engine: BaresipEngine
    private let session: AVAudioSession
    private var observers: [NSObjectProtocol] = []
    private let onRouteChange: (@MainActor (BaresipAudioRoute) -> Void)?

    public init(engine: BaresipEngine, session: AVAudioSession = .sharedInstance(),
                onRouteChange: (@MainActor (BaresipAudioRoute) -> Void)? = nil) {
        self.engine = engine
        self.session = session
        self.onRouteChange = onRouteChange
        observe()
    }

    deinit {
        let center = NotificationCenter.default
        for o in observers {
            center.removeObserver(o)
        }
    }

    public func configureForVoIP(allowBluetooth: Bool = true, defaultToSpeaker: Bool = false) throws {
        var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
        if allowBluetooth {
            options.insert(.allowBluetoothA2DP)
        }
        if defaultToSpeaker {
            options.insert(.defaultToSpeaker)
        }
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
    }

    public func activate() async throws {
        try session.setActive(true, options: [])
        await engine.audioSessionDidActivate()
    }

    public func deactivate() async {
        await engine.audioSessionDidDeactivate()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    public func didActivateFromCallKit() async {
        await engine.audioSessionDidActivate()
    }

    public func didDeactivateFromCallKit() async {
        await engine.audioSessionDidDeactivate()
    }

    public func setSpeakerEnabled(_ enabled: Bool) throws {
        try session.overrideOutputAudioPort(enabled ? .speaker : .none)
    }

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
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.engine.audioRouteDidChange()
                self.onRouteChange?(self.currentRoute)
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
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
