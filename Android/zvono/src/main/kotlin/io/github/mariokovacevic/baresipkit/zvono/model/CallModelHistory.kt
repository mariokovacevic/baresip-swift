package io.github.mariokovacevic.baresipkit.zvono.model

import android.graphics.Bitmap
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest
import kotlinx.coroutines.launch
import kotlin.time.Duration.Companion.seconds
import kotlin.time.TimeSource

enum class Repeat { SAME, AUDIO, VIDEO }

val CallModel.activity: List<ActivityEntry>
    get() = ActivityEntry.list(history, doors)

fun CallModel.recordHistory(
    row: CallRow,
    call: BaresipCallID?,
    ringPicture: Bitmap? = null,
) {
    val snapshot = call?.let { snapshots.finish(it) } ?: ringPicture?.let { snapshots.save(it) }
    val record = CallRecord.of(row, call?.let { dtmfStates[it] }, System.currentTimeMillis(), snapshot)
    history = listOf(record) + history
}

suspend fun CallModel.redial(request: BaresipRedialRequest) {
    destination = request.destination
    if (!request.callsNow) {
        pendingRedial = null
        append("${request.destination} from outside the app, waiting for a tap on Call")
        return
    }
    if (registration != BaresipRegistrationState.REGISTERED) {
        pendingRedial = request
        pendingRedialSince = TimeSource.Monotonic.markNow()
        append("redial waits for the registration")
        return
    }
    pendingRedial = null
    append("redial ${if (request.video) "video" else "audio"} from outside the app")
    call(video = request.video)
}

fun CallModel.redialPending() {
    val request = pendingRedial ?: return
    val since = pendingRedialSince
    pendingRedial = null
    pendingRedialSince = null
    if (since == null || since.elapsedNow() > REDIAL_WAIT) {
        append("redial dropped: the account registered too late")
        return
    }
    scope.launch { redial(request) }
}

private val REDIAL_WAIT = 30.seconds

fun CallModel.redial(record: CallRecord) {
    destination = record.uri.ifEmpty { record.name }
}

suspend fun CallModel.repeatCall(
    record: CallRecord,
    kind: Repeat,
) {
    redial(record)
    when (kind) {
        Repeat.SAME -> {
            val request = record.dtmfRequest
            if (request != null) sendDtmfRequest(request) else call(video = record.video)
        }
        Repeat.AUDIO -> call(video = false)
        Repeat.VIDEO -> call(video = true)
    }
}

fun CallModel.removeRecord(record: CallRecord) {
    history = history.filterNot { it.id == record.id }
}

fun CallModel.save(contact: Contact) {
    val index = contacts.indexOfFirst { it.id == contact.id }
    contacts = if (index >= 0) contacts.toMutableList().also { it[index] = contact } else contacts + contact
}

fun CallModel.remove(contact: Contact) {
    contacts = contacts.filterNot { it.id == contact.id }
}
