package io.github.mariokovacevic.baresipkit.zvono.system

import android.Manifest
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import io.github.mariokovacevic.baresipkit.zvono.MainActivity
import io.github.mariokovacevic.baresipkit.zvono.R

class CallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty().ifEmpty { "Call" }
        val connectedAt = intent?.getLongExtra(EXTRA_CONNECTED_AT, 0L) ?: 0L
        val video = intent?.getBooleanExtra(EXTRA_VIDEO, false) ?: false
        val open =
            PendingIntent.getActivity(
                this,
                REQUEST_OPEN,
                Intent(this, MainActivity::class.java).setAction(MainActivity.ACTION_SHOW_CALL).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        val hangUp =
            PendingIntent.getBroadcast(
                this,
                REQUEST_HANG_UP,
                Intent(this, CallActionReceiver::class.java).setAction(CallActionReceiver.ACTION_HANG_UP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        val builder =
            NotificationCompat
                .Builder(this, AndroidCallSystem.CHANNEL_CALL)
                .setSmallIcon(R.drawable.ic_logo)
                .setColor(AndroidCallSystem.BRASS)
                .setContentTitle(title)
                .setContentText(if (connectedAt > 0) "In call" else "Calling…")
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setContentIntent(open)
                .setStyle(NotificationCompat.CallStyle.forOngoingCall(Person.Builder().setName(title).build(), hangUp).setIsVideo(video))
        if (connectedAt > 0) builder.setWhen(connectedAt).setUsesChronometer(true).setShowWhen(true)
        val notification = builder.build()
        val started =
            listOf(foregroundTypes(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE.takeIf { granted(Manifest.permission.RECORD_AUDIO) } ?: 0)
                .any { types ->
                    runCatching {
                        ServiceCompat.startForeground(this, AndroidCallSystem.ID_CALL, notification, types)
                    }.isSuccess
                }
        if (!started) stopSelf()
        return START_NOT_STICKY
    }

    private fun foregroundTypes(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (granted(Manifest.permission.RECORD_AUDIO)) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (granted(Manifest.permission.CAMERA)) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
        }
        return types
    }

    private fun granted(permission: String): Boolean = ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_CONNECTED_AT = "connectedAt"
        const val EXTRA_VIDEO = "video"
        private const val REQUEST_OPEN = 20
        private const val REQUEST_HANG_UP = 21
    }
}
