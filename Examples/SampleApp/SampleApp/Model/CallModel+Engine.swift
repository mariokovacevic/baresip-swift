import Foundation
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitPushKit
import BaresipKitSwiftUI

extension CallModel {
    func startEngine() async {
        do {
            var config = BaresipConfiguration()
            config.userAgent = "BaresipKitSample/1.0"
            config.logLevel = .info
            config.logSIPTrace = logsSIPMessages
            if uiTest {
                config.modules += ["ausine", "aufile"]
                config.audio = BaresipAudioConfiguration(sourceModule: "ausine", playerModule: "aufile",
                                                         playerDevice: NSTemporaryDirectory() + "speaker.wav")
            }
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
            startCallKit(engine: engine)
            // CallKit takes the call actions on a device, so the system call screen stays in step.
            let phone = BaresipPhone(engine: engine, callController: usesDirectCalls ? nil : callKit)
            self.phone = phone
            phoneTask = Task { await phone.run() }
            startPushKit(engine: engine)
            try await engine.start()
            startNetworkMonitor(engine: engine)
            startLifecycle(engine: engine)
            audio = BaresipAudioSessionController(engine: engine) { [weak self] _ in
                self?.audioRouteChanges += 1
            }
            try audio?.configureForVoIP()
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

    private func startCallKit(engine: BaresipEngine) {
        var callKitConfiguration = BaresipCallKitConfiguration(supportsVideo: true)
        profile.configure(&callKitConfiguration)
        answerWithCamera = callKitConfiguration.sendsCameraOnAnswer
        callKit = BaresipCallKitAdapter(engine: engine, configuration: callKitConfiguration)
    }

    /// Goes offline in the background when no call runs, online again when the app is active,
    /// and unregisters when the app terminates.
    private func startLifecycle(engine: BaresipEngine) {
        let lifecycle = BaresipAppLifecycle(engine: engine)
        lifecycle.backgroundBehavior = .goOffline
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
        let adapter = BaresipPushKitAdapter(engine: engine, appID: profile.pushAppID) { payload in
            let caller = profileType.caller(in: payload)
            let video = payload["video"] as? Bool ?? false
            try CallModel.pushArrived(on: callKit, from: caller.uri, displayName: caller.name, video: video)
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

    nonisolated static func pushArrived(on callKit: BaresipCallKitAdapter?, from: String?, displayName: String?,
                                        video: Bool) throws {
        guard let callKit else { throw CancellationError() }
        callKit.reportIncomingCallFromPush(uuid: UUID(), remoteURI: from, displayName: displayName,
                                           hasVideo: video) { _ in }
    }
}
