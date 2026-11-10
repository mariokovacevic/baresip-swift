import Combine
import Foundation
import SwiftUI
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitPushKit
import BaresipKitSwiftUI

struct TLSSnapshot: Equatable {
    let ca: Data?
    let client: Data?
    let pins: [String]
    var verifyServer = true
}

@MainActor
final class CallModel: ObservableObject {
    @Published var settings = SettingsStore.load() {
        didSet {
            if settings != oldValue {
                SettingsStore.save(settings)
            }
        }
    }

    @Published var password = SettingsStore.password {
        didSet {
            if password != oldValue {
                SettingsStore.password = password
            }
        }
    }

    @Published var turnPassword = SettingsStore.turnPassword {
        didSet {
            if turnPassword != oldValue {
                SettingsStore.turnPassword = turnPassword
            }
        }
    }

    @Published var caCertificates = SettingsStore.caCertificates {
        didSet {
            if let caCertificates, caCertificates != oldValue {
                SettingsStore.storeCACertificates(caCertificates)
            }
        }
    }

    @Published var clientCertificate = SettingsStore.clientCertificate {
        didSet {
            if let clientCertificate, clientCertificate != oldValue {
                SettingsStore.storeClientCertificate(clientCertificate)
            }
        }
    }

    @Published var logsSIPMessages = SettingsStore.logsSIPMessages {
        didSet {
            if logsSIPMessages != oldValue {
                SettingsStore.logsSIPMessages = logsSIPMessages
            }
        }
    }

    @Published var destination = ""
    @Published var registration: BaresipRegistrationState = .none
    @Published var registrationError: String?
    /// Whether the incoming call's early media preview shows video.
    @Published var previewVideo = false
    /// Whether the incoming call is previewed, by the app or by early media the account answers.
    @Published var previewing = false
    @Published var incomingEarlyVideo = false
    /// The ringing call the user opened from the call list, shown instead of the first one.
    @Published var shownIncoming: BaresipCallID?
    @Published var log: [String] = []
    @Published var stats: BaresipCallStatistics?
    @Published var callMinimized = false
    @Published var recordingCall: BaresipCallID?
    @Published var lastRecording: URL?
    /// DTMF waiting for the outgoing call placed to send it.
    @Published var pendingDTMF: DTMFRequest?
    /// DTMF sent or to send per call.
    @Published var dtmfStates: [BaresipCallID: DTMFState] = [:]
    /// Bumped on every audio route change so views showing the output refresh.
    @Published var audioRouteChanges = 0
    @Published var history = SettingsStore.history {
        didSet {
            SettingsStore.history = history
            snapshots.prune(keeping: Set(history.compactMap(\.snapshotFile)))
        }
    }

    @Published var transferTarget = ""
    @Published var messages: [ChatMessage] = []
    @Published var messageTo = ""
    @Published var messageText = ""
    var earlyStatuses: [BaresipMessageID: ChatMessage.Status] = [:]

    var engine: BaresipEngine?
    var accountID: BaresipAccountID?
    var audio: BaresipAudioSessionController?
    var callKit: BaresipCallKitAdapter?
    let snapshots = CallSnapshots()
    var push: BaresipPushKitAdapter? {
        didSet {
            if let remoteToken {
                push?.updateRemoteToken(remoteToken)
            }
        }
    }

    var remoteToken: Data?
    let profile = AppProfiles.current
    /// Whether answering sends the camera, as configured for CallKit.
    var answerWithCamera = true
    var eventTask: Task<Void, Never>?
    /// Registrations and calls, kept by `BaresipKitSwiftUI`. The call screens read their state
    /// from it; its changes and its calls' changes are passed on as changes of this model.
    @Published var phone: BaresipPhone? {
        didSet { observe(phone) }
    }

    var phoneTask: Task<Void, Never>?
    var phoneObservers: Set<AnyCancellable> = []
    var callObservers: [BaresipCallID: AnyCancellable] = [:]
    /// The calls seen, kept after they end until the app is done with them.
    var knownCalls: [BaresipCallID: BaresipPhoneCall] = [:]
    /// Incoming calls whose answer the app already handled.
    var answeredCalls: Set<BaresipCallID> = []
    /// Incoming calls not answered yet, from the engine's events.
    var ringingCalls: Set<BaresipCallID> = []
    var networkMonitor: BaresipNetworkMonitor?
    var lifecycle: BaresipAppLifecycle?
    var lastNetworkPath: String?
    var engineTLS: TLSSnapshot?
    var engineOptions: EngineOptions?
    var pendingApply = false
    var registeredSettings: SIPSettings?
    var previewAudioActive = false
    #if DEBUG
        let uiTest = ProcessInfo.processInfo.environment["BSK_UITEST"] == "1"
    #else
        let uiTest = false
    #endif

    var caSummaries: [String] {
        BaresipCertificates.summaries(caCertificates)
    }

    var clientSummaries: [String] {
        BaresipCertificates.summaries(clientCertificate)
    }

    func start() async {
        guard engine == nil else { return }
        #if DEBUG
            if uiTest {
                prepareUITest()
            }
        #endif
        await startEngine()
        if settings.isComplete, !password.isEmpty {
            await register()
        }
    }

    #if DEBUG
        func prepareUITest() {
            settings = SIPSettings()
            password = ""
            turnPassword = ""
            history = []
            removeClientCertificate()
            removeCA()
            if let pem = ProcessInfo.processInfo.environment["BSK_UITEST_CA_PEM"] {
                caCertificates = try? BaresipCertificates.caBundle(from: Data(pem.utf8))
            }
        }
    #endif

    func append(_ line: String) {
        FileLog.shared.write(line)
        log.append(line)
        if log.count > 200 {
            log.removeFirst(log.count - 200)
        }
    }
}
