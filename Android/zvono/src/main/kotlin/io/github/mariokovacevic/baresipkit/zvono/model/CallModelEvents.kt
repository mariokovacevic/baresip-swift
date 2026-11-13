package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallInfo
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipEvent
import io.github.mariokovacevic.baresipkit.BaresipMediaEvent
import io.github.mariokovacevic.baresipkit.BaresipMessageStatus
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall
import kotlinx.coroutines.launch

suspend fun CallModel.handle(event: BaresipEvent) {
    when (event) {
        is BaresipEvent.Engine -> append("engine ${event.state} ${event.error?.toString().orEmpty()}")
        is BaresipEvent.Registration -> {
            registration = event.state
            registrationError = event.error?.message
            append("registration ${event.state} ${event.error?.toString().orEmpty()}")
            if (event.state == BaresipRegistrationState.REGISTERED) {
                push?.bind(event.account)
                redialPending()
            }
        }
        is BaresipEvent.IncomingCall -> handleIncoming(event.info, event.earlyVideo)
        is BaresipEvent.Call -> handleState(event.state, event.call, event.error)
        is BaresipEvent.Message -> receive(event.message)
        is BaresipEvent.MessageStatus -> handleMessageStatus(event.status)
        is BaresipEvent.Media -> {
            when (event.info.event) {
                BaresipMediaEvent.RECORDING_STARTED -> {
                    recordingCall = event.call
                    append("recording ${event.call} to ${lastRecording?.name ?: "file"}")
                }
                BaresipMediaEvent.RECORDING_STOPPED -> {
                    if (recordingCall == event.call) recordingCall = null
                    append("recording of ${event.call} saved")
                }
                BaresipMediaEvent.ENCRYPTION_ESTABLISHED -> encryptedCalls[event.call] = event.info.detail
                else -> updateProximity()
            }
        }
        is BaresipEvent.Transfer ->
            append("transfer ${event.call}: ${if (event.transfer.failed) "failed" else "requested"} ${event.transfer.targetUri}")
        is BaresipEvent.Statistics -> if (event.call == phone?.activeCall?.id) stats = event.statistics
        is BaresipEvent.Ice ->
            append("ice ${event.ice.state} ${event.ice.localCandidate}/${event.ice.remoteCandidate} ${event.ice.remoteAddress}")
        is BaresipEvent.Dtmf -> if (!event.dtmf.isEnd) append("dtmf ${event.dtmf.digit}${if (event.dtmf.viaSipInfo) " (SIP INFO)" else ""}")
        is BaresipEvent.Network -> append("network: ${event.network.localAddress}")
        else -> Unit
    }
}

private suspend fun CallModel.handleIncoming(
    info: BaresipCallInfo,
    earlyVideo: Boolean,
) {
    ringingCalls += info.id
    incomingEarlyVideo = earlyVideo
    append("incoming call from ${info.remoteUri}${if (earlyVideo) " (early video offered)" else ""}")
    val alone = phone?.calls?.none { it.id != info.id } ?: true
    if (alone) system.startRinging(ringtone)
    if (telecom == null && !system.isInForeground) {
        system.showIncoming(
            ringNotification(
                CallRow(
                    id = info.id,
                    remoteUri = info.remoteUri,
                    remoteName = info.remoteDisplayName,
                    state = info.state,
                    outgoing = false,
                    hasVideo = info.hasVideo || earlyVideo,
                ),
                null,
            ),
        )
    }
    val settings = registeredSettings ?: return
    if (!alone) return
    val plan = PreviewPlan.of(settings.previewAudio, earlyVideo)
    if (plan.accountAnswersEarlyMedia) {
        if (plan.video) startPreviewFeed(info.id)
        previewing = true
        previewVideo = plan.video
        append("preview ${info.id}: ${if (plan.video) "audio+video" else "audio"} (heard after answering or Listen first)")
    } else {
        preview(info.id, hasVideo = earlyVideo)
    }
}

private suspend fun CallModel.handleState(
    state: BaresipCallState,
    call: BaresipCallID,
    error: BaresipError?,
) {
    append("call $call $state ${error?.toString().orEmpty()}")
    if ((state == BaresipCallState.CONNECTED || state == BaresipCallState.STREAMS_RUNNING) && ringingCalls.remove(call)) {
        didAnswer(call)
    }
    if (state.isTerminal) {
        ringingCalls.remove(call)
        if (ringingCalls.isEmpty()) {
            system.stopRinging()
            system.cancelIncoming()
        }
    }
    if (state == BaresipCallState.STREAMS_RUNNING) {
        startOnLoudspeaker(call)
        sendQueuedDtmf(call)
    }
    if (state == BaresipCallState.CONNECTED || state == BaresipCallState.STREAMS_RUNNING || state.isTerminal) updateCallService()
}

private fun CallModel.handleMessageStatus(status: BaresipMessageStatus) {
    val result =
        if (status.delivered) {
            ChatStatus.Delivered
        } else {
            ChatStatus.Failed(status.error?.message ?: "${status.sipStatus ?: 0}")
        }
    val index = messages.indexOfLast { it.messageId == status.id }
    if (index >= 0) messages[index] = messages[index].copy(status = result) else earlyStatuses[status.id] = result
}

fun CallModel.callsChanged(calls: List<BaresipPhoneCall>) {
    val ids = calls.map { it.id }.toSet()
    for (call in calls) knownCalls.putIfAbsent(call.id, call)
    val ended = knownCalls.filterKeys { it !in ids }
    for ((id, call) in ended) {
        knownCalls.remove(id)
        scope.launch { callEnded(call, calls.size) }
    }
}

fun CallModel.updateCallService() {
    updateProximity()
    val row = callOnScreen
    system.callsChanged(row, row?.let { doorFor(it.remoteUri)?.title ?: it.title }.orEmpty())
}

fun CallModel.movedToBackground() {
    val row = incomingRow ?: return
    val picture = previewFeed?.takeIf { it.call == row.id }?.latest
    if (picture != null) ringNotice.shownWithoutGap(System.currentTimeMillis())
    system.showIncoming(ringNotification(row, picture))
}

fun CallModel.movedToForeground() {
    system.cancelIncoming()
}
