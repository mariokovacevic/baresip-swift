import Foundation
import SwiftUI
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitPushKit

@MainActor
final class CallModel: ObservableObject {
    @Published var aor = "sip:1001@pbx.example.invalid"
    @Published var registrar = "sip:pbx.example.invalid:5061;transport=tls"
    @Published var authUser = "1001"
    @Published var password = ""
    @Published var destination = "sip:door@192.0.2.10"
    @Published var registration: BaresipRegistrationState = .none
    @Published var callState: BaresipCallState?
    @Published var currentCall: BaresipCallID?
    @Published var incoming: BaresipCallInfo?
    @Published var muted = false
    @Published var onHold = false
    @Published var videoEnabled = false
    @Published var log: [String] = []
    @Published var stats: BaresipCallStatistics?

    private(set) var engine: BaresipEngine?
    private var accountID: BaresipAccountID?
    private var audio: BaresipAudioSessionController?
    private var callKit: BaresipCallKitAdapter?
    private var push: BaresipPushKitAdapter?
    private var eventTask: Task<Void, Never>?

    func start() async {
        guard engine == nil else { return }
        do {
            var config = BaresipConfiguration()
            config.userAgent = "BaresipKitSample/1.0"
            config.logLevel = .info
            let engine = try BaresipEngine(configuration: config)
            engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.BaresipKitSample"))
            self.engine = engine
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
            append("engine started, core \(BaresipEngine.coreVersion)")
        } catch {
            append("start failed: \(error)")
        }
    }

    func register() async {
        guard let engine else { return }
        do {
            if let accountID {
                try await engine.removeAccount(accountID)
            }
            let account = BaresipAccountConfiguration(aor: aor, registrar: registrar, transport: .tls,
                                                      authUser: authUser, authPassword: password,
                                                      mediaEncryption: .srtpOptional)
            let id = try await engine.addAccount(account)
            accountID = id
            push?.bind(accountID: id)
            try await engine.register(accountID: id)
        } catch {
            append("register failed: \(error)")
        }
    }

    func call(video: Bool) async {
        guard let callKit else { return }
        do {
            _ = try await callKit.startOutgoingCall(to: destination, video: video)
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

    func toggleSpeaker(_ on: Bool) {
        try? audio?.setSpeakerEnabled(on)
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
            if state == .released {
                if currentCall == call {
                    currentCall = nil
                    callState = nil
                    stats = nil
                    onHold = false
                    muted = false
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
