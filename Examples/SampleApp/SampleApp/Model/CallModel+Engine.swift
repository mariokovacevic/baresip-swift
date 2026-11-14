import Foundation
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitLiveCommunication
import BaresipKitPushKit
import BaresipKitSwiftUI

extension CallModel {
    func startEngine() async {
        do {
            var config = BaresipConfiguration()
            config.userAgent = "BaresipKitSample/1.0"
            config.logLevel = .info
            config.logSIPTrace = logsSIPMessages
            // UI tests send a tone and record to a file; with BSK_LIVE_AUDIO=1, as
            // Tools/DoorStack/simulators.sh starts it, the simulator uses the Mac's microphone
            // and speakers.
            if uiTest, ProcessInfo.processInfo.environment["BSK_LIVE_AUDIO"] != "1" {
                config.modules += ["ausine", "aufile"]
                config.audio = BaresipAudioConfiguration(sourceModule: "ausine", playerModule: "aufile",
                                                         playerDevice: NSTemporaryDirectory() + "speaker.wav")
            }
            config.audio.holdMusicFile = Bundle.main.url(forResource: "HoldMusic", withExtension: "wav")
            let tls = savedTLS
            config.tls = tlsConfiguration(tls)
            profile.configure(&config)
            let options = SettingsStore.load().engine
            apply(options, to: &config)
            let engine = try BaresipEngine(configuration: config)
            engine.setLogHandler(FileLog.shared.handler(
                forwardingTo: BaresipOSLog.handler(subsystem: "com.example.BaresipKitSample")
            ))
            self.engine = engine
            engineTLS = tls
            engineOptions = options
            let events = engine.events
            eventTask = Task { [weak self] in
                for await event in events {
                    await self?.handle(event)
                }
            }
            PreviewNotifications.registerCategories()
            if !usesDirectCalls {
                startSystemCalls(engine: engine)
            }
            // CallKit or LiveCommunicationKit takes the call actions on a device, so the system
            // call screen stays in step.
            let phone = BaresipPhone(engine: engine, callController: systemCalls)
            self.phone = phone
            phoneTask = Task { await phone.run() }
            startPushKit(engine: engine)
            try await engine.start()
            startNetworkMonitor(engine: engine)
            startLifecycle(engine: engine)
            audio = BaresipAudioSessionController(engine: engine) { [weak self] _ in
                self?.audioRouteChanges += 1
            }
            // An intercom is held away from the ear, to see the door: calls start on the
            // loudspeaker, or on a connected headset.
            try audio?.configureForVoIP(defaultToSpeaker: true)
            append(
                """
                engine started, core \(BaresipEngine.coreVersion), CA \
                \(tls.ca == nil ? "system" : "custom"), client certificate \
                \(tls.client == nil ? "none" : "set"), pins \(tls.pins.count)
                """
            )
        } catch {
            append("engine start failed: \(error)")
        }
    }

    /// Creates the adapter of the call screen chosen in Settings: LiveCommunicationKit from
    /// iOS 17.4 when chosen, CallKit otherwise.
    private func startSystemCalls(engine: BaresipEngine) {
        let screen = callScreen.effective
        engineCallScreen = screen
        engineRingtone = ringtone
        if screen == .liveCommunicationKit, #available(iOS 17.4, *) {
            startLiveCommunication(engine: engine)
        } else {
            startCallKit(engine: engine)
        }
        append("call screen: \(screen.title)")
    }

    private func startCallKit(engine: BaresipEngine) {
        var callKitConfiguration = BaresipCallKitConfiguration(supportsVideo: true)
        callKitConfiguration.callUUIDHeader = CallModel.callUUIDHeader
        callKitConfiguration.handleStyle = .phoneNumberWhenNumeric
        callKitConfiguration.ringtoneSound = ringtone.soundFile
        profile.configure(&callKitConfiguration)
        answerWithCamera = callKitConfiguration.sendsCameraOnAnswer
        let adapter = BaresipCallKitAdapter(engine: engine, configuration: callKitConfiguration)
        callKit = adapter
        systemCalls = adapter
    }

    @available(iOS 17.4, *)
    private func startLiveCommunication(engine: BaresipEngine) {
        var configuration = BaresipLiveCommunicationConfiguration(supportsVideo: true,
                                                                  ringtoneName: ringtone.soundFile)
        configuration.callUUIDHeader = CallModel.callUUIDHeader
        configuration.handleStyle = .phoneNumberWhenNumeric
        profile.configure(&configuration)
        answerWithCamera = configuration.sendsCameraOnAnswer
        let adapter = BaresipLiveCommunicationAdapter(engine: engine, configuration: configuration)
        liveCommunication = adapter
        systemCalls = adapter
    }

    /// Restarts the engine with the call screen and ringtone chosen in Settings, once no call
    /// runs; a change during a call waits for its end.
    func applyCallScreen() async {
        guard engine != nil, !usesDirectCalls, needsNewCallScreen else { return }
        if currentCall != nil {
            pendingApply = true
            append("the call screen changes after the current call")
            return
        }
        await restartEngine()
        await register()
    }

    /// Whether the running adapter differs from Settings: another call screen, or a new ringtone
    /// for LiveCommunicationKit, which takes it only when the adapter is created.
    var needsNewCallScreen: Bool {
        guard !usesDirectCalls, let engineCallScreen else { return false }
        if callScreen.effective != engineCallScreen {
            return true
        }
        return engineCallScreen == .liveCommunicationKit && ringtone != engineRingtone
    }

    /// Goes offline in the background when no call runs, or stays registered for VoIP pushes
    /// when the account asks for it, online again when the app is active, and unregisters when
    /// the app terminates.
    private func startLifecycle(engine: BaresipEngine) {
        let lifecycle = BaresipAppLifecycle(engine: engine)
        lifecycle.backgroundBehavior = backgroundBehavior
        lifecycle.setChangeHandler { [weak self] change in
            switch change {
            case .suspended: self?.append("in the background without a call: SIP paused")
            case .wentOffline: self?.append("in the background without a call: SIP offline")
            case .backOnline: self?.append("app active again: SIP online")
            case .disconnected: self?.append("app terminates: unregistered and stopped")
            }
        }
        lifecycle.start()
        self.lifecycle = lifecycle
    }

    /// Lets the engine move registrations and calls to a new network, such as from Wi-Fi to
    /// cellular.
    private func startNetworkMonitor(engine: BaresipEngine) {
        let monitor = BaresipNetworkMonitor(engine: engine)
        monitor.setChangeHandler { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { lastNetworkPath = path.interfaceSummary }
                guard path.isSatisfied, let lastNetworkPath, lastNetworkPath != path.interfaceSummary else { return }
                append("network path changed: \(path.interfaceSummary)")
            }
        }
        monitor.start()
        networkMonitor = monitor
    }

    private func startPushKit(engine: BaresipEngine) {
        let profileType = type(of: profile)
        let callKit = callKit
        let adapter: BaresipPushKitAdapter = if #available(iOS 17.4, *),
                                                let calls = liveCommunication as? BaresipLiveCommunicationAdapter {
            BaresipPushKitAdapter.reportingAsynchronously(engine: engine,
                                                          appID: profile.pushAppID) { payload in
                let push = IncomingPush(payload, caller: profileType.caller(in: payload))
                try await calls.reportIncomingCallFromPush(uuid: push.uuid, remoteURI: push.uri,
                                                           displayName: push.name, hasVideo: push.video)
            }
        } else {
            BaresipPushKitAdapter(engine: engine, appID: profile.pushAppID) { payload in
                let push = IncomingPush(payload, caller: profileType.caller(in: payload))
                try CallModel.pushArrived(on: callKit, uuid: push.uuid, from: push.uri, displayName: push.name,
                                          video: push.video)
            }
        }
        adapter.setErrorHandler { [weak self] step, error in
            Task { @MainActor [weak self] in
                self?.append("push: \(step) failed: \(error)")
            }
        }
        push = adapter
    }

    func restartEngine() async {
        append("certificates or engine settings changed, restarting the engine")
        if let engine {
            if let accountID {
                try? await engine.unregister(accountID: accountID)
            }
            await engine.stop()
        }
        networkMonitor?.stop()
        networkMonitor = nil
        lifecycle?.stop()
        lifecycle = nil
        eventTask?.cancel()
        eventTask = nil
        phoneTask?.cancel()
        phoneTask = nil
        phone = nil
        accountID = nil
        push = nil
        callKit = nil
        liveCommunication = nil
        systemCalls = nil
        engineCallScreen = nil
        audio = nil
        engine = nil
        registration = .none
        await startEngine()
    }

    func readSecurityScoped(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else {
            throw BaresipCertificateError.unreadable
        }
        return data
    }

    /// The APNs token for regular notifications; sent with the VoIP token in `pn-tok`.
    func remoteTokenArrived(_ token: Data) {
        remoteToken = token
        push?.updateRemoteToken(token)
        append("APNs token received")
    }

    /// The INVITE header with the UUID that the server also puts in the VoIP push as `uuid`.
    nonisolated static let callUUIDHeader = "X-Call-UUID"

    nonisolated static func pushArrived(on callKit: BaresipCallKitAdapter?, uuid: UUID?, from: String?,
                                        displayName: String?, video: Bool) throws {
        guard let callKit else { throw CancellationError() }
        callKit.reportIncomingCallFromPush(uuid: uuid, remoteURI: from, displayName: displayName,
                                           hasVideo: video) { _ in }
    }
}

/// What the sample reads from a VoIP push payload.
struct IncomingPush {
    let uuid: UUID?
    let uri: String?
    let name: String?
    let video: Bool

    init(_ payload: [AnyHashable: Any], caller: (uri: String?, name: String?)) {
        uuid = (payload["uuid"] as? String).flatMap(UUID.init(uuidString:))
        uri = caller.uri
        name = caller.name
        video = payload["video"] as? Bool ?? false
    }
}
