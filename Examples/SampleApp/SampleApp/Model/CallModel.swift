import Combine
import Foundation
import SwiftUI
import BaresipKit
import BaresipKitAudio
import BaresipKitCallKit
import BaresipKitLiveCommunication
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
    static let shared = CallModel()

    @Published var settings = SettingsStore.load() {
        didSet {
            if settings != oldValue {
                SettingsStore.save(settings)
                lifecycle?.backgroundBehavior = backgroundBehavior
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

    @Published var doors = SettingsStore.doors {
        didSet {
            if doors != oldValue {
                SettingsStore.doors = doors
                ZvonoShortcuts.updateAppShortcutParameters()
            }
        }
    }

    @Published var contacts = SettingsStore.contacts {
        didSet {
            if contacts != oldValue {
                SettingsStore.contacts = contacts
            }
        }
    }

    @Published var ringtone = SettingsStore.ringtone {
        didSet {
            if ringtone != oldValue {
                SettingsStore.ringtone = ringtone
                callKit?.setRingtoneSound(ringtone.soundFile)
                if engineCallScreen == .liveCommunicationKit {
                    Task { await applyCallScreen() }
                }
            }
        }
    }

    /// The system call screen chosen in Settings; it takes effect when no call runs.
    @Published var callScreen = SettingsStore.callScreen {
        didSet {
            if callScreen != oldValue {
                SettingsStore.callScreen = callScreen
                Task { await applyCallScreen() }
            }
        }
    }

    @Published var tab: AppTab = .doors
    @Published var destination = ""
    @Published var registration: BaresipRegistrationState = .none
    @Published var registrationError: String?
    /// Whether the incoming call's early media preview shows video.
    @Published var previewVideo = false
    /// Whether the incoming call is previewed, by the app or by early media the account answers.
    @Published var previewing = false
    @Published var incomingEarlyVideo = false
    /// The ringing call's video on its way to the screen and to the pictures saved of it.
    @Published var previewFeed: CallPreviewFeed?
    /// Whether a picture of the ringing call was saved.
    var previewPictureReady = false
    /// The ringing call whose notification is shown.
    var previewNotified: BaresipCallID?
    /// The ringing call the user opened from the call list, shown instead of the first one.
    @Published var shownIncoming: BaresipCallID?
    @Published var log: [String] = []
    @Published var stats: BaresipCallStatistics?
    @Published var callMinimized = false
    @Published var recordingCall: BaresipCallID?
    @Published var lastRecording: URL?
    /// DTMF waiting for the outgoing call placed to send it.
    @Published var pendingDTMF: DTMFRequest?
    /// A call asked for from the Recents list that waits for the registration.
    var pendingRedial: BaresipRedialRequest?
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
    /// The messages of the call's other side shown over the call screen, oldest first.
    @Published var captions: [CallCaption] = []
    /// The other side whose chat is open over the call screen, as a SIP URI.
    @Published var showCallChat: String?
    /// The user whose thread is on screen; its messages arrive read and without a caption.
    var openChatPeer: String?
    var earlyStatuses: [BaresipMessageID: ChatMessage.Status] = [:]

    var engine: BaresipEngine?
    var accountID: BaresipAccountID?
    var audio: BaresipAudioSessionController?
    var callKit: BaresipCallKitAdapter?
    /// The LiveCommunicationKit adapter. Its type needs iOS 17.4, so it is kept untyped.
    var liveCommunication: AnyObject?
    /// The adapter of the system call screen in use, which takes the call actions; `nil` when
    /// calls go to the engine directly.
    var systemCalls: BaresipCallController?
    /// The call screen and the ringtone the running adapter was created with.
    var engineCallScreen: SystemCallScreen?
    var engineRingtone: Ringtone?
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
    /// Whether answering sends the camera, as configured for the system call screen.
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
    /// Calls whose audio was put on the loudspeaker when their media started.
    var loudspeakerCalls: Set<BaresipCallID> = []
    /// Calls whose audio output the user chose: the proximity sensor leaves them alone.
    var manualOutputCalls: Set<BaresipCallID> = []
    var proximityObserver: NSObjectProtocol?
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
        ZvonoShortcuts.updateAppShortcutParameters()
        #if DEBUG
            if uiTest {
                prepareUITest()
                seedDemo()
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
            doors = []
            contacts = []
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
