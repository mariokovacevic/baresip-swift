package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

fun CallModel.doorFor(remote: String?): Door? = remote?.let { doors.matching(it) }

val CallModel.currentDoor: Door?
    get() = doorFor(callOnScreen?.remoteUri)?.takeIf { it.canOpen }

val CallModel.ringingDoor: Door?
    get() = doorFor(incomingRow?.remoteUri)?.takeIf { it.canOpen }

val CallModel.currentDoorOpened: Boolean
    get() {
        if (demoMode) return demoDoorOpened
        val id = activeCall?.id ?: return false
        return dtmfStates[id]?.opened == true
    }

fun CallModel.save(door: Door) {
    val index = doors.indexOfFirst { it.id == door.id }
    doors = if (index >= 0) doors.toMutableList().also { it[index] = door } else doors + door
}

fun CallModel.remove(door: Door) {
    doors = doors.filterNot { it.id == door.id }
}

fun CallModel.lastRecord(door: Door): CallRecord? = history.firstOrNull { it.user == door.user }

fun CallModel.lastPicture(door: Door): String? = history.firstOrNull { it.user == door.user && it.snapshotFile != null }?.snapshotFile

suspend fun CallModel.open(
    door: Door,
    confirmingOwner: Boolean = true,
) {
    if (!door.canOpen) return
    if (confirmingOwner && !confirmOwner(door)) return
    destination = door.address
    val active = activeCall
    if (active != null && doorFor(active.remoteUri)?.id == door.id) {
        sendDtmfRequest(door.openRequest)
    } else {
        pendingDtmf = door.openRequest
        call(video = false)
    }
}

suspend fun CallModel.look(door: Door) {
    destination = door.address
    call(video = false)
}

suspend fun CallModel.openCurrentDoor() {
    val door = currentDoor ?: return
    if (!confirmOwner(door)) return
    if (demoMode) {
        demoDoorOpened = true
        return
    }
    sendDtmfRequest(door.openRequest)
}

suspend fun CallModel.openRingingDoor() {
    val door = ringingDoor ?: return
    if (!confirmOwner(door)) return
    if (demoMode) {
        answerDemo()
        demoDoorOpened = true
        return
    }
    val incoming = incomingCall ?: return
    if (telecom == null) activateAppAudio()
    dtmfStates[incoming.id] = DtmfState(door.openRequest)
    try {
        incoming.answer(video = false)
    } catch (error: Throwable) {
        dtmfStates.remove(incoming.id)
        append("open door failed: $error")
        return
    }
    didAnswer(incoming.id)
}

suspend fun CallModel.confirmOwner(door: Door): Boolean {
    if (!door.asksToUnlockFirst) return true
    val check = ownerCheck ?: return true
    return check.confirm("Open ${door.title}")
}

suspend fun CallModel.sendDtmfRequest(request: DtmfRequest) {
    val active = activeCall
    if (active == null) {
        pendingDtmf = request
        call(video = false)
        return
    }
    dtmfStates[active.id] = DtmfState(request)
    if (active.state == BaresipCallState.STREAMS_RUNNING) sendQueuedDtmf(active.id)
}

fun CallModel.sendQueuedDtmf(call: BaresipCallID) {
    val state = dtmfStates[call] ?: return
    if (state.sent) return
    val target = phone?.call(call) ?: return
    dtmfStates[call] = state.copy(sent = true)
    val request = state.request
    scope.launch {
        val result =
            try {
                val reply = request.replyDigit
                val outcome =
                    if (reply != null) {
                        when (val answer = target.sendDtmf(request.digits, reply, DtmfRequest.ackTimeout)) {
                            BaresipDtmfReply.Confirmed -> "door opened"
                            is BaresipDtmfReply.Other -> "reply ${answer.digit}, expected $reply"
                            BaresipDtmfReply.NoReply -> "no reply"
                        }
                    } else {
                        target.sendDtmf(request.digits)
                        "sent"
                    }
                append("sent DTMF ${request.digits}")
                outcome
            } catch (error: Throwable) {
                "failed: $error"
            }
        finishDtmf(call, result)
    }
}

suspend fun CallModel.finishDtmf(
    call: BaresipCallID,
    result: String,
) {
    val state = dtmfStates[call] ?: return
    if (state.result != null) return
    dtmfStates[call] = state.copy(result = result)
    append("DTMF ${state.request.digits}: $result")
    if (!state.request.hangUp) return
    delay(DtmfRequest.hangUpDelay)
    hangUp(call)
}

suspend fun CallModel.sendDtmf(digits: String) {
    runCatching { activeCall?.sendDtmf(digits) }
}
