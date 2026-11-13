package io.github.mariokovacevic.baresipkit.zvono.model

import android.graphics.Bitmap

data class RingNotification(
    val title: String,
    val uri: String,
    val video: Boolean,
    val opensDoor: Boolean,
    val picture: Bitmap? = null,
)

interface CallSystem {
    val isInForeground: Boolean

    var proximityListener: ((Boolean) -> Unit)?

    fun showIncoming(ring: RingNotification)

    fun showMissedRing(
        title: String,
        picture: Bitmap,
    )

    fun watchProximity(watching: Boolean)

    fun updateDoorShortcuts(shortcuts: List<DoorShortcut>)

    fun cancelIncoming()

    fun callsChanged(
        call: CallRow?,
        title: String,
    )

    fun showMessage(
        sender: String,
        text: String,
    )

    fun startRinging(ringtone: Ringtone)

    fun stopRinging()

    fun playOnce(ringtone: Ringtone)

    fun stopPlaying()
}

fun interface OwnerCheck {
    suspend fun confirm(reason: String): Boolean
}

interface PushReceiver {
    fun pushTokenChanged(token: String)

    suspend fun pushArrived(data: Map<String, String>): Boolean
}
