import Foundation
import Network
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitPushKit

extension CallModel {
    func startEngine() async {
        do {
            var config = BaresipConfiguration()
            config.userAgent = "BaresipKitSample/1.0"
            config.logLevel = .info
            if uiTest {
                config.modules += ["ausine", "aufile"]
                config.audio = BaresipAudioConfiguration(sourceModule: "ausine", playerModule: "aufile",
                                                         playerDevice: NSTemporaryDirectory() + "speaker.wav")
            }
            let tls = savedTLS
            config.tls = BaresipTLSConfiguration(caCertificatesPEM: tls.ca,
                                                 clientCertificatePEM: tls.client,
                                                 pinnedSPKISHA256: tls.pins)
            let engine = try BaresipEngine(configuration: config)
            engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.BaresipKitSample"))
            self.engine = engine
            engineTLS = tls
            eventTask = Task { [weak self] in
                for await event in engine.events {
                    await self?.handle(event)
                }
            }
            try await engine.start()
            audio = BaresipAudioSessionController(engine: engine)
            try audio?.configureForVoIP()
            callKit = BaresipCallKitAdapter(engine: engine,
                                            configuration: BaresipCallKitConfiguration(supportsVideo: true))
            push = BaresipPushKitAdapter(engine: engine, appID: "com.example.BaresipKitSample") { [weak self] payload in
                guard let self else { throw CancellationError() }
                try await self.pushArrived(payload)
            }
            append("engine started, core \(BaresipEngine.coreVersion), CA \(tls.ca == nil ? "system" : "custom"), client certificate \(tls.client == nil ? "none" : "set"), pins \(tls.pins.count)")
        } catch {
            append("engine start failed: \(error)")
        }
    }

    func restartEngine() async {
        append("certificates changed, restarting the engine")
        if let engine {
            if let accountID {
                try? await engine.unregister(accountID: accountID)
            }
            await engine.stop()
        }
        eventTask?.cancel()
        eventTask = nil
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
            throw CertificateError.unreadable
        }
        return data
    }

    func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let summary = path.availableInterfaces.map { "\($0.type)" }.joined(separator: ",")
                + (path.status == .satisfied ? "" : " unsatisfied")
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                await self?.pathChanged(summary, satisfied: satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.example.BaresipKitSample.path"))
        pathMonitor = monitor
    }

    func pathChanged(_ summary: String, satisfied: Bool) async {
        defer { lastPath = summary }
        guard let lastPath, lastPath != summary, satisfied, let engine else { return }
        append("network path changed: \(summary)")
        await engine.networkDidChange()
    }

    func pushArrived(_ payload: [AnyHashable: Any]) async throws {
        guard let callKit else { throw CancellationError() }
        let from = payload["from"] as? String
        try await callKit.reportIncomingCallFromPush(uuid: UUID(), remoteURI: from, displayName: from,
                                                     hasVideo: payload["video"] as? Bool ?? false)
    }
}
