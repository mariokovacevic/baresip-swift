package io.github.mariokovacevic.baresipkit.zvono.system

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import io.github.mariokovacevic.baresipkit.zvono.MainActivity
import io.github.mariokovacevic.baresipkit.zvono.R
import io.github.mariokovacevic.baresipkit.zvono.model.CallRow
import io.github.mariokovacevic.baresipkit.zvono.model.CallSystem
import io.github.mariokovacevic.baresipkit.zvono.model.DoorShortcut
import io.github.mariokovacevic.baresipkit.zvono.model.DoorShortcuts
import io.github.mariokovacevic.baresipkit.zvono.model.RingNotification
import io.github.mariokovacevic.baresipkit.zvono.model.Ringtone

class AndroidCallSystem(
    private val context: Context,
) : CallSystem {
    private val ringing = SoundPlayer(context)
    private val sample = SoundPlayer(context)

    init {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_INCOMING, "Rings", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "A door or a person ringing"
                setSound(null, null)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_CALL, "Calls", NotificationManager.IMPORTANCE_LOW).apply {
                description = "The call that runs"
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_MESSAGES, "Messages", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Messages from people and desks"
            },
        )
    }

    override val isInForeground: Boolean
        get() =
            ProcessLifecycleOwner
                .get()
                .lifecycle.currentState
                .isAtLeast(Lifecycle.State.STARTED)

    override var proximityListener: ((Boolean) -> Unit)? = null

    private val proximity = ProximityWatcher(context) { near -> proximityListener?.invoke(near) }

    override fun showIncoming(ring: RingNotification) {
        if (!mayNotify()) return
        val picture = ring.picture
        val caller =
            Person
                .Builder()
                .setName(ring.title.ifEmpty { "Caller" })
                .setUri(ring.uri)
                .setImportant(true)
                .apply { if (picture != null) setIcon(IconCompat.createWithBitmap(square(picture))) }
                .build()
        val show = activityIntent(MainActivity.ACTION_SHOW_INCOMING, REQUEST_SHOW)
        val answer = activityIntent(MainActivity.ACTION_ANSWER, REQUEST_ANSWER)
        val decline = broadcastIntent(CallActionReceiver.ACTION_DECLINE, REQUEST_DECLINE)
        val builder =
            NotificationCompat
                .Builder(context, CHANNEL_INCOMING)
                .setSmallIcon(R.drawable.ic_logo)
                .setColor(BRASS)
                .setContentTitle(ring.title)
                .setContentText(
                    when {
                        picture != null -> "Ringing. Expand to see who is there, tap to watch."
                        ring.video -> "Ringing with video"
                        else -> "Ringing"
                    },
                ).setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(show)
                .setFullScreenIntent(show, true)
                .setStyle(NotificationCompat.CallStyle.forIncomingCall(caller, decline, answer).setIsVideo(ring.video))
        if (picture != null) {
            builder.setLargeIcon(picture)
            val expanded = RemoteViews(context.packageName, R.layout.notification_picture)
            expanded.setImageViewBitmap(R.id.ring_picture, picture)
            expanded.setTextViewText(R.id.ring_title, ring.title)
            builder.setCustomBigContentView(expanded)
        }
        if (ring.opensDoor) {
            builder.addAction(R.drawable.ic_logo, "Open door", activityIntent(MainActivity.ACTION_OPEN_DOOR, REQUEST_OPEN_DOOR))
        }
        runCatching { NotificationManagerCompat.from(context).notify(ID_INCOMING, builder.build()) }
    }

    override fun showMissedRing(
        title: String,
        picture: Bitmap,
    ) {
        if (!mayNotify()) return
        cancelIncoming()
        val notification =
            NotificationCompat
                .Builder(context, CHANNEL_MESSAGES)
                .setSmallIcon(R.drawable.ic_logo)
                .setColor(BRASS)
                .setContentTitle(title)
                .setContentText("Missed ring")
                .setLargeIcon(picture)
                .setStyle(NotificationCompat.BigPictureStyle().bigPicture(picture).setSummaryText("Missed ring"))
                .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
                .setAutoCancel(true)
                .setContentIntent(activityIntent(MainActivity.ACTION_SHOW_ACTIVITY, REQUEST_ACTIVITY))
                .build()
        runCatching { NotificationManagerCompat.from(context).notify(ID_MISSED, notification) }
    }

    override fun watchProximity(watching: Boolean) {
        if (watching) proximity.start() else proximity.stop()
    }

    override fun updateDoorShortcuts(shortcuts: List<DoorShortcut>) {
        runCatching {
            val limit = ShortcutManagerCompat.getMaxShortcutCountPerActivity(context).coerceAtLeast(1)
            val infos =
                shortcuts.take(limit).map { shortcut ->
                    ShortcutInfoCompat
                        .Builder(context, shortcut.id)
                        .setShortLabel(shortcut.shortLabel)
                        .setLongLabel(shortcut.longLabel)
                        .setIcon(IconCompat.createWithResource(context, R.drawable.ic_shortcut_open_door))
                        .setIntent(
                            Intent(context, MainActivity::class.java)
                                .setAction(MainActivity.ACTION_OPEN_DOOR_SHORTCUT)
                                .putExtra(MainActivity.EXTRA_DOOR_ID, shortcut.doorId),
                        ).setRank(shortcut.rank)
                        .addCapabilityBinding(OPEN_APP_FEATURE, FEATURE, listOf(shortcut.longLabel.removePrefix("Open ")))
                        .build()
                }
            val ids = infos.map { it.id }.toSet()
            val pinned = ShortcutManagerCompat.getShortcuts(context, ShortcutManagerCompat.FLAG_MATCH_PINNED)
            val stale = pinned.map { it.id }.filter { it.startsWith(DoorShortcuts.PREFIX) && it !in ids }
            if (stale.isNotEmpty()) ShortcutManagerCompat.disableShortcuts(context, stale, "This door is no longer in Zvono")
            val revived = infos.filter { info -> pinned.any { it.id == info.id && !it.isEnabled } }
            if (revived.isNotEmpty()) ShortcutManagerCompat.enableShortcuts(context, revived)
            ShortcutManagerCompat.setDynamicShortcuts(context, infos)
        }
    }

    private fun square(picture: Bitmap): Bitmap {
        val side = minOf(picture.width, picture.height)
        return Bitmap.createBitmap(picture, (picture.width - side) / 2, (picture.height - side) / 2, side, side)
    }

    override fun cancelIncoming() {
        NotificationManagerCompat.from(context).cancel(ID_INCOMING)
    }

    override fun callsChanged(
        call: CallRow?,
        title: String,
    ) {
        val intent = Intent(context, CallService::class.java)
        if (call == null) {
            context.stopService(intent)
            return
        }
        intent.putExtra(CallService.EXTRA_TITLE, title)
        intent.putExtra(CallService.EXTRA_CONNECTED_AT, call.connectedAtMillis ?: 0L)
        intent.putExtra(CallService.EXTRA_VIDEO, call.sendingVideo)
        runCatching { ContextCompat.startForegroundService(context, intent) }
    }

    override fun showMessage(
        sender: String,
        text: String,
    ) {
        if (!mayNotify()) return
        val notification =
            NotificationCompat
                .Builder(context, CHANNEL_MESSAGES)
                .setSmallIcon(R.drawable.ic_logo)
                .setColor(BRASS)
                .setContentTitle(sender)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .setContentIntent(activityIntent(MainActivity.ACTION_SHOW_MESSAGES, REQUEST_MESSAGES))
                .build()
        runCatching { NotificationManagerCompat.from(context).notify(ID_MESSAGE, notification) }
    }

    override fun startRinging(ringtone: Ringtone) = ringing.play(ringtone, loop = true)

    override fun stopRinging() = ringing.stop()

    override fun playOnce(ringtone: Ringtone) = sample.play(ringtone, loop = false)

    override fun stopPlaying() = sample.stop()

    private fun mayNotify(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun activityIntent(
        action: String,
        request: Int,
    ): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java)
                .setAction(action)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(context, request, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun broadcastIntent(
        action: String,
        request: Int,
    ): PendingIntent {
        val intent = Intent(context, CallActionReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(context, request, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    companion object {
        const val CHANNEL_INCOMING = "zvono.rings"
        const val CHANNEL_CALL = "zvono.calls"
        const val CHANNEL_MESSAGES = "zvono.messages"
        const val ID_INCOMING = 1
        const val ID_CALL = 2
        const val ID_MESSAGE = 3
        const val ID_MISSED = 4
        private const val OPEN_APP_FEATURE = "actions.intent.OPEN_APP_FEATURE"
        private const val FEATURE = "feature"
        private const val REQUEST_ACTIVITY = 15
        const val BRASS = 0xFFF0B24A.toInt()
        private const val REQUEST_SHOW = 10
        private const val REQUEST_ANSWER = 11
        private const val REQUEST_DECLINE = 12
        private const val REQUEST_OPEN_DOOR = 13
        private const val REQUEST_MESSAGES = 14
    }
}

class SoundPlayer(
    private val context: Context,
) {
    private var player: MediaPlayer? = null

    fun play(
        ringtone: Ringtone,
        loop: Boolean,
    ) {
        stop()
        val uri =
            ringtone.sound?.let { Uri.parse("android.resource://${context.packageName}/$it") }
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: return
        player =
            runCatching {
                MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes
                            .Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    setDataSource(context, uri)
                    isLooping = loop
                    setOnPreparedListener { it.start() }
                    prepareAsync()
                }
            }.getOrNull()
    }

    fun stop() {
        val current = player ?: return
        player = null
        runCatching { current.stop() }
        current.release()
    }
}
