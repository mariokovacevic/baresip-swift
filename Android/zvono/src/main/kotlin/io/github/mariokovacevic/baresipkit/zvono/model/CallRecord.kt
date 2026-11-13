package io.github.mariokovacevic.baresipkit.zvono.model

import kotlinx.serialization.Serializable
import java.util.UUID
import kotlin.math.roundToLong

@Serializable
data class CallRecord(
    val id: String = UUID.randomUUID().toString(),
    val uri: String,
    val name: String,
    val outgoing: Boolean,
    val video: Boolean = false,
    val startedAt: Long,
    val durationSeconds: Double? = null,
    val dtmf: String = "",
    val dtmfResult: String? = null,
    val dtmfAck: String? = null,
    val dtmfHangUp: Boolean = true,
    val snapshotFile: String? = null,
    val elsewhere: String? = null,
) {
    val user: String
        get() = SipNames.user(uri.ifEmpty { name })

    val initials: String
        get() = SipNames.initials(name)

    val dtmfRequest: DtmfRequest?
        get() = if (dtmf.isEmpty()) null else DtmfRequest(dtmf, dtmfAck.orEmpty(), dtmfHangUp)

    val kindText: String
        get() {
            val request = dtmfRequest ?: return if (video) "Video call" else "Audio call"
            return "DTMF ${request.digits}" + if (request.ack.isEmpty()) "" else ", reply ${request.ack}"
        }

    val talkTime: String?
        get() {
            val seconds = durationSeconds?.roundToLong() ?: return null
            return "%d:%02d".format(seconds / 60, seconds % 60)
        }

    companion object {
        const val LIMIT = 200

        fun of(
            row: CallRow,
            dtmf: DtmfState?,
            endedAtMillis: Long,
            snapshotFile: String?,
        ): CallRecord {
            val connected = row.connectedAtMillis
            return CallRecord(
                uri = row.remoteUri,
                name = if (row.remoteUri.isEmpty() && row.remoteName.isEmpty()) "Unknown" else row.title,
                outgoing = row.outgoing,
                video = row.sendingVideo || row.startedWithVideo,
                startedAt = row.startedAtMillis,
                durationSeconds = connected?.let { (endedAtMillis - it).coerceAtLeast(0) / 1000.0 },
                dtmf = dtmf?.request?.digits.orEmpty(),
                dtmfResult = dtmf?.let { if (it.sent) it.result else "not sent" },
                dtmfAck = dtmf?.request?.ack,
                dtmfHangUp = dtmf?.request?.hangUp ?: true,
                snapshotFile = snapshotFile,
                elsewhere = row.endedElsewhere,
            )
        }
    }
}
