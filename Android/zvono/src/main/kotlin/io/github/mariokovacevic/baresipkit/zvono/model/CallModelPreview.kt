package io.github.mariokovacevic.baresipkit.zvono.model

import android.graphics.Bitmap
import androidx.compose.runtime.snapshotFlow
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.time.Duration.Companion.seconds

suspend fun CallModel.startPreviewFeed(call: BaresipCallID) {
    val engine = engine ?: return
    if (previewFeed?.call == call) return
    previewFeed?.stop()
    ringNotice.reset()
    val feed =
        CallPreviewFeed(call, File(context.cacheDir, "Preview/${call.rawValue}.jpg")) { picture ->
            scope.launch { previewPictureSaved(call, picture) }
        }
    previewFeed = feed
    try {
        engine.setVideoRenderer(call, feed)
    } catch (error: Throwable) {
        feed.stop()
        if (previewFeed === feed) previewFeed = null
        append("preview pictures unavailable: $error")
    }
}

fun CallModel.previewPictureSaved(
    call: BaresipCallID,
    picture: Bitmap,
) {
    val feed = previewFeed ?: return
    if (feed.call != call) return
    val shows = RingNotice.showsPicture(settings.ringPicture, system.isInForeground, call in ringingCalls)
    val first = !ringNotice.hasPicture
    if (!ringNotice.pictureArrived(System.currentTimeMillis(), shows)) return
    val row = phone?.call(call)?.let(CallRow::of) ?: return
    system.showIncoming(ringNotification(row, picture))
    if (first) append("preview notification shown for $call")
}

fun CallModel.ringNotification(
    row: CallRow,
    picture: Bitmap?,
): RingNotification {
    val door = doorFor(row.remoteUri)
    return RingNotification(
        title = door?.title ?: row.title,
        uri = row.remoteUri,
        video = row.hasVideo || incomingEarlyVideo || picture != null,
        opensDoor = door?.let { it.canOpen && it.opensFromNotification } == true,
        picture = picture?.takeIf { settings.ringPicture },
    )
}

fun CallModel.endPreviewFeed(
    call: BaresipCallID,
    ended: BaresipPhoneCall? = null,
): Bitmap? {
    val feed = previewFeed ?: return null
    if (feed.call != call) return null
    val picture = feed.latest
    if (ended != null && picture != null) {
        val missed =
            RingNotice.leavesMissedRing(
                ringPicture = settings.ringPicture,
                hasPicture = true,
                inForeground = system.isInForeground,
                answered = ended.connectedAt != null || call in answeredCalls,
                declinedHere = call in declinedCalls,
                endedElsewhere = ended.error?.endReason != null,
            )
        if (missed) {
            system.showMissedRing(doorFor(ended.remoteUri)?.title ?: ended.displayName.ifEmpty { "Door" }, picture)
            append("missed ring notification for $call")
        }
    }
    feed.stop()
    previewFeed = null
    ringNotice.reset()
    return picture
}

fun CallModel.currentOutputChoices(): List<OutputChoice> {
    val telecomCall = telecomCall(activeCall?.id)
    if (telecomCall != null) return endpointChoices(telecomCall.availableEndpoints.value, telecomCall.currentEndpoint.value)
    return controllerChoices()
}

private val CallRow.audioOnly: Boolean
    get() = !sendingVideo && !receivingVideo

fun CallModel.updateProximity() {
    if (demoMode) return
    val row = callOnScreen
    val watching =
        row != null &&
            ProximityRule.watches(
                connected = row.isConnected,
                audioOnly = row.audioOnly,
                userChoseOutput = row.id in manualOutputCalls,
                current = currentOutputChoices().firstOrNull { it.selected }?.kind,
            )
    system.watchProximity(watching)
}

fun CallModel.proximityChanged(near: Boolean) {
    val row = callOnScreen ?: return
    val choices = currentOutputChoices()
    val target =
        ProximityRule.route(
            near = near,
            audioOnly = row.audioOnly,
            userChoseOutput = row.id in manualOutputCalls,
            current = choices.firstOrNull { it.selected }?.kind,
            available = choices.map { it.kind }.toSet(),
        ) ?: return
    choices.firstOrNull { it.kind == target }?.let { selectOutput(it, byUser = false) }
}

suspend fun CallModel.openFromShortcut(
    doorId: String?,
    name: String?,
): Boolean {
    val door = DoorShortcuts.door(doors, doorId, name)
    if (door == null) {
        append("shortcut: no door ${name ?: doorId.orEmpty()} with a code")
        return false
    }
    val ringing = incomingRow
    if (ringing != null && doorFor(ringing.remoteUri)?.id == door.id) {
        openRingingDoor()
        return true
    }
    val talking = callOnScreen
    if (talking != null && doorFor(talking.remoteUri)?.id == door.id) {
        openCurrentDoor()
        return true
    }
    start()
    if (!demoMode && registration != BaresipRegistrationState.REGISTERED) {
        val registered = withTimeoutOrNull(15.seconds) { snapshotFlow { registration }.first { it == BaresipRegistrationState.REGISTERED } }
        if (registered == null) {
            append("shortcut: ${door.title} not opened, the server was not reached")
            return false
        }
    }
    open(door, confirmingOwner = true)
    return true
}
