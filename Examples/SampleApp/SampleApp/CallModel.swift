import Foundation
import Network
import SwiftUI
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitPushKit

struct TLSSnapshot: Equatable {
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
    @Published var previewVideo = false
    var pendingOutgoingVideo = false
    @Published var frontCamera = true
    @Published var previewing = false
    @Published var incomingEarlyVideo = false
    @Published var log: [String] = []
    @Published var stats: BaresipCallStatistics?
    @Published var heldCall: BaresipCallID?
    @Published var callMinimized = false
    @Published var recordingCall: BaresipCallID?
    @Published var lastRecording: URL?
    @Published var calls: [CallRow] = []
    @Published var transferTarget = ""
    @Published var messages: [ChatMessage] = []
    @Published var messageTo = ""
    @Published var messageText = ""
    var earlyStatuses: [BaresipMessageID: ChatMessage.Status] = [:]

    var engine: BaresipEngine?
    var accountID: BaresipAccountID?
    var audio: BaresipAudioSessionController?
    var callKit: BaresipCallKitAdapter?
    var push: BaresipPushKitAdapter?
    var eventTask: Task<Void, Never>?
    var pathMonitor: NWPathMonitor?
    var lastPath: String?
    var engineTLS: TLSSnapshot?
    var pendingApply = false
    var registeredSettings: SIPSettings?
    var previewAudioActive = false
    let uiTest = ProcessInfo.processInfo.environment["BSK_UITEST"] == "1"

    var caSummaries: [String] {
        PEM.summaries(caCertificates)
    }

    var clientSummaries: [String] {
        PEM.summaries(clientCertificate)
    }

    func start() async {
        guard engine == nil else { return }
        if uiTest {
            prepareUITest()
        }
        startPathMonitor()
        await startEngine()
        if settings.isComplete, !password.isEmpty {
            await register()
        }
    }

    func prepareUITest() {
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

    func append(_ line: String) {
        log.append(line)
        if log.count > 200 {
            log.removeFirst(log.count - 200)
        }
    }
}
