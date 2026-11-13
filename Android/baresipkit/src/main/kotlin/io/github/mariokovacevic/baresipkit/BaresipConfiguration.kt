package io.github.mariokovacevic.baresipkit

import java.io.File
import java.util.UUID
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * Engine-wide settings, passed to [BaresipEngine].
 *
 * The defaults suit a typical Android VoIP app; most apps only change [userAgent] and [tls].
 */
data class BaresipConfiguration(
    /** The `User-Agent` header value. */
    val userAgent: String = "BaresipKit",
    /** The instance identifier sent as `+sip.instance` (RFC 5626). Keep it stable per install. */
    val instanceUuid: UUID = UUID.randomUUID(),
    /** The network interface to bind to, or `null` for all interfaces. */
    val networkInterface: String? = null,
    /** The baresip modules to load. */
    val modules: List<String> = DEFAULT_MODULES,
    /** Extra lines appended to the generated baresip configuration. */
    val extraConfiguration: String? = null,
    /** Whether IPv6 addresses are used. */
    val ipv6: Boolean = true,
    /** The local UDP port range for RTP. */
    val rtpPortRange: IntRange = 10000..20000,
    /** The maximum number of simultaneous calls. */
    val maxCalls: Int = 4,
    /** Audio settings. */
    val audio: BaresipAudioConfiguration = BaresipAudioConfiguration(),
    /** Video settings. */
    val video: BaresipVideoConfiguration = BaresipVideoConfiguration(),
    /** TLS settings. */
    val tls: BaresipTlsConfiguration = BaresipTlsConfiguration(),
    /** The lowest log level passed to the log handler. */
    val logLevel: BaresipLogLevel = BaresipLogLevel.INFO,
    /** Whether full SIP messages are logged, with credentials redacted. */
    val logSipTrace: Boolean = false,
    /** Whether ICE uses relayed candidates only. */
    val iceRelayOnly: Boolean = false,
    /** Whether the video bitrate follows RTCP loss reports. */
    val videoAdaptiveBitrate: Boolean = true,
    /** The lowest video bitrate, in bits per second, that adaptation goes down to. */
    val videoMinimumBitrate: Int = 150_000,
    /**
     * The SIP session timer (RFC 4028) that calls offer and accept, or `null` for none.
     *
     * Calls offer it in their INVITE and accept it from a caller that supports session timers.
     * The side that refreshes renews the session at half the interval with UPDATE, or with a
     * re-INVITE when the other side does not allow UPDATE; the other side hangs up when the
     * session is not renewed in time.
     */
    val sessionTimer: Duration? = 1800.seconds,
    /** The shortest session timer accepted, at most [sessionTimer]. */
    val minimumSessionTimer: Duration = 90.seconds,
) {
    companion object {
        /**
         * The modules loaded by default: G.711, Opus, L16, ICE, TURN, STUN, SRTP, DTLS-SRTP,
         * RTCP summaries, AAudio and the test video source. H.264 and the camera are built in.
         */
        val DEFAULT_MODULES: List<String> =
            listOf(
                "g711",
                "opus",
                "l16",
                "auconv",
                "auresamp",
                "ice",
                "turn",
                "stun",
                "srtp",
                "dtls_srtp",
                "rtcpsummary",
                "aaudio",
                "fakevideo",
            )
    }
}

/** Audio settings for the engine. */
data class BaresipAudioConfiguration(
    /** The baresip audio source module, `aaudio` on Android. */
    val sourceModule: String = "aaudio",
    /** The input device, or `null` for the default. */
    val sourceDevice: String? = null,
    /** The baresip audio player module, `aaudio` on Android. */
    val playerModule: String = "aaudio",
    /** The output device, or `null` for the default. */
    val playerDevice: String? = null,
    /** The capture and playback sample rate, or `null` to follow the codec. */
    val sampleRate: Int? = null,
    /** The number of channels, or `null` to follow the codec. */
    val channels: Int? = null,
    /** The RTP packet time offered to the peer. */
    val packetTime: Duration = 20.milliseconds,
    /** The jitter buffer range in milliseconds. */
    val jitterBufferRange: IntRange = 40..200,
    /** Whether the jitter buffer adapts within [jitterBufferRange]. */
    val adaptiveJitterBuffer: Boolean = true,
    /** Audio codecs in order of preference, as `name/rate/channels`. */
    val codecs: List<String> = DEFAULT_CODECS,
    /**
     * Music on hold: a WAV file (16-bit PCM, mono or stereo, 8 to 48 kHz) that a call put on hold
     * with [BaresipEngine.hold] plays to the other side in a loop instead of the microphone.
     * `null` sends nothing while on hold.
     *
     * The engine reads the file when it is created and fails with [BaresipError] when the file
     * is missing or in another format.
     */
    val holdMusicFile: File? = null,
) {
    companion object {
        /**
         * The codecs offered when an account configures none: Opus, G.722, then G.711 µ-law and
         * A-law. G.722 is written with its audio rate, `G722/16000/1`.
         */
        val DEFAULT_CODECS: List<String> = listOf("opus/48000/2", "G722/16000/1", "PCMU/8000/1", "PCMA/8000/1")
    }
}

/** Video settings for the engine. */
data class BaresipVideoConfiguration(
    /** The baresip video source module; `bskcamera` is the camera source, fed by `BaresipCamera` from baresipkit-video. */
    val sourceModule: String = "bskcamera",
    /** The camera, or `null` for the default front camera. */
    val sourceDevice: String? = null,
    /** The capture width in pixels. */
    val width: Int = 640,
    /** The capture height in pixels. */
    val height: Int = 480,
    /** The capture frame rate. */
    val framesPerSecond: Int = 30,
    /** The maximum encoder bitrate in bits per second. */
    val bitrate: Int = 800_000,
    /** Video codecs in order of preference. H.264 is coded by MediaCodec. */
    val codecs: List<String> = listOf("H264"),
)

/**
 * TLS settings for SIP over TLS.
 *
 * By default the server certificate is verified against the trust store of the core. Add
 * [caCertificatesPem] for a private CA or a self-signed server, and [pinnedSpkiSha256] to accept
 * only specific server keys on top of normal validation.
 */
class BaresipTlsConfiguration private constructor(
    /** Extra trusted CA certificates in PEM format. */
    val caCertificatesPem: ByteArray?,
    /** A client certificate followed by its private key, in PEM format, for mutual TLS. */
    val clientCertificatePem: ByteArray?,
    /** Base64-encoded SHA-256 hashes of accepted server SubjectPublicKeyInfo structures. */
    val pinnedSpkiSha256: List<String>,
    /** An OpenSSL cipher list, or `null` for the core's default. */
    val cipherList: String?,
    /** The lowest accepted TLS version. */
    val minimumVersion: TlsVersion,
    /** Whether the server certificate is verified. Always `true` except for [insecureSkippingServerVerification]. */
    val verifyServer: Boolean,
) {
    /**
     * Creates TLS settings that verify the server.
     *
     * @param caCertificatesPem Extra trusted CA certificates in PEM format.
     * @param clientCertificatePem A client certificate and key in PEM format.
     * @param pinnedSpkiSha256 Accepted server key hashes.
     * @param cipherList An OpenSSL cipher list.
     * @param minimumVersion The lowest accepted TLS version.
     */
    constructor(
        caCertificatesPem: ByteArray? = null,
        clientCertificatePem: ByteArray? = null,
        pinnedSpkiSha256: List<String> = emptyList(),
        cipherList: String? = null,
        minimumVersion: TlsVersion = TlsVersion.TLS_1_2,
    ) : this(caCertificatesPem, clientCertificatePem, pinnedSpkiSha256, cipherList, minimumVersion, true)

    /** A TLS protocol version. */
    enum class TlsVersion(
        internal val wire: Int,
    ) {
        /** TLS 1.2. */
        TLS_1_2(0x0303),

        /** TLS 1.3. */
        TLS_1_3(0x0304),
    }

    override fun equals(other: Any?): Boolean =
        other is BaresipTlsConfiguration &&
            caCertificatesPem.contentEquals(other.caCertificatesPem) &&
            clientCertificatePem.contentEquals(other.clientCertificatePem) &&
            pinnedSpkiSha256 == other.pinnedSpkiSha256 &&
            cipherList == other.cipherList &&
            minimumVersion == other.minimumVersion &&
            verifyServer == other.verifyServer

    override fun hashCode(): Int =
        listOf(
            caCertificatesPem?.contentHashCode(),
            clientCertificatePem?.contentHashCode(),
            pinnedSpkiSha256,
            cipherList,
            minimumVersion,
            verifyServer,
        ).hashCode()

    companion object {
        /**
         * Settings that accept any server certificate, for development against a test server.
         *
         * The engine logs a warning when it starts with these settings. They cannot be combined
         * with pins: the engine rejects pins without verification.
         */
        fun insecureSkippingServerVerification(): BaresipTlsConfiguration = BaresipTlsConfiguration(null, null, emptyList(), null, TlsVersion.TLS_1_2, false)
    }
}
