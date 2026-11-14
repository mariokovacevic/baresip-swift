package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.BaresipDtmfMode
import io.github.mariokovacevic.baresipkit.BaresipMediaEncryption
import io.github.mariokovacevic.baresipkit.BaresipNatTraversal
import io.github.mariokovacevic.baresipkit.BaresipTransport
import kotlinx.serialization.Serializable

@Serializable
data class SipSettings(
    val domain: String = "",
    val port: String = "",
    val transport: BaresipTransport = BaresipTransport.TLS,
    val username: String = "",
    val authUser: String = "",
    val displayName: String = "",
    val outboundProxy: String = "",
    val mediaEncryption: BaresipMediaEncryption = BaresipMediaEncryption.SRTP_OPTIONAL,
    val pins: String = "",
    val natMode: BaresipNatTraversal = BaresipNatTraversal.NONE,
    val stunUri: String = "",
    val turnUri: String = "",
    val turnUser: String = "",
    val previewAudio: Boolean = true,
    val reachableInBackground: Boolean = false,
    val ringPicture: Boolean = true,
    val rtcpMux: Boolean = true,
    val pinhole: Boolean = true,
    val pictureUpdateOverInfo: Boolean = true,
    val dtmfMode: BaresipDtmfMode = BaresipDtmfMode.SIP_INFO,
    val rtpTimeoutSeconds: Int = 30,
    val sipOutbound: Boolean = false,
    val registerExpiresSeconds: Int = 600,
    val acceptTransfers: Boolean = true,
    val audioCodecs: String = "",
    val videoCodecs: String = "",
    val engine: EngineOptions = EngineOptions(),
) {
    val useIce: Boolean
        get() = natMode == BaresipNatTraversal.ICE

    val isComplete: Boolean
        get() = domain.isNotBlank() && username.isNotBlank()

    val transportName: String
        get() = transport.name.lowercase()

    val aor: String
        get() = "sip:${username.trim()}@${domain.trim()}"

    val registrar: String
        get() {
            val trimmedPort = port.trim()
            val portPart = if (trimmedPort.isEmpty()) "" else ":$trimmedPort"
            return "sip:${domain.trim()}$portPart;transport=$transportName"
        }

    val proxy: String?
        get() {
            val raw = outboundProxy.trim()
            if (raw.isEmpty()) return null
            if (raw.startsWith("sip:") || raw.startsWith("sips:")) return raw
            return "sip:$raw;transport=$transportName;lr"
        }

    val pinList: List<String>
        get() = pins.split('\n', ',', ' ').map { it.trim() }.filter { it.isNotEmpty() }

    companion object {
        fun codecList(text: String): List<String> = text.split(',', ' ', '\n').map { it.trim() }.filter { it.isNotEmpty() }

        val registrationTimes = listOf(300, 600, 3600, 86400, 604_800)

        fun durationText(seconds: Int): String =
            when {
                seconds % 86400 == 0 -> if (seconds == 86400) "1 day" else "${seconds / 86400} days"
                seconds % 3600 == 0 -> if (seconds == 3600) "1 hour" else "${seconds / 3600} hours"
                else -> "${seconds / 60} min"
            }
    }
}

@Serializable
data class EngineOptions(
    val ipv6: Boolean = true,
    val iceRelayOnly: Boolean = false,
    val videoHeight: Int = 0,
    val videoFramesPerSecond: Int = 0,
    val videoBitrateKbps: Int = 0,
    val adaptiveBitrate: Boolean = true,
) {
    companion object {
        val videoHeights = listOf(0, 240, 288, 480, 720)
        val videoFrameRates = listOf(0, 10, 15, 25, 30)
        val videoBitrates = listOf(0, 300, 600, 1000, 1500, 2500)

        fun width(height: Int): Int =
            when (height) {
                288 -> 352
                720 -> 1280
                else -> height * 4 / 3
            }
    }
}
