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
    @Published var previewing = false
    @Published var incomingEarlyVideo = false
    @Published var log: [String] = []
    @Published var stats: BaresipCallStatistics?
    @Published var heldCall: BaresipCallID?
    @Published var calls: [CallRow] = []
    @Published var transferTarget = ""
    @Published var messages: [ChatMessage] = []
    @Published var messageTo = ""
    @Published var messageText = ""
    private var earlyStatuses: [BaresipMessageID: ChatMessage.Status] = [:]

    private(set) var engine: BaresipEngine?
    private var accountID: BaresipAccountID?
    private var audio: BaresipAudioSessionController?
    private var callKit: BaresipCallKitAdapter?
    private var push: BaresipPushKitAdapter?
    private var eventTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var lastPath: String?
    private var engineTLS: TLSSnapshot?
    private var pendingApply = false
    private var registeredSettings: SIPSettings?
    private var previewAudioActive = false
    private let uiTest = ProcessInfo.processInfo.environment["BSK_UITEST"] == "1"

    var caSummaries: [String] { PEM.summaries(caCertificates) }
    var clientSummaries: [String] { PEM.summaries(clientCertificate) }

    func start() async {
        guard engine == nil else { return }
        if uiTest {
            prepareUITest()
        }
        startPathMonitor()
        await startEngine()
        if settings.isComplete && !password.isEmpty {
            await register()
        }
    }

    private func prepareUITest() {
        settings = SIPSettings()
        password = ""
        turnPassword = ""
        clientCertificate = nil
        caCertificates = nil
        if let pem = ProcessInfo.processInfo.environment["BSK_UITEST_CA_PEM"] {
            caCertificates = try? PEM.caBundle(from: Data(pem.utf8))
        }
        SettingsStore.save(settings)
        SettingsStore.password = ""
        SettingsStore.turnPassword = ""
        SettingsStore.caCertificates = caCertificates
        SettingsStore.clientCertificate = nil
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
        if currentCall != nil {
            pendingApply = true
            append("settings saved; they apply after the current call")
            return
        }
        await applySaved()
    }

    private func applySaved() async {
        if savedTLS != engineTLS {
            await restartEngine()
        }
        await register()
    }

    func register() async {
        guard let engine else { return }
        let saved = SettingsStore.load()
        guard saved.isComplete else {
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
            let id = try await engine.addAccount(accountConfiguration(saved, password: SettingsStore.password,
                                                                      turnPassword: SettingsStore.turnPassword))
            accountID = id
            registeredSettings = saved
            push?.bind(accountID: id)
            try await engine.register(accountID: id)
            append("registering \(saved.aor) via \(saved.registrar)")
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
        let target = normalizedDestination(destination)
        guard !target.isEmpty else { return }
        if uiTest, let engine {
            do {
                _ = try await engine.makeCall(accountID: accountID, destination: target, video: video)
                videoEnabled = video
            } catch {
                append("call failed: \(error)")
            }
            return
        }
        guard let callKit else { return }
        do {
            _ = try await callKit.startOutgoingCall(to: target, video: video)
            videoEnabled = video
        } catch {
            append("call failed: \(error)")
        }
    }

    func preview() async {
        guard let engine, let incoming, !previewing else { return }
        let video = incoming.hasVideo || incomingEarlyVideo
        do {
            await activatePreviewAudio()
            try await engine.sendProgress(callID: incoming.id, earlyVideo: video)
            previewing = true
            videoEnabled = video
            append("previewing \(incoming.remoteURI) (they do not hear or see you)")
        } catch {
            append("preview failed: \(error)")
        }
    }

    private func activatePreviewAudio() async {
        guard !previewAudioActive, let audio else { return }
        do {
            try await audio.activate()
            previewAudioActive = true
        } catch {
            append("audio for preview unavailable: \(error)")
        }
    }

    func answer() async {
        guard let engine, let incoming else { return }
        let others = calls.contains { $0.id != incoming.id }
        try? await engine.answer(callID: incoming.id, video: incoming.hasVideo)
        if others {
            try? await engine.setActiveCall(incoming.id)
        }
        currentCall = incoming.id
        callState = calls.first { $0.id == incoming.id }?.state
        onHold = false
        videoEnabled = incoming.hasVideo
        previewing = false
        self.incoming = nil
    }

    func switchTo(_ call: BaresipCallID) async {
        guard let engine else { return }
        do {
            try await engine.setActiveCall(call)
            currentCall = call
            callState = calls.first { $0.id == call }?.state
            onHold = false
            heldCall = nil
        } catch {
            append("switch failed: \(error)")
        }
    }

    func toggleHold(_ call: BaresipCallID) async {
        guard let engine, let row = calls.first(where: { $0.id == call }) else { return }
        let held = row.state == .paused || row.state == .pausing
        if held {
            try? await engine.resume(callID: call)
        } else {
            try? await engine.hold(callID: call)
        }
        if call == currentCall {
            onHold = !held
        }
    }

    func hangup(_ call: BaresipCallID) async {
        try? await engine?.hangup(callID: call)
    }

    private var currentCallOnHold: Bool {
        guard let currentCall, let row = calls.first(where: { $0.id == currentCall }) else { return false }
        return row.state == .paused || row.state == .pausing
    }

    private func updateRow(_ call: BaresipCallID, state: BaresipCallState) {
        if let index = calls.firstIndex(where: { $0.id == call }) {
            calls[index].state = state
            return
        }
        guard state != .released else { return }
        calls.append(CallRow(id: call, remote: "…", state: state, outgoing: state != .incoming))
        Task { [weak self] in
            guard let self, let engine = self.engine,
                  let info = try? await engine.callInfo(callID: call) else { return }
            if let index = self.calls.firstIndex(where: { $0.id == call }) {
                self.calls[index].remote = info.remoteDisplayName.isEmpty ? info.remoteURI : info.remoteDisplayName
                self.calls[index].outgoing = info.outgoing
            }
        }
    }

    private func callReleased(_ call: BaresipCallID) async {
        calls.removeAll { $0.id == call }
        if heldCall == call {
            heldCall = nil
        }
        if incoming?.id == call {
            incoming = nil
            previewing = false
        }
        guard call == currentCall else { return }
        if let next = heldCall ?? calls.first?.id {
            heldCall = nil
            currentCall = next
            callState = calls.first { $0.id == next }?.state
            if let engine {
                try? await engine.resume(callID: next)
            }
            onHold = false
            return
        }
        currentCall = nil
        callState = nil
        stats = nil
        onHold = false
        muted = false
        videoEnabled = false
        previewing = false
        if previewAudioActive {
            previewAudioActive = false
            await audio?.deactivate()
        }
        if pendingApply {
            pendingApply = false
            Task { [weak self] in
                await self?.applySaved()
            }
        }
    }

    func reject() async {
        guard let engine, let incoming else { return }
        try? await engine.reject(callID: incoming.id, statusCode: 486)
        previewing = false
        videoEnabled = false
        self.incoming = nil
    }

    func sendMessage() async {
        guard let engine else { return }
        let to = normalizedDestination(messageTo)
        let text = messageText
        guard !to.isEmpty, !text.isEmpty else { return }
        do {
            let id = try await engine.sendMessage(to: to, text: text, accountID: accountID)
            let status = earlyStatuses.removeValue(forKey: id) ?? .sending
            messages.append(ChatMessage(id: UUID(), messageID: id, peer: to, text: text, outgoing: true, status: status))
            messageText = ""
        } catch {
            messages.append(ChatMessage(id: UUID(), messageID: nil, peer: to, text: text, outgoing: true,
                                        status: .failed("\(error)")))
        }
    }

    func blindTransfer() async {
        guard let engine, let currentCall else { return }
        let target = normalizedDestination(transferTarget)
        guard !target.isEmpty else { return }
        do {
            try await engine.transfer(callID: currentCall, to: target)
            append("transferring \(currentCall) to \(target)")
        } catch {
            append("transfer failed: \(error)")
        }
    }

    func consult() async {
        guard let engine, let currentCall, heldCall == nil else { return }
        let target = normalizedDestination(transferTarget)
        guard !target.isEmpty else { return }
        do {
            try await engine.hold(callID: currentCall)
            heldCall = currentCall
            onHold = false
            _ = try await engine.makeCall(accountID: accountID, destination: target, video: false)
            append("consulting \(target) while \(currentCall) is on hold")
        } catch {
            append("consultation failed: \(error)")
        }
    }

    func completeTransfer() async {
        guard let engine, let heldCall, let currentCall, heldCall != currentCall else { return }
        do {
            try await engine.transferAttended(callID: heldCall, to: currentCall)
            append("attended transfer of \(heldCall) to \(currentCall)")
        } catch {
            append("attended transfer failed: \(error)")
        }
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

    private var savedTLS: TLSSnapshot {
        TLSSnapshot(ca: SettingsStore.caCertificates, client: SettingsStore.clientCertificate,
                    pins: SettingsStore.load().pinList)
    }

    private func accountConfiguration(_ settings: SIPSettings, password: String,
                                      turnPassword: String) -> BaresipAccountConfiguration {
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
                                           nat: nat,
                                           answerEarlyMedia: settings.autoPreview)
    }

    private func normalizedDestination(_ raw: String) -> String {
        let value = raw.trimmed
        if value.isEmpty || value.hasPrefix("sip:") || value.hasPrefix("sips:") {
            return value
        }
        if value.contains("@") {
            return "sip:\(value)"
        }
        return "sip:\(value)@\((registeredSettings ?? settings).domain.trimmed)"
    }

    private func startEngine() async {
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

    private func pushArrived(_ payload: [AnyHashable: Any]) async throws {
        guard let callKit else { throw CancellationError() }
        let from = payload["from"] as? String
        try await callKit.reportIncomingCallFromPush(uuid: UUID(), remoteURI: from, displayName: from,
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
        case .incomingCall(let info, let earlyVideo):
            incoming = info
            incomingEarlyVideo = earlyVideo
            if let index = calls.firstIndex(where: { $0.id == info.id }) {
                calls[index].remote = info.remoteDisplayName.isEmpty ? info.remoteURI : info.remoteDisplayName
            } else {
                calls.append(CallRow(id: info.id,
                                     remote: info.remoteDisplayName.isEmpty ? info.remoteURI : info.remoteDisplayName,
                                     state: .incoming, outgoing: false))
            }
            if currentCall == nil {
                currentCall = info.id
            }
            if registeredSettings?.autoPreview == true && !calls.contains(where: { $0.id != info.id }) {
                previewing = true
                videoEnabled = info.hasVideo || earlyVideo
                await activatePreviewAudio()
            }
            append("incoming call from \(info.remoteURI)\(earlyVideo ? " (early video offered)" : "")")
        case .call(let call, let state, let error):
            append("call \(call) \(state) \(error.map { "\($0)" } ?? "")")
            updateRow(call, state: state)
            if state == .outgoingInit && (currentCall == nil || heldCall != nil || currentCallOnHold) {
                currentCall = call
            }
            if call == currentCall {
                callState = state
                onHold = state == .paused || state == .pausing
            }
            if state == .released {
                await callReleased(call)
            }
        case .message(let message):
            messages.append(ChatMessage(id: UUID(), messageID: nil, peer: message.from,
                                        text: message.text ?? "<\(message.contentType), \(message.body.count) bytes>",
                                        outgoing: false, status: .received))
            append("message from \(message.from)")
        case .messageStatus(let status):
            let result: ChatMessage.Status = status.delivered ? .delivered
                : .failed(status.error.map { "\($0)" } ?? "\(status.sipStatus ?? 0)")
            if let index = messages.lastIndex(where: { $0.messageID == status.id }) {
                messages[index].status = result
            } else {
                earlyStatuses[status.id] = result
            }
        case .transfer(let call, let event):
            append("transfer \(call): \(event.failed ? "failed" : "requested") \(event.targetURI)")
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


struct ChatMessage: Identifiable, Equatable {
    enum Status: Equatable {
        case sending
        case delivered
        case failed(String)
        case received
    }

    let id: UUID
    let messageID: BaresipMessageID?
    let peer: String
    let text: String
    let outgoing: Bool
    var status: Status
}


struct CallRow: Identifiable, Equatable {
    let id: BaresipCallID
    var remote: String
    var state: BaresipCallState
    var outgoing: Bool
}
