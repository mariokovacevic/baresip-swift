import Foundation
import Network
import SwiftUI
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitPushKit

private struct TLSSnapshot: Equatable {
    let ca: Data?
    let client: Data?
    let pins: [String]
}

@MainActor
final class CallModel: ObservableObject {
    @Published var settings = SettingsStore.load()
    @Published var password = SettingsStore.password
    @Published var turnPassword = SettingsStore.turnPassword
    @Published var caCertificates = SettingsStore.caCertificates
    @Published var clientCertificate = SettingsStore.clientCertificate
    @Published var destination = ""
    @Published var registration: BaresipRegistrationState = .none
    @Published var registrationError: String?
    @Published var callState: BaresipCallState?
    @Published var currentCall: BaresipCallID?
    @Published var incoming: BaresipCallInfo?
    @Published var muted = false
    @Published var onHold = false
    @Published var videoEnabled = false
    @Published var frontCamera = true
    @Published var log: [String] = []
    @Published var stats: BaresipCallStatistics?

    private(set) var engine: BaresipEngine?
    private var accountID: BaresipAccountID?
    private var audio: BaresipAudioSessionController?
    private var callKit: BaresipCallKitAdapter?
    private var push: BaresipPushKitAdapter?
    private var eventTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var lastPath: String?
    private var engineTLS: TLSSnapshot?

    var caSummaries: [String] { PEM.summaries(caCertificates) }
    var clientSummaries: [String] { PEM.summaries(clientCertificate) }

    func start() async {
        guard engine == nil else { return }
        startPathMonitor()
        await startEngine()
        if settings.isComplete && !password.isEmpty {
            await register()
        }
    }

    func importCA(from url: URL) {
        do {
            let data = try readSecurityScoped(url)
            caCertificates = try PEM.caBundle(from: data)
            append("CA imported: \(caSummaries.joined(separator: ", "))")
        } catch {
            append("CA import failed: \(error.localizedDescription)")
        }
    }

    func importClientCertificate(from url: URL) {
        do {
            let data = try readSecurityScoped(url)
            clientCertificate = try PEM.clientIdentity(from: data)
            append("client certificate imported: \(clientSummaries.first ?? "")")
        } catch {
            append("client certificate import failed: \(error.localizedDescription)")
        }
    }

    func removeCA() {
        caCertificates = nil
    }

    func removeClientCertificate() {
        clientCertificate = nil
    }

    func saveAndRegister() async {
        SettingsStore.save(settings)
        SettingsStore.password = password
        SettingsStore.turnPassword = turnPassword
        SettingsStore.caCertificates = caCertificates
        SettingsStore.clientCertificate = clientCertificate
        if currentTLS != engineTLS {
            if currentCall != nil {
                append("certificates changed; they apply after the current call")
            } else {
                await restartEngine()
            }
        }
        await register()
    }

    func register() async {
        guard let engine else { return }
        guard settings.isComplete else {
            registrationError = "Domain and username are required."
            return
        }
        registrationError = nil
        do {
            if let accountID {
                try? await engine.unregister(accountID: accountID)
                try await engine.removeAccount(accountID)
                self.accountID = nil
            }
            let id = try await engine.addAccount(accountConfiguration())
            accountID = id
            push?.bind(accountID: id)
            try await engine.register(accountID: id)
            append("registering \(settings.aor) via \(settings.registrar)")
        } catch {
            registrationError = "\(error)"
            append("register failed: \(error)")
        }
    }

    func unregister() async {
        guard let engine, let accountID else { return }
        try? await engine.unregister(accountID: accountID)
    }

    func call(video: Bool) async {
        guard let callKit else { return }
        let target = normalizedDestination(destination)
        guard !target.isEmpty else { return }
        do {
            _ = try await callKit.startOutgoingCall(to: target, video: video)
            videoEnabled = video
        } catch {
            append("call failed: \(error)")
        }
    }

    func answer() async {
        guard let engine, let incoming else { return }
        try? await engine.answer(callID: incoming.id, video: incoming.hasVideo)
        videoEnabled = incoming.hasVideo
        self.incoming = nil
    }

    func reject() async {
        guard let engine, let incoming else { return }
        try? await engine.reject(callID: incoming.id, statusCode: 486)
        self.incoming = nil
    }

    func hangup() async {
        guard let engine, let currentCall else { return }
        try? await engine.hangup(callID: currentCall)
    }

    func toggleHold() async {
        guard let engine, let currentCall else { return }
        if onHold {
            try? await engine.resume(callID: currentCall)
        } else {
            try? await engine.hold(callID: currentCall)
        }
        onHold.toggle()
    }

    func toggleMute() async {
        guard let engine, let currentCall else { return }
        muted.toggle()
        try? await engine.setMicrophoneMuted(muted, callID: currentCall)
    }

    func toggleVideo() async {
        guard let engine, let currentCall else { return }
        videoEnabled.toggle()
        try? await engine.setVideoEnabled(videoEnabled, callID: currentCall)
    }

    func sendDTMF(_ digits: String) async {
        guard let engine, let currentCall else { return }
        try? await engine.sendDTMF(callID: currentCall, digits: digits)
    }

    func switchCamera() async {
        guard let engine, let currentCall else { return }
        frontCamera.toggle()
        do {
            try await engine.setCamera(frontCamera ? "front" : "back", callID: currentCall)
        } catch {
            append("camera switch failed: \(error)")
        }
    }

    func restartICE() async {
        guard let engine, let currentCall else { return }
        do {
            try await engine.restartICE(callID: currentCall)
        } catch {
            append("ICE restart failed: \(error)")
        }
    }

    func toggleSpeaker(_ on: Bool) {
        try? audio?.setSpeakerEnabled(on)
    }

    private var currentTLS: TLSSnapshot {
        TLSSnapshot(ca: caCertificates, client: clientCertificate, pins: settings.pinList)
    }

    private func accountConfiguration() -> BaresipAccountConfiguration {
        var nat = BaresipNATConfiguration()
        if settings.useICE {
            nat.mode = .ice
            if !settings.stunURI.trimmed.isEmpty {
                nat.stunURI = settings.stunURI.trimmed
            }
            if !settings.turnURI.trimmed.isEmpty {
                nat.turnServers = [TURNServer(uri: settings.turnURI.trimmed,
                                              username: settings.turnUser.trimmed.isEmpty ? nil : settings.turnUser.trimmed,
                                              password: turnPassword.isEmpty ? nil : turnPassword)]
            }
        }
        let authUser = settings.authUser.trimmed.isEmpty ? settings.username.trimmed : settings.authUser.trimmed
        return BaresipAccountConfiguration(aor: settings.aor,
                                           displayName: settings.displayName.trimmed.isEmpty ? nil : settings.displayName.trimmed,
                                           registrar: settings.registrar,
                                           outboundProxy: settings.proxy,
                                           transport: settings.transport,
                                           authUser: authUser,
                                           authPassword: password,
                                           mediaEncryption: settings.mediaEncryption,
                                           nat: nat)
    }

    private func normalizedDestination(_ raw: String) -> String {
        let value = raw.trimmed
        if value.isEmpty || value.hasPrefix("sip:") || value.hasPrefix("sips:") {
            return value
        }
        if value.contains("@") {
            return "sip:\(value)"
        }
        return "sip:\(value)@\(settings.domain.trimmed)"
    }

    private func startEngine() async {
        do {
            var config = BaresipConfiguration()
            config.userAgent = "BaresipKitSample/1.0"
            config.logLevel = .info
            config.tls = BaresipTLSConfiguration(caCertificatesPEM: caCertificates,
                                                 clientCertificatePEM: clientCertificate,
                                                 pinnedSPKISHA256: settings.pinList)
            let engine = try BaresipEngine(configuration: config)
            engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.BaresipKitSample"))
            self.engine = engine
            engineTLS = currentTLS
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
                await self?.pushArrived(payload)
            }
            append("engine started, core \(BaresipEngine.coreVersion), CA \(caCertificates == nil ? "system" : "custom"), client certificate \(clientCertificate == nil ? "none" : "set"), pins \(settings.pinList.count)")
        } catch {
            append("engine start failed: \(error)")
        }
    }

    private func restartEngine() async {
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

    private func readSecurityScoped(_ url: URL) throws -> Data {
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

    private func startPathMonitor() {
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

    private func pathChanged(_ summary: String, satisfied: Bool) async {
        defer { lastPath = summary }
        guard let lastPath, lastPath != summary, satisfied, let engine else { return }
        append("network path changed: \(summary)")
        await engine.networkDidChange()
    }

    private func pushArrived(_ payload: [AnyHashable: Any]) async {
        let from = payload["from"] as? String
        try? await callKit?.reportIncomingCallFromPush(uuid: UUID(), remoteURI: from, displayName: from,
                                                       hasVideo: payload["video"] as? Bool ?? false)
    }

    private func handle(_ event: BaresipEvent) async {
        switch event {
        case .engine(let state, let error):
            append("engine \(state) \(error.map { "\($0)" } ?? "")")
        case .registration(_, let state, _, let error):
            registration = state
            registrationError = error.map { "\($0)" }
            append("registration \(state) \(error.map { "\($0)" } ?? "")")
        case .incomingCall(let info, _):
            incoming = info
            currentCall = info.id
            append("incoming call from \(info.remoteURI)")
        case .call(let call, let state, let error):
            callState = state
            append("call \(call) \(state) \(error.map { "\($0)" } ?? "")")
            if state == .outgoingInit {
                currentCall = call
            }
            if state == .released, currentCall == call {
                currentCall = nil
                callState = nil
                stats = nil
                onHold = false
                muted = false
                videoEnabled = false
                if currentTLS != engineTLS {
                    Task { [weak self] in
                        await self?.restartEngine()
                        await self?.register()
                    }
                }
            }
        case .statistics(_, let s):
            stats = s
        case .ice(_, let ice):
            append("ice \(ice.state) \(ice.localCandidate)/\(ice.remoteCandidate) \(ice.remoteAddress)")
        case .dtmf(_, let dtmf):
            if !dtmf.isEnd {
                append("dtmf \(dtmf.digit)")
            }
        default:
            break
        }
    }

    private func append(_ line: String) {
        log.append(line)
        if log.count > 200 {
            log.removeFirst(log.count - 200)
        }
    }
}
