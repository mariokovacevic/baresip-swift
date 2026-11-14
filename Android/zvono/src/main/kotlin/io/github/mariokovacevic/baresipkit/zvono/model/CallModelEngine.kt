package io.github.mariokovacevic.baresipkit.zvono.model

import androidx.compose.runtime.snapshotFlow
import io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration
import io.github.mariokovacevic.baresipkit.BaresipAppLifecycle
import io.github.mariokovacevic.baresipkit.BaresipCertificates
import io.github.mariokovacevic.baresipkit.BaresipConfiguration
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipHandleStyle
import io.github.mariokovacevic.baresipkit.BaresipLogLevel
import io.github.mariokovacevic.baresipkit.BaresipLogcat
import io.github.mariokovacevic.baresipkit.BaresipNatTraversal
import io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration
import io.github.mariokovacevic.baresipkit.BaresipTurnServer
import io.github.mariokovacevic.baresipkit.audio.BaresipAudioController
import io.github.mariokovacevic.baresipkit.compose.BaresipPhone
import io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter
import io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter
import io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall
import io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration
import io.github.mariokovacevic.baresipkit.zvono.R
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.time.Duration.Companion.seconds

suspend fun CallModel.startEngine() {
    try {
        val tls = savedTls()
        val options = settings.engine
        val configuration =
            BaresipConfiguration {
                userAgent = "Zvono/1.0"
                instanceUuid = store.instanceUuid
                logLevel = BaresipLogLevel.INFO
                logSipTrace = logsSipMessages
                audio { holdMusicFile = holdMusicFile() }
                video {
                    if (options.videoHeight > 0) {
                        width = EngineOptions.width(options.videoHeight)
                        height = options.videoHeight
                    }
                    if (options.videoFramesPerSecond > 0) framesPerSecond = options.videoFramesPerSecond
                    if (options.videoBitrateKbps > 0) bitrate = options.videoBitrateKbps * 1000
                }
                this.tls = tlsConfiguration(tls)
                ipv6 = options.ipv6
                iceRelayOnly = options.iceRelayOnly
                videoAdaptiveBitrate = options.adaptiveBitrate
            }
        val engine = BaresipEngine(profile.configure(configuration))
        engine.setLogHandler(fileLog.handler(BaresipLogcat.handler("Zvono")))
        this.engine = engine
        engineTls = tls
        engineOptions = options
        engineLogsSipMessages = logsSipMessages
        val events = scope.launch(start = CoroutineStart.UNDISPATCHED) { engine.events.collect { handle(it) } }
        engineIntegration = callIntegration
        val telecom =
            if (callIntegration != CallIntegration.SYSTEM) {
                null
            } else {
                runCatching {
                    BaresipTelecomAdapter(
                        context,
                        engine,
                        profile.configure(
                            BaresipTelecomConfiguration {
                                callUuidHeader = CallModel.CALL_UUID_HEADER
                                handleStyle = BaresipHandleStyle.PHONE_NUMBER_WHEN_NUMERIC
                            },
                        ),
                    ) { call -> scope.launch { telecomRinging(call) } }
                }.onFailure { append("Telecom unavailable, calls go to the engine directly: $it") }.getOrNull()
            }
        this.telecom = telecom
        val phone = BaresipPhone(engine, telecom, scope)
        this.phone = phone
        val phoneJob = scope.launch { phone.run() }
        val callsJob = scope.launch { snapshotFlow { phone.calls.toList() }.collect { callsChanged(it) } }
        engineJobs = listOf(events, phoneJob, callsJob)
        engine.start()
        startNetworkMonitor(engine)
        startLifecycle(engine)
        audio = BaresipAudioController(context, engine) { audioRouteChanges++ }.also { it.configureForVoip(defaultToSpeaker = true) }
        ensurePushAdapter()
        append(
            "engine started, ${if (telecom == null) "calls in the app only" else "calls through Telecom"}, " +
                "core ${BaresipEngine.coreVersion}, CA ${if (tls.ca == null) "system" else "custom"}, " +
                "client certificate ${if (tls.client == null) "none" else "set"}, pins ${tls.pins.size}",
        )
    } catch (error: Throwable) {
        append("engine start failed: $error")
    }
}

private fun CallModel.holdMusicFile(): File? =
    runCatching {
        val file = File(context.filesDir, "Sounds/HoldMusic.wav")
        if (!file.exists()) {
            file.parentFile?.mkdirs()
            context.resources.openRawResource(R.raw.hold_music).use { input -> file.outputStream().use { input.copyTo(it) } }
        }
        file
    }.getOrNull()

private fun CallModel.startLifecycle(engine: BaresipEngine) {
    val lifecycle = BaresipAppLifecycle(engine)
    lifecycle.backgroundBehavior = backgroundBehavior
    lifecycle.setChangeHandler { change ->
        scope.launch {
            when (change) {
                BaresipAppLifecycle.Change.SUSPENDED -> append("in the background without a call: SIP paused")
                BaresipAppLifecycle.Change.WENT_OFFLINE -> append("in the background without a call: SIP offline")
                BaresipAppLifecycle.Change.BACK_ONLINE -> append("app active again: SIP online")
            }
        }
    }
    lifecycle.start()
    this.lifecycle = lifecycle
}

private fun CallModel.startNetworkMonitor(engine: BaresipEngine) {
    val monitor = BaresipNetworkMonitor(context, engine)
    monitor.setChangeHandler { path ->
        scope.launch {
            val previous = lastNetworkPath
            lastNetworkPath = path.interfaceSummary.ifEmpty { "No network" }
            if (path.isSatisfied && previous != null && previous != path.interfaceSummary) {
                append("network path changed: ${path.interfaceSummary}")
            }
        }
    }
    monitor.start()
    networkMonitor = monitor
}

fun CallModel.ensurePushAdapter() {
    val engine = engine ?: return
    val token = pushToken ?: return
    val adapter =
        push ?: BaresipPushAdapter(engine, appId = profile.pushAppId(context), account = accountId) { call ->
            telecom?.reportIncomingCallFromPush(call.uuid, call.remoteUri, call.displayName, call.hasVideo)
        }.also { created ->
            created.setErrorHandler { step, error -> scope.launch { append("push: $step failed: $error") } }
            push = created
        }
    adapter.updateToken(token)
}

suspend fun CallModel.pushTokenReceived(token: String) {
    pushToken = token
    ensurePushAdapter()
    append("push token received")
}

suspend fun CallModel.pushMessage(data: Map<String, String>): Boolean {
    start()
    return push?.handle(data) ?: false
}

suspend fun CallModel.restartEngine() {
    append("certificates or engine settings changed, restarting the engine")
    val running = engine
    if (running != null) {
        accountId?.let { runCatching { running.unregister(it) } }
        running.stop()
    }
    networkMonitor?.stop()
    networkMonitor = null
    previewFeed?.stop()
    previewFeed = null
    system.watchProximity(false)
    lifecycle?.stop()
    lifecycle = null
    engineJobs.forEach { it.cancel() }
    engineJobs = emptyList()
    telecom?.close()
    telecom = null
    audio?.release()
    audio = null
    phone = null
    push = null
    accountId = null
    knownCalls.clear()
    running?.let { withContext(Dispatchers.Default) { it.close() } }
    engine = null
    registration = BaresipRegistrationState.NONE
    startEngine()
}

suspend fun CallModel.saveAndRegister() {
    store.settings = settings
    store.password = password
    store.turnPassword = turnPassword
    store.caCertificates = caCertificates
    store.clientIdentity = clientIdentity
    if (calls.isNotEmpty()) {
        pendingApply = true
        append("settings saved; they apply after the current call")
        return
    }
    applySaved()
}

suspend fun CallModel.applySaved() {
    if (savedTls() != engineTls ||
        settings.engine != engineOptions ||
        logsSipMessages != engineLogsSipMessages ||
        callIntegration != engineIntegration
    ) {
        restartEngine()
    }
    register()
}

suspend fun CallModel.register() {
    val engine = engine ?: return
    if (demoMode) return
    val saved = settings
    if (!saved.isComplete) {
        registrationError = "Domain and username are required."
        return
    }
    registrationError = null
    try {
        accountId?.let { previous ->
            runCatching { engine.unregister(previous) }
            engine.removeAccount(previous)
            accountId = null
        }
        val id = engine.addAccount(profile.configure(accountConfiguration(saved, password, turnPassword)))
        accountId = id
        registeredSettings = saved
        push?.bind(id)
        engine.register(id)
        append("registering ${saved.aor} via ${saved.registrar}")
    } catch (error: Throwable) {
        registrationError = error.message ?: error.toString()
        append("register failed: $error")
    }
}

suspend fun CallModel.unregister() {
    val engine = engine ?: return
    val id = accountId ?: return
    runCatching { engine.unregister(id) }
}

fun CallModel.savedTls(): TlsSnapshot = TlsSnapshot(caCertificates?.toList(), clientIdentity?.toList(), settings.pinList)

fun tlsConfiguration(tls: TlsSnapshot): BaresipTlsConfiguration =
    BaresipTlsConfiguration {
        caCertificatesPem = tls.ca?.toByteArray()
        clientCertificatePem = tls.client?.toByteArray()
        pinnedSpkiSha256 = tls.pins
    }

fun accountConfiguration(
    settings: SipSettings,
    password: String,
    turnPassword: String,
): BaresipAccountConfiguration {
    val turnUser = settings.turnUser.trim()
    return BaresipAccountConfiguration(aor = settings.aor) {
        displayName = settings.displayName.trim().ifEmpty { null }
        registrar = settings.registrar
        outboundProxy = settings.proxy
        transport = settings.transport
        authUser = settings.authUser.trim().ifEmpty { settings.username.trim() }
        authPassword = password
        registerExpires = settings.registerExpiresSeconds.coerceAtLeast(60).seconds
        sipOutbound = settings.sipOutbound
        mediaEncryption = settings.mediaEncryption
        nat {
            mode = settings.natMode
            stunUri = settings.stunUri.trim().takeIf { settings.natMode != BaresipNatTraversal.NONE && it.isNotEmpty() }
            if (settings.natMode == BaresipNatTraversal.ICE && settings.turnUri.isNotBlank()) {
                turnServers =
                    listOf(
                        BaresipTurnServer(settings.turnUri.trim()) {
                            username = turnUser.ifEmpty { null }
                            this.password = turnPassword.ifEmpty { null }
                        },
                    )
            }
            rtpTimeout = settings.rtpTimeoutSeconds.coerceAtLeast(0).seconds
            rtcpMultiplexing = settings.rtcpMux
            pinhole = settings.pinhole
        }
        dtmfMode = settings.dtmfMode
        audioCodecs = SipSettings.codecList(settings.audioCodecs)
        videoCodecs = SipSettings.codecList(settings.videoCodecs)
        answerEarlyMedia = settings.previewAudio
        acceptTransfers = settings.acceptTransfers
        pictureUpdateOverSipInfo = settings.pictureUpdateOverInfo
        incomingHeaders = listOf(CallModel.CALL_UUID_HEADER)
    }
}

fun CallModel.setCa(pem: String) {
    if (pem.isBlank()) {
        caCertificates = null
        store.caCertificates = null
        return
    }
    val bundle = BaresipCertificates.caBundle(pem.toByteArray())
    caCertificates = bundle
    store.caCertificates = bundle
    append("CA entered: ${caSummaries.joinToString(", ")}")
}

fun CallModel.importCa(data: ByteArray) {
    runCatching {
        val bundle = BaresipCertificates.caBundle(data)
        caCertificates = bundle
        store.caCertificates = bundle
        append("CA imported: ${caSummaries.joinToString(", ")}")
    }.onFailure { append("CA import failed: ${it.message ?: it}") }
}

fun CallModel.setClientIdentity(
    certificate: String,
    key: String,
) {
    if (certificate.isBlank() && key.isBlank()) {
        clientIdentity = null
        store.clientIdentity = null
        return
    }
    val identity = BaresipCertificates.clientIdentity((certificate.trim() + "\n" + key.trim()).toByteArray())
    clientIdentity = identity
    store.clientIdentity = identity
    append("client certificate entered: ${clientSummaries.firstOrNull().orEmpty()}")
}

fun CallModel.importClientIdentity(data: ByteArray) {
    runCatching {
        val identity = BaresipCertificates.clientIdentity(data)
        clientIdentity = identity
        store.clientIdentity = identity
        append("client certificate imported: ${clientSummaries.firstOrNull().orEmpty()}")
    }.onFailure { append("client certificate import failed: ${it.message ?: it}") }
}

suspend fun CallModel.applyCallIntegration() {
    if (engine == null || callIntegration == engineIntegration) return
    if (calls.isNotEmpty()) {
        pendingApply = true
        append("calls go ${callIntegration.title} after the current call")
        return
    }
    restartEngine()
    register()
}

fun CallModel.telecomRinging(call: BaresipTelecomCall) {
    if (system.isInForeground) return
    val door = doors.matching(call.remoteUri)
    system.showIncoming(
        RingNotification(
            door?.title ?: call.displayName ?: SipNames.user(call.remoteUri),
            call.remoteUri,
            call.hasVideo,
            door?.let { it.canOpen && it.opensFromNotification } == true,
            previewFeed?.latest?.takeIf { settings.ringPicture },
        ),
    )
}
