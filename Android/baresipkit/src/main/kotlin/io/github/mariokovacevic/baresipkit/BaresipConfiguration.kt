package io.github.mariokovacevic.baresipkit

import io.github.mariokovacevic.baresipkit.internal.describe
import io.github.mariokovacevic.baresipkit.internal.redacted
import io.github.mariokovacevic.baresipkit.internal.sizeDescription
import java.io.File
import java.util.UUID
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * Engine-wide settings, passed to [BaresipEngine].
 *
 * Create the settings with the [BaresipConfiguration] function and change a copy with [copy]. The
 * only required value is the [instanceUuid] the app stored for this installation:
 *
 * ```kotlin
 * val configuration =
 *     BaresipConfiguration(instanceUuid = settings.instanceUuid) {
 *         userAgent = "MyApp/1.0"
 *         tls { caCertificatesPem = caBundle }
 *     }
 * val withoutIpv6 = configuration.copy { ipv6 = false }
 * ```
 *
 * The defaults suit a typical Android VoIP app; most apps only change [userAgent] and [tls].
 * Settings added in a later release get a default that keeps the earlier behaviour.
 */
public class BaresipConfiguration private constructor(
    builder: Builder,
) {
    /** The `User-Agent` header value. */
    public val userAgent: String = builder.userAgent

    /**
     * The instance identifier sent as `+sip.instance` (RFC 5626). The registrar uses it to tell
     * that a REGISTER comes from the same device as before and replaces that device's `Contact`
     * binding instead of adding one.
     *
     * The app creates it once per installation, for example with `UUID.randomUUID()`, persists it
     * and passes the stored value on every launch. A new value on each launch leaves a stale binding
     * on the registrar for every earlier launch until it expires.
     */
    public val instanceUuid: UUID = builder.instanceUuid

    /** The network interface to bind to, or `null` for all interfaces. */
    public val networkInterface: String? = builder.networkInterface

    /** The baresip modules to load. */
    public val modules: List<String> = builder.modules

    /** Extra lines appended to the generated baresip configuration. */
    public val extraConfiguration: String? = builder.extraConfiguration

    /** Whether IPv6 addresses are used. */
    public val ipv6: Boolean = builder.ipv6

    /** The local UDP port range for RTP. */
    public val rtpPortRange: IntRange = builder.rtpPortRange

    /** The maximum number of simultaneous calls. */
    public val maxCalls: Int = builder.maxCalls

    /** Audio settings. */
    public val audio: BaresipAudioConfiguration = builder.audio

    /** Video settings. */
    public val video: BaresipVideoConfiguration = builder.video

    /** TLS settings. */
    public val tls: BaresipTlsConfiguration = builder.tls

    /** The lowest log level passed to the log handler. */
    public val logLevel: BaresipLogLevel = builder.logLevel

    /** Whether full SIP messages are logged, with credentials redacted. */
    public val logSipTrace: Boolean = builder.logSipTrace

    /** Whether ICE uses relayed candidates only. */
    public val iceRelayOnly: Boolean = builder.iceRelayOnly

    /** Whether the video bitrate follows RTCP loss reports. */
    public val videoAdaptiveBitrate: Boolean = builder.videoAdaptiveBitrate

    /** The lowest video bitrate, in bits per second, that adaptation goes down to. */
    public val videoMinimumBitrate: Int = builder.videoMinimumBitrate

    /**
     * The SIP session timer (RFC 4028) that calls offer and accept, or `null` for none.
     *
     * Calls offer it in their INVITE and accept it from a caller that supports session timers.
     * The side that refreshes renews the session at half the interval with UPDATE, or with a
     * re-INVITE when the other side does not allow UPDATE; the other side hangs up when the
     * session is not renewed in time.
     */
    public val sessionTimer: Duration? = builder.sessionTimer

    /** The shortest session timer accepted, at most [sessionTimer] and at least 90 seconds (RFC 4028). */
    public val minimumSessionTimer: Duration = builder.minimumSessionTimer

    /** Returns a copy of these settings with the changes made in [block]. */
    public fun copy(block: Builder.() -> Unit): BaresipConfiguration = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean = other is BaresipConfiguration && values() == other.values()

    override fun hashCode(): Int = values().hashCode()

    override fun toString(): String =
        describe(
            "BaresipConfiguration",
            "userAgent" to userAgent,
            "instanceUuid" to instanceUuid,
            "networkInterface" to networkInterface,
            "modules" to modules,
            "extraConfiguration" to extraConfiguration,
            "ipv6" to ipv6,
            "rtpPortRange" to rtpPortRange,
            "maxCalls" to maxCalls,
            "audio" to audio,
            "video" to video,
            "tls" to tls,
            "logLevel" to logLevel,
            "logSipTrace" to logSipTrace,
            "iceRelayOnly" to iceRelayOnly,
            "videoAdaptiveBitrate" to videoAdaptiveBitrate,
            "videoMinimumBitrate" to videoMinimumBitrate,
            "sessionTimer" to sessionTimer,
            "minimumSessionTimer" to minimumSessionTimer,
        )

    private fun values(): List<Any?> =
        listOf(
            userAgent,
            instanceUuid,
            networkInterface,
            modules,
            extraConfiguration,
            ipv6,
            rtpPortRange,
            maxCalls,
            audio,
            video,
            tls,
            logLevel,
            logSipTrace,
            iceRelayOnly,
            videoAdaptiveBitrate,
            videoMinimumBitrate,
            sessionTimer,
            minimumSessionTimer,
        )

    /** Collects the settings of a [BaresipConfiguration]; see the [BaresipConfiguration] function. */
    @BaresipConfigurationDsl
    public class Builder(
        /** The persisted instance identifier of this installation; see [BaresipConfiguration.instanceUuid]. */
        public var instanceUuid: UUID,
    ) {
        /** The `User-Agent` header value. */
        public var userAgent: String = "BaresipKit"

        /** The network interface to bind to, or `null` for all interfaces. */
        public var networkInterface: String? = null

        /** The baresip modules to load, [DEFAULT_MODULES] by default. */
        public var modules: List<String> = DEFAULT_MODULES

        /** Extra lines appended to the generated baresip configuration. */
        public var extraConfiguration: String? = null

        /** Whether IPv6 addresses are used. On by default. */
        public var ipv6: Boolean = true

        /** The local UDP port range for RTP, 10000 to 20000 by default. */
        public var rtpPortRange: IntRange = 10000..20000

        /** The maximum number of simultaneous calls, 4 by default. */
        public var maxCalls: Int = 4

        /** Audio settings. */
        public var audio: BaresipAudioConfiguration = BaresipAudioConfiguration()

        /** Video settings. */
        public var video: BaresipVideoConfiguration = BaresipVideoConfiguration()

        /** TLS settings. */
        public var tls: BaresipTlsConfiguration = BaresipTlsConfiguration()

        /** The lowest log level passed to the log handler, [BaresipLogLevel.INFO] by default. */
        public var logLevel: BaresipLogLevel = BaresipLogLevel.INFO

        /** Whether full SIP messages are logged, with credentials redacted. Off by default. */
        public var logSipTrace: Boolean = false

        /** Whether ICE uses relayed candidates only. Off by default. */
        public var iceRelayOnly: Boolean = false

        /** Whether the video bitrate follows RTCP loss reports. On by default. */
        public var videoAdaptiveBitrate: Boolean = true

        /** The lowest video bitrate, in bits per second, that adaptation goes down to. */
        public var videoMinimumBitrate: Int = 150_000

        /** The SIP session timer that calls offer and accept, or `null` for none; see [BaresipConfiguration.sessionTimer]. */
        public var sessionTimer: Duration? = 1800.seconds

        /** The shortest session timer accepted, at most [sessionTimer] and at least 90 seconds (RFC 4028). */
        public var minimumSessionTimer: Duration = 90.seconds

        /** Starts from the settings of [configuration]. */
        public constructor(configuration: BaresipConfiguration) : this(configuration.instanceUuid) {
            userAgent = configuration.userAgent
            networkInterface = configuration.networkInterface
            modules = configuration.modules
            extraConfiguration = configuration.extraConfiguration
            ipv6 = configuration.ipv6
            rtpPortRange = configuration.rtpPortRange
            maxCalls = configuration.maxCalls
            audio = configuration.audio
            video = configuration.video
            tls = configuration.tls
            logLevel = configuration.logLevel
            logSipTrace = configuration.logSipTrace
            iceRelayOnly = configuration.iceRelayOnly
            videoAdaptiveBitrate = configuration.videoAdaptiveBitrate
            videoMinimumBitrate = configuration.videoMinimumBitrate
            sessionTimer = configuration.sessionTimer
            minimumSessionTimer = configuration.minimumSessionTimer
        }

        /** Changes the [audio] settings. */
        public fun audio(block: BaresipAudioConfiguration.Builder.() -> Unit) {
            audio = audio.copy(block)
        }

        /** Changes the [video] settings. */
        public fun video(block: BaresipVideoConfiguration.Builder.() -> Unit) {
            video = video.copy(block)
        }

        /** Changes the [tls] settings. */
        public fun tls(block: BaresipTlsConfiguration.Builder.() -> Unit) {
            tls = tls.copy(block)
        }

        /** Creates the settings. */
        public fun build(): BaresipConfiguration = BaresipConfiguration(this)
    }

    public companion object {
        /**
         * The modules loaded by default: G.711, Opus, L16, ICE, TURN, STUN, SRTP, DTLS-SRTP,
         * RTCP summaries, AAudio and the test video source. H.264 and the camera are built in.
         */
        public val DEFAULT_MODULES: List<String> =
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

/**
 * Creates engine-wide settings: the defaults, changed by [block].
 *
 * @param instanceUuid The instance identifier the app persisted for this installation; see
 *   [BaresipConfiguration.instanceUuid].
 */
public fun BaresipConfiguration(
    instanceUuid: UUID,
    block: BaresipConfiguration.Builder.() -> Unit = {},
): BaresipConfiguration = BaresipConfiguration.Builder(instanceUuid).apply(block).build()

/**
 * Audio settings for the engine, part of [BaresipConfiguration].
 *
 * Create them with the [BaresipAudioConfiguration] function or with
 * [BaresipConfiguration.Builder.audio].
 */
public class BaresipAudioConfiguration private constructor(
    builder: Builder,
) {
    /** The baresip audio source module, `aaudio` on Android. */
    public val sourceModule: String = builder.sourceModule

    /** The input device, or `null` for the default. */
    public val sourceDevice: String? = builder.sourceDevice

    /** The baresip audio player module, `aaudio` on Android. */
    public val playerModule: String = builder.playerModule

    /** The output device, or `null` for the default. */
    public val playerDevice: String? = builder.playerDevice

    /** The capture and playback sample rate, or `null` to follow the codec. */
    public val sampleRate: Int? = builder.sampleRate

    /** The number of channels, or `null` to follow the codec. */
    public val channels: Int? = builder.channels

    /** The RTP packet time offered to the peer. */
    public val packetTime: Duration = builder.packetTime

    /** The jitter buffer range in milliseconds. */
    public val jitterBufferRange: IntRange = builder.jitterBufferRange

    /** Whether the jitter buffer adapts within [jitterBufferRange]. */
    public val adaptiveJitterBuffer: Boolean = builder.adaptiveJitterBuffer

    /** Audio codecs in order of preference, as `name/rate/channels`. */
    public val codecs: List<String> = builder.codecs

    /**
     * Music on hold: a WAV file (16-bit PCM, mono or stereo, 8 to 48 kHz) that a call put on hold
     * with [BaresipEngine.hold] plays to the other side in a loop instead of the microphone.
     * `null` sends nothing while on hold.
     *
     * The engine reads the file when it is created and fails with [BaresipError] when the file
     * is missing or in another format.
     */
    public val holdMusicFile: File? = builder.holdMusicFile

    /** Returns a copy of these settings with the changes made in [block]. */
    public fun copy(block: Builder.() -> Unit): BaresipAudioConfiguration = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean = other is BaresipAudioConfiguration && values() == other.values()

    override fun hashCode(): Int = values().hashCode()

    override fun toString(): String =
        describe(
            "BaresipAudioConfiguration",
            "sourceModule" to sourceModule,
            "sourceDevice" to sourceDevice,
            "playerModule" to playerModule,
            "playerDevice" to playerDevice,
            "sampleRate" to sampleRate,
            "channels" to channels,
            "packetTime" to packetTime,
            "jitterBufferRange" to jitterBufferRange,
            "adaptiveJitterBuffer" to adaptiveJitterBuffer,
            "codecs" to codecs,
            "holdMusicFile" to holdMusicFile,
        )

    private fun values(): List<Any?> =
        listOf(
            sourceModule,
            sourceDevice,
            playerModule,
            playerDevice,
            sampleRate,
            channels,
            packetTime,
            jitterBufferRange,
            adaptiveJitterBuffer,
            codecs,
            holdMusicFile,
        )

    /** Collects the settings of a [BaresipAudioConfiguration]; see the [BaresipAudioConfiguration] function. */
    @BaresipConfigurationDsl
    public class Builder() {
        /** The baresip audio source module, `aaudio` by default. */
        public var sourceModule: String = "aaudio"

        /** The input device, or `null` for the default. */
        public var sourceDevice: String? = null

        /** The baresip audio player module, `aaudio` by default. */
        public var playerModule: String = "aaudio"

        /** The output device, or `null` for the default. */
        public var playerDevice: String? = null

        /** The capture and playback sample rate, or `null` to follow the codec. */
        public var sampleRate: Int? = null

        /** The number of channels, or `null` to follow the codec. */
        public var channels: Int? = null

        /** The RTP packet time offered to the peer, 20 ms by default. */
        public var packetTime: Duration = 20.milliseconds

        /** The jitter buffer range in milliseconds, 40 to 200 by default. */
        public var jitterBufferRange: IntRange = 40..200

        /** Whether the jitter buffer adapts within [jitterBufferRange]. On by default. */
        public var adaptiveJitterBuffer: Boolean = true

        /** Audio codecs in order of preference, as `name/rate/channels`; [DEFAULT_CODECS] by default. */
        public var codecs: List<String> = DEFAULT_CODECS

        /** Music on hold, or `null` to send nothing while on hold; see [BaresipAudioConfiguration.holdMusicFile]. */
        public var holdMusicFile: File? = null

        /** Starts from the settings of [configuration]. */
        public constructor(configuration: BaresipAudioConfiguration) : this() {
            sourceModule = configuration.sourceModule
            sourceDevice = configuration.sourceDevice
            playerModule = configuration.playerModule
            playerDevice = configuration.playerDevice
            sampleRate = configuration.sampleRate
            channels = configuration.channels
            packetTime = configuration.packetTime
            jitterBufferRange = configuration.jitterBufferRange
            adaptiveJitterBuffer = configuration.adaptiveJitterBuffer
            codecs = configuration.codecs
            holdMusicFile = configuration.holdMusicFile
        }

        /** Creates the settings. */
        public fun build(): BaresipAudioConfiguration = BaresipAudioConfiguration(this)
    }

    public companion object {
        /**
         * The codecs offered when an account configures none: Opus, G.722, then G.711 µ-law and
         * A-law. G.722 is written with its audio rate, `G722/16000/1`.
         */
        public val DEFAULT_CODECS: List<String> = listOf("opus/48000/2", "G722/16000/1", "PCMU/8000/1", "PCMA/8000/1")
    }
}

/** Creates audio settings: the defaults, changed by [block]. */
public fun BaresipAudioConfiguration(block: BaresipAudioConfiguration.Builder.() -> Unit = {}): BaresipAudioConfiguration =
    BaresipAudioConfiguration.Builder().apply(block).build()

/**
 * Video settings for the engine, part of [BaresipConfiguration].
 *
 * Create them with the [BaresipVideoConfiguration] function or with
 * [BaresipConfiguration.Builder.video].
 */
public class BaresipVideoConfiguration private constructor(
    builder: Builder,
) {
    /** The baresip video source module; `bskcamera` is the camera source, fed by `BaresipCamera` from baresipkit-video. */
    public val sourceModule: String = builder.sourceModule

    /** The camera, or `null` for the default front camera. */
    public val sourceDevice: String? = builder.sourceDevice

    /** The capture width in pixels. */
    public val width: Int = builder.width

    /** The capture height in pixels. */
    public val height: Int = builder.height

    /** The capture frame rate. */
    public val framesPerSecond: Int = builder.framesPerSecond

    /** The maximum encoder bitrate in bits per second. */
    public val bitrate: Int = builder.bitrate

    /** Video codecs in order of preference. H.264 is coded by MediaCodec. */
    public val codecs: List<String> = builder.codecs

    /** Returns a copy of these settings with the changes made in [block]. */
    public fun copy(block: Builder.() -> Unit): BaresipVideoConfiguration = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean = other is BaresipVideoConfiguration && values() == other.values()

    override fun hashCode(): Int = values().hashCode()

    override fun toString(): String =
        describe(
            "BaresipVideoConfiguration",
            "sourceModule" to sourceModule,
            "sourceDevice" to sourceDevice,
            "width" to width,
            "height" to height,
            "framesPerSecond" to framesPerSecond,
            "bitrate" to bitrate,
            "codecs" to codecs,
        )

    private fun values(): List<Any?> = listOf(sourceModule, sourceDevice, width, height, framesPerSecond, bitrate, codecs)

    /** Collects the settings of a [BaresipVideoConfiguration]; see the [BaresipVideoConfiguration] function. */
    @BaresipConfigurationDsl
    public class Builder() {
        /** The baresip video source module, `bskcamera` by default. */
        public var sourceModule: String = "bskcamera"

        /** The camera, or `null` for the default front camera. */
        public var sourceDevice: String? = null

        /** The capture width in pixels, 640 by default. */
        public var width: Int = 640

        /** The capture height in pixels, 480 by default. */
        public var height: Int = 480

        /** The capture frame rate, 30 by default. */
        public var framesPerSecond: Int = 30

        /** The maximum encoder bitrate in bits per second, 800 000 by default. */
        public var bitrate: Int = 800_000

        /** Video codecs in order of preference, H.264 by default. */
        public var codecs: List<String> = listOf("H264")

        /** Starts from the settings of [configuration]. */
        public constructor(configuration: BaresipVideoConfiguration) : this() {
            sourceModule = configuration.sourceModule
            sourceDevice = configuration.sourceDevice
            width = configuration.width
            height = configuration.height
            framesPerSecond = configuration.framesPerSecond
            bitrate = configuration.bitrate
            codecs = configuration.codecs
        }

        /** Creates the settings. */
        public fun build(): BaresipVideoConfiguration = BaresipVideoConfiguration(this)
    }
}

/** Creates video settings: the defaults, changed by [block]. */
public fun BaresipVideoConfiguration(block: BaresipVideoConfiguration.Builder.() -> Unit = {}): BaresipVideoConfiguration =
    BaresipVideoConfiguration.Builder().apply(block).build()

/**
 * TLS settings for SIP over TLS, part of [BaresipConfiguration].
 *
 * The server certificate is always verified: against the trust store of the core by default, or
 * against [caCertificatesPem] for a private CA or a self-signed server. Add [pinnedSpkiSha256] to
 * accept only specific server keys on top of that validation. There is no setting that accepts any
 * certificate; a test server needs its CA in [caCertificatesPem].
 *
 * Create the settings with the [BaresipTlsConfiguration] function or with
 * [BaresipConfiguration.Builder.tls]. [toString] does not show the client certificate and key.
 */
public class BaresipTlsConfiguration private constructor(
    builder: Builder,
) {
    /** Extra trusted CA certificates in PEM format. */
    public val caCertificatesPem: ByteArray? = builder.caCertificatesPem

    /** A client certificate followed by its private key, in PEM format, for mutual TLS. */
    public val clientCertificatePem: ByteArray? = builder.clientCertificatePem

    /** Base64-encoded SHA-256 hashes of accepted server SubjectPublicKeyInfo structures. */
    public val pinnedSpkiSha256: List<String> = builder.pinnedSpkiSha256

    /** An OpenSSL cipher list, or `null` for the core's default. */
    public val cipherList: String? = builder.cipherList

    /** The lowest accepted TLS version. */
    public val minimumVersion: TlsVersion = builder.minimumVersion

    /** A TLS protocol version. */
    public enum class TlsVersion(
        internal val wire: Int,
    ) {
        /** TLS 1.2. */
        TLS_1_2(0x0303),

        /** TLS 1.3. */
        TLS_1_3(0x0304),
    }

    /** Returns a copy of these settings with the changes made in [block]. */
    public fun copy(block: Builder.() -> Unit): BaresipTlsConfiguration = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean =
        other is BaresipTlsConfiguration &&
            caCertificatesPem.contentEquals(other.caCertificatesPem) &&
            clientCertificatePem.contentEquals(other.clientCertificatePem) &&
            pinnedSpkiSha256 == other.pinnedSpkiSha256 &&
            cipherList == other.cipherList &&
            minimumVersion == other.minimumVersion

    override fun hashCode(): Int =
        listOf(
            caCertificatesPem?.contentHashCode(),
            clientCertificatePem?.contentHashCode(),
            pinnedSpkiSha256,
            cipherList,
            minimumVersion,
        ).hashCode()

    override fun toString(): String =
        describe(
            "BaresipTlsConfiguration",
            "caCertificatesPem" to caCertificatesPem.sizeDescription(),
            "clientCertificatePem" to redacted(clientCertificatePem),
            "pinnedSpkiSha256" to pinnedSpkiSha256,
            "cipherList" to cipherList,
            "minimumVersion" to minimumVersion,
        )

    /** Collects the settings of a [BaresipTlsConfiguration]; see the [BaresipTlsConfiguration] function. */
    @BaresipConfigurationDsl
    public class Builder() {
        /** Extra trusted CA certificates in PEM format, or `null` for the core's trust store only. */
        public var caCertificatesPem: ByteArray? = null

        /** A client certificate followed by its private key, in PEM format, for mutual TLS. */
        public var clientCertificatePem: ByteArray? = null

        /** Base64-encoded SHA-256 hashes of accepted server SubjectPublicKeyInfo structures; empty for no pinning. */
        public var pinnedSpkiSha256: List<String> = emptyList()

        /** An OpenSSL cipher list, or `null` for the core's default. */
        public var cipherList: String? = null

        /** The lowest accepted TLS version, [TlsVersion.TLS_1_2] by default. */
        public var minimumVersion: TlsVersion = TlsVersion.TLS_1_2

        /** Starts from the settings of [configuration]. */
        public constructor(configuration: BaresipTlsConfiguration) : this() {
            caCertificatesPem = configuration.caCertificatesPem
            clientCertificatePem = configuration.clientCertificatePem
            pinnedSpkiSha256 = configuration.pinnedSpkiSha256
            cipherList = configuration.cipherList
            minimumVersion = configuration.minimumVersion
        }

        /** Creates the settings. */
        public fun build(): BaresipTlsConfiguration = BaresipTlsConfiguration(this)
    }
}

/** Creates TLS settings: the defaults, changed by [block]. */
public fun BaresipTlsConfiguration(block: BaresipTlsConfiguration.Builder.() -> Unit = {}): BaresipTlsConfiguration =
    BaresipTlsConfiguration.Builder().apply(block).build()
