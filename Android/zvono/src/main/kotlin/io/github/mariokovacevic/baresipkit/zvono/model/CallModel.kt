package io.github.mariokovacevic.baresipkit.zvono.model

import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.mariokovacevic.baresipkit.BaresipAccountID
import io.github.mariokovacevic.baresipkit.BaresipAppLifecycle
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallStatistics
import io.github.mariokovacevic.baresipkit.BaresipCertificates
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipFileLog
import io.github.mariokovacevic.baresipkit.BaresipMessageID
import io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.audio.BaresipAudioController
import io.github.mariokovacevic.baresipkit.compose.BaresipPhone
import io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall
import io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter
import io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest
import io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.time.TimeSource

class CallModel(
    val context: Context,
    val store: SettingsStore,
    val fileLog: BaresipFileLog,
    val system: CallSystem,
    val isDebugBuild: Boolean,
) : PushReceiver {
    val scope = MainScope()
    val profile: AppProfile = AppProfile.load { error -> Log.e("Zvono", "LocalAppProfile could not be loaded, using the default profile", error) }
    val navigator = Navigator()
    val snapshots = CallSnapshots(File(context.filesDir, "Snapshots"))

    var settings by mutableStateOf(store.settings)
        private set

    private var passwordState by mutableStateOf(store.password)
    var password: String
        get() = passwordState
        set(value) {
            if (value == passwordState) return
            passwordState = value
            store.password = value
        }

    private var turnPasswordState by mutableStateOf(store.turnPassword)
    var turnPassword: String
        get() = turnPasswordState
        set(value) {
            if (value == turnPasswordState) return
            turnPasswordState = value
            store.turnPassword = value
        }

    private var doorsState by mutableStateOf(store.doors)
    var doors: List<Door>
        get() = doorsState
        set(value) {
            if (value == doorsState) return
            doorsState = value
            store.doors = value
            system.updateDoorShortcuts(DoorShortcuts.of(value))
        }

    private var contactsState by mutableStateOf(store.contacts)
    var contacts: List<Contact>
        get() = contactsState
        set(value) {
            if (value == contactsState) return
            contactsState = value
            store.contacts = value
        }

    private var historyState by mutableStateOf(store.history)
    var history: List<CallRecord>
        get() = historyState
        set(value) {
            historyState = value.take(CallRecord.LIMIT)
            store.history = historyState
            snapshots.prune(historyState.mapNotNull { it.snapshotFile }.toSet())
        }

    private var ringtoneState by mutableStateOf(store.ringtone)
    var ringtone: Ringtone
        get() = ringtoneState
        set(value) {
            ringtoneState = value
            store.ringtone = value
        }

    private var logsSipMessagesState by mutableStateOf(store.logsSipMessages)
    var logsSipMessages: Boolean
        get() = logsSipMessagesState
        set(value) {
            logsSipMessagesState = value
            store.logsSipMessages = value
        }

    private var callIntegrationState by mutableStateOf(store.callIntegration)
    val callIntegration: CallIntegration
        get() = callIntegrationState

    fun chooseCallIntegration(value: CallIntegration) {
        if (value == callIntegrationState) return
        callIntegrationState = value
        store.callIntegration = value
        scope.launch { applyCallIntegration() }
    }

    var caCertificates by mutableStateOf(store.caCertificates)
    var clientIdentity by mutableStateOf(store.clientIdentity)

    var tab by mutableStateOf(AppTab.DOORS)
    var destination by mutableStateOf("")
    var pendingRedial: BaresipRedialRequest? = null
    var pendingRedialSince: TimeSource.Monotonic.ValueTimeMark? = null
    var registration by mutableStateOf(BaresipRegistrationState.NONE)
    var registrationError by mutableStateOf<String?>(null)
    var previewVideo by mutableStateOf(false)
    var previewing by mutableStateOf(false)
    var incomingEarlyVideo by mutableStateOf(false)
    var shownIncoming by mutableStateOf<BaresipCallID?>(null)
    val log = mutableStateListOf<String>()
    var stats by mutableStateOf<BaresipCallStatistics?>(null)
    var callMinimized by mutableStateOf(false)
    var recordingCall by mutableStateOf<BaresipCallID?>(null)
    var lastRecording by mutableStateOf<File?>(null)
    var pendingDtmf by mutableStateOf<DtmfRequest?>(null)
    val dtmfStates = mutableStateMapOf<BaresipCallID, DtmfState>()
    var audioRouteChanges by mutableIntStateOf(0)
    var transferTarget by mutableStateOf("")
    val messages = mutableStateListOf<ChatMessage>()
    var captions by mutableStateOf<List<CallCaption>>(emptyList())
    var showCallChat by mutableStateOf<String?>(null)
    var openChatPeer: String? = null
    val encryptedCalls = mutableStateMapOf<BaresipCallID, String>()
    var lastNetworkPath by mutableStateOf<String?>(null)
    var pushToken by mutableStateOf<String?>(null)
    var phone by mutableStateOf<BaresipPhone?>(null)
    var previewFeed by mutableStateOf<CallPreviewFeed?>(null)
    val ringNotice = RingNotice()
    val declinedCalls = HashSet<BaresipCallID>()
    var engineIntegration: CallIntegration? = null

    var demoMode by mutableStateOf(false)
    var demoIncoming by mutableStateOf<CallRow?>(null)
    var demoCall by mutableStateOf<CallRow?>(null)
    var demoDoorOpened by mutableStateOf(false)

    var engine: BaresipEngine? = null
    var accountId: BaresipAccountID? = null
    var audio: BaresipAudioController? = null
    var telecom: BaresipTelecomAdapter? = null
    var push: BaresipPushAdapter? = null
    var networkMonitor: BaresipNetworkMonitor? = null
    var lifecycle: BaresipAppLifecycle? = null
    var ownerCheck: OwnerCheck? = null
    var engineJobs: List<Job> = emptyList()
    var engineTls: TlsSnapshot? = null
    var engineOptions: EngineOptions? = null
    var engineLogsSipMessages = false
    var registeredSettings: SipSettings? = null
    var pendingApply = false
    var appAudioActive = false
    var started = false
    val earlyStatuses = HashMap<BaresipMessageID, ChatStatus>()
    val knownCalls = HashMap<BaresipCallID, BaresipPhoneCall>()
    val answeredCalls = HashSet<BaresipCallID>()
    val ringingCalls = HashSet<BaresipCallID>()
    val loudspeakerCalls = HashSet<BaresipCallID>()
    val manualOutputCalls = HashSet<BaresipCallID>()
    var nextCaptionId = 0L

    init {
        system.proximityListener = { near -> proximityChanged(near) }
        system.updateDoorShortcuts(DoorShortcuts.of(doorsState))
    }

    val caSummaries: List<String>
        get() = BaresipCertificates.summaries(caCertificates)

    val clientSummaries: List<String>
        get() = BaresipCertificates.summaries(clientIdentity)

    fun updateSettings(change: (SipSettings) -> SipSettings) {
        val updated = change(settings)
        if (updated == settings) return
        settings = updated
        store.settings = updated
        lifecycle?.backgroundBehavior = backgroundBehavior
    }

    fun replaceSettings(updated: SipSettings) = updateSettings { updated }

    val backgroundBehavior: BaresipAppLifecycle.BackgroundBehavior
        get() =
            if (settings.reachableInBackground) {
                BaresipAppLifecycle.BackgroundBehavior.SUSPEND
            } else {
                BaresipAppLifecycle.BackgroundBehavior.GO_OFFLINE
            }

    fun append(line: String) {
        fileLog.write(line)
        log += line
        if (log.size > LOG_LINES) log.removeRange(0, log.size - LOG_LINES)
    }

    suspend fun start(
        demo: Boolean = false,
        fresh: Boolean = false,
    ) {
        if (started) return
        started = true
        if (isDebugBuild && fresh) resetForTest()
        if (isDebugBuild && demo) seedDemo()
        startEngine()
        if (!demoMode && settings.isComplete && password.isNotEmpty()) register()
    }

    private fun resetForTest() {
        store.clear()
        settings = SipSettings()
        passwordState = ""
        turnPasswordState = ""
        doorsState = emptyList()
        contactsState = emptyList()
        historyState = emptyList()
        caCertificates = null
        clientIdentity = null
        messages.clear()
    }

    override fun pushTokenChanged(token: String) {
        scope.launch { pushTokenReceived(token) }
    }

    override suspend fun pushArrived(data: Map<String, String>): Boolean = withContext(Dispatchers.Main) { pushMessage(data) }

    companion object {
        const val CALL_UUID_HEADER = "X-Call-UUID"
        private const val LOG_LINES = 200
    }
}

data class TlsSnapshot(
    val ca: List<Byte>?,
    val client: List<Byte>?,
    val pins: List<String>,
    val verifyServer: Boolean,
)
