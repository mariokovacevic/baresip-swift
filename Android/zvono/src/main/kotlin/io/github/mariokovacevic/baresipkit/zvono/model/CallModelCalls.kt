package io.github.mariokovacevic.baresipkit.zvono.model

import androidx.core.telecom.CallEndpointCompat
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput
import io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute
import io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall
import io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

val CallModel.activeCall: BaresipPhoneCall?
    get() = phone?.activeCall

val CallModel.calls: List<CallRow>
    get() = if (demoMode) listOfNotNull(demoCall) else phone?.calls?.map(CallRow::of).orEmpty()

val CallModel.activeRow: CallRow?
    get() = if (demoMode) demoCall else activeCall?.let(CallRow::of)

val CallModel.callOnScreen: CallRow?
    get() = activeRow?.takeIf { !it.isRinging && !it.state.isTerminal }

val CallModel.incomingCall: BaresipPhoneCall?
    get() {
        shownIncoming?.let { id -> phone?.call(id)?.takeIf { it.isRinging }?.let { return it } }
        return phone?.incomingCall
    }

val CallModel.incomingRow: CallRow?
    get() = if (demoMode) demoIncoming else incomingCall?.let(CallRow::of)

val CallModel.heldRow: CallRow?
    get() = phone?.calls?.firstOrNull { it.id != activeCall?.id && it.isOnHold }?.let(CallRow::of)

fun CallModel.phoneCall(id: BaresipCallID?): BaresipPhoneCall? = id?.let { phone?.call(it) }

fun CallModel.normalizedDestination(raw: String): String = SipNames.normalized(raw, (registeredSettings ?: settings).domain)

suspend fun CallModel.call(video: Boolean) {
    val target = normalizedDestination(destination)
    val phone = phone
    if (demoMode) {
        if (target.isNotEmpty()) startDemoCall(target, video)
        pendingDtmf = null
        return
    }
    if (target.isEmpty() || phone == null) {
        pendingDtmf = null
        return
    }
    callMinimized = false
    if (telecom == null) activateAppAudio()
    try {
        val placed = phone.makeCall(target, video = video)
        pendingDtmf?.let { request ->
            dtmfStates[placed.id] = DtmfState(request)
            pendingDtmf = null
            if (placed.state == BaresipCallState.STREAMS_RUNNING) sendQueuedDtmf(placed.id)
        }
        updateCallService()
    } catch (error: Throwable) {
        pendingDtmf = null
        append("call failed: $error")
    }
}

suspend fun CallModel.answer() {
    if (demoMode) {
        answerDemo()
        return
    }
    val incoming = incomingCall ?: return
    if (telecom == null) activateAppAudio()
    try {
        incoming.answer(video = incoming.hasVideo || incomingEarlyVideo)
    } catch (error: Throwable) {
        append("answer failed: $error")
        return
    }
    didAnswer(incoming.id)
}

fun CallModel.didAnswer(call: BaresipCallID) {
    if (!answeredCalls.add(call)) return
    endPreviewFeed(call)
    callMinimized = false
    previewing = false
    previewVideo = false
    incomingEarlyVideo = false
    if (shownIncoming == call) shownIncoming = null
    system.stopRinging()
    system.cancelIncoming()
    updateCallService()
}

suspend fun CallModel.reject() {
    if (demoMode) {
        demoIncoming = null
        return
    }
    val incoming = incomingCall ?: return
    system.stopRinging()
    declinedCalls += incoming.id
    endPreviewFeed(incoming.id)
    try {
        incoming.reject()
    } catch (error: Throwable) {
        append("decline failed: $error")
    }
    previewing = false
    previewVideo = false
}

suspend fun CallModel.hangUp() {
    if (demoMode) {
        endDemoCall()
        return
    }
    runCatching { activeCall?.hangUp() }
}

suspend fun CallModel.hangUp(call: BaresipCallID) {
    runCatching { phone?.call(call)?.hangUp() }
}

suspend fun CallModel.switchTo(call: BaresipCallID) {
    val phone = phone ?: return
    val target = phone.call(call) ?: return
    runCatching { phone.makeActive(target) }.onFailure { append("switch failed: $it") }
}

suspend fun CallModel.toggleHold(call: BaresipCallID? = activeCall?.id) {
    if (demoMode) {
        demoCall = demoCall?.let { it.copy(state = if (it.isOnHold) BaresipCallState.STREAMS_RUNNING else BaresipCallState.PAUSED) }
        return
    }
    val target = call?.let { phone?.call(it) } ?: return
    runCatching { target.setOnHold(!target.isOnHold) }.onFailure { append("hold failed: $it") }
}

suspend fun CallModel.toggleMute() {
    if (demoMode) {
        demoCall = demoCall?.let { it.copy(muted = !it.muted) }
        return
    }
    val call = activeCall ?: return
    runCatching { call.setMuted(!call.isMuted) }.onFailure { append("mute failed: $it") }
}

suspend fun CallModel.toggleVideo() {
    if (demoMode) {
        demoCall = demoCall?.let { it.copy(sendingVideo = !it.sendingVideo) }
        return
    }
    val call = activeCall ?: return
    runCatching { call.setVideoEnabled(!call.isSendingVideo) }.onFailure { append("camera change failed: $it") }
    updateProximity()
}

suspend fun CallModel.switchCamera() {
    runCatching { activeCall?.switchCamera() }.onFailure { append("camera switch failed: $it") }
}

suspend fun CallModel.restartIce() {
    val engine = engine ?: return
    val call = activeCall ?: return
    runCatching { engine.restartIce(call.id) }.onFailure { append("ICE restart failed: $it") }
}

suspend fun CallModel.refreshStatistics() {
    val engine = engine ?: return
    val call = activeCall ?: return
    if (!call.isConnected && !call.isOnHold) return
    runCatching { engine.callStatistics(call.id) }.onSuccess { stats = it }
}

suspend fun CallModel.preview() {
    if (demoMode) {
        demoIncoming = demoIncoming?.copy(previewing = true)
        previewing = true
        previewVideo = true
        return
    }
    val incoming = incomingCall ?: return
    preview(incoming.id, incoming.hasVideo || incomingEarlyVideo, explicit = true)
}

suspend fun CallModel.preview(
    call: BaresipCallID,
    hasVideo: Boolean,
    explicit: Boolean = false,
) {
    if (previewing && !explicit) return
    val engine = engine ?: return
    val audio = (registeredSettings?.previewAudio ?: true) || !hasVideo
    try {
        if (audio && explicit) activateAppAudio()
        if (hasVideo) startPreviewFeed(call)
        val tracked = phone?.call(call)
        if (tracked != null) tracked.startPreview(video = hasVideo, audio = audio) else engine.sendProgress(call, hasVideo, audio)
        previewing = true
        previewVideo = hasVideo
        append("previewing $call (they do not hear or see you)")
    } catch (error: Throwable) {
        append("preview failed: $error")
    }
}

suspend fun CallModel.activateAppAudio() {
    if (appAudioActive) return
    val audio = audio ?: return
    system.stopRinging()
    if (audio.activate()) appAudioActive = true else append("audio focus refused, another app holds it")
}

suspend fun CallModel.callEnded(
    call: BaresipPhoneCall,
    remaining: Int,
) {
    val ringPicture = endPreviewFeed(call.id, ended = call)
    recordHistory(CallRow.of(call), call.id, ringPicture)
    declinedCalls.remove(call.id)
    dtmfStates.remove(call.id)
    answeredCalls.remove(call.id)
    encryptedCalls.remove(call.id)
    loudspeakerCalls.remove(call.id)
    manualOutputCalls.remove(call.id)
    if (shownIncoming == call.id) shownIncoming = null
    if (incomingRow == null) {
        previewing = false
        previewVideo = false
        incomingEarlyVideo = false
        system.stopRinging()
        system.cancelIncoming()
    }
    updateCallService()
    if (remaining > 0) return
    stats = null
    callMinimized = false
    captions = emptyList()
    showCallChat = null
    if (appAudioActive) {
        appAudioActive = false
        audio?.deactivate()
    }
    if (pendingApply) {
        pendingApply = false
        scope.launch { applySaved() }
    }
}

fun CallModel.telecomCall(id: BaresipCallID?): BaresipTelecomCall? = id?.let { telecom?.telecomCall(it) }

fun CallModel.startOnLoudspeaker(call: BaresipCallID) {
    if (!loudspeakerCalls.add(call) || call in manualOutputCalls) return
    val telecomCall = telecomCall(call)
    if (telecomCall != null) {
        scope.launch {
            val current = telecomCall.currentEndpoint.value
            if (current != null && current.type != CallEndpointCompat.TYPE_EARPIECE) return@launch
            val speaker = telecomCall.availableEndpoints.value.firstOrNull { it.type == CallEndpointCompat.TYPE_SPEAKER } ?: return@launch
            runCatching { telecomCall.requestEndpoint(speaker) }
            audioRouteChanges++
        }
        return
    }
    val audio = audio ?: return
    if (audio.currentRoute == BaresipAudioRoute.Earpiece) {
        audio.selectOutput(BaresipAudioOutput.SPEAKER)
        audioRouteChanges++
    }
}

enum class OutputKind { PHONE, SPEAKER, BLUETOOTH, HEADSET, OTHER }

data class OutputChoice(
    val id: String,
    val name: String,
    val kind: OutputKind,
    val selected: Boolean,
)

fun endpointChoices(
    available: List<CallEndpointCompat>,
    current: CallEndpointCompat?,
): List<OutputChoice> =
    available.map { endpoint ->
        val kind =
            when (endpoint.type) {
                CallEndpointCompat.TYPE_EARPIECE -> OutputKind.PHONE
                CallEndpointCompat.TYPE_SPEAKER -> OutputKind.SPEAKER
                CallEndpointCompat.TYPE_BLUETOOTH -> OutputKind.BLUETOOTH
                CallEndpointCompat.TYPE_WIRED_HEADSET -> OutputKind.HEADSET
                else -> OutputKind.OTHER
            }
        val name = if (kind == OutputKind.PHONE) "Phone" else endpoint.name.toString()
        OutputChoice(endpoint.identifier.toString(), name, kind, endpoint.identifier == current?.identifier)
    }

fun CallModel.controllerChoices(): List<OutputChoice> {
    val audio = audio ?: return listOf(OutputChoice(BaresipAudioOutput.SPEAKER.id, "Speaker", OutputKind.SPEAKER, true))
    val current = audio.currentOutput
    return audio.availableOutputs.map { output ->
        val kind =
            when (output.route) {
                BaresipAudioRoute.Earpiece -> OutputKind.PHONE
                BaresipAudioRoute.Speaker -> OutputKind.SPEAKER
                BaresipAudioRoute.Bluetooth -> OutputKind.BLUETOOTH
                BaresipAudioRoute.WiredHeadset -> OutputKind.HEADSET
                is BaresipAudioRoute.Other -> OutputKind.OTHER
            }
        OutputChoice(output.id, output.name, kind, output.id == current?.id)
    }
}

fun CallModel.selectOutput(
    choice: OutputChoice,
    byUser: Boolean = true,
) {
    val call = activeCall?.id
    if (call != null && byUser) {
        manualOutputCalls += call
        system.watchProximity(false)
    }
    val telecomCall = telecomCall(call)
    if (telecomCall != null) {
        val endpoint = telecomCall.availableEndpoints.value.firstOrNull { it.identifier.toString() == choice.id } ?: return
        scope.launch {
            runCatching { telecomCall.requestEndpoint(endpoint) }.onFailure { append("audio output ${choice.name} failed: $it") }
            audioRouteChanges++
        }
    } else {
        val output = audio?.availableOutputs?.firstOrNull { it.id == choice.id } ?: return
        runCatching { audio?.selectOutput(output) }.onFailure { append("audio output ${choice.name} failed: $it") }
        audioRouteChanges++
    }
    append("audio output: ${choice.name}${if (byUser) "" else " (proximity)"}")
}

suspend fun CallModel.toggleRecording() {
    val engine = engine ?: return
    val call = activeCall ?: return
    try {
        if (recordingCall == call.id) {
            engine.stopRecording(call.id)
            return
        }
        val folder = File(context.getExternalFilesDir(null) ?: context.filesDir, "Recordings").apply { mkdirs() }
        val stamp = SimpleDateFormat("yyyy-MM-dd'T'HH-mm-ss", Locale.US).format(Date())
        val name = SipNames.user(call.remoteUri).ifEmpty { "call" }.replace('/', '-')
        val file = File(folder, "$stamp $name.wav")
        val previous = lastRecording
        lastRecording = file
        try {
            engine.startRecording(call.id, file)
        } catch (error: Throwable) {
            lastRecording = previous
            throw error
        }
    } catch (error: Throwable) {
        append("recording failed: $error")
    }
}

suspend fun CallModel.blindTransfer() {
    val engine = engine ?: return
    val call = activeCall ?: return
    val target = normalizedDestination(transferTarget)
    if (target.isEmpty()) return
    runCatching { engine.blindTransfer(call.id, target) }
        .onSuccess { append("transferring ${call.id} to $target") }
        .onFailure { append("transfer failed: $it") }
}

suspend fun CallModel.consult() {
    val phone = phone ?: return
    val active = activeCall ?: return
    if (heldRow != null) return
    val target = normalizedDestination(transferTarget)
    if (target.isEmpty()) return
    try {
        active.setOnHold(true)
        val consultation = phone.makeCall(target)
        phone.makeActive(consultation)
        append("consulting $target while ${active.id} is on hold")
    } catch (error: Throwable) {
        append("consultation failed: $error")
    }
}

suspend fun CallModel.completeTransfer() {
    val engine = engine ?: return
    val held = heldRow?.id ?: return
    val current = activeCall?.id ?: return
    if (held == current) return
    runCatching { engine.attendedTransfer(held, current) }
        .onSuccess { append("attended transfer of $held to $current") }
        .onFailure { append("attended transfer failed: $it") }
}

suspend fun CallModel.endConsultation() {
    if (heldRow == null) return
    runCatching { activeCall?.hangUp() }
}
