package io.github.mariokovacevic.baresipkit.internal

import io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration
import io.github.mariokovacevic.baresipkit.BaresipConfiguration
import io.github.mariokovacevic.baresipkit.BaresipContactParameter
import kotlin.time.Duration

internal class NativeEngineConfig(
    configuration: BaresipConfiguration,
) {
    @JvmField val userAgent = configuration.userAgent.cString()

    @JvmField val instanceUuid =
        configuration.instanceUuid
            .toString()
            .lowercase()
            .cString()

    @JvmField val networkInterface = configuration.networkInterface.cStringOrNull()

    @JvmField val modules = configuration.modules.cStrings()

    @JvmField val extraConfig = configuration.extraConfiguration.cStringOrNull()

    @JvmField val ipv6 = configuration.ipv6

    @JvmField val rtpPortMin = configuration.rtpPortRange.first.coerceIn(0, 65535)

    @JvmField val rtpPortMax = configuration.rtpPortRange.last.coerceIn(0, 65535)

    @JvmField val maxCalls = configuration.maxCalls.coerceAtLeast(0)

    @JvmField val logLevel = configuration.logLevel.ordinal

    @JvmField val logSipTrace = configuration.logSipTrace

    @JvmField val iceRelayOnly = configuration.iceRelayOnly

    @JvmField val videoAdaptiveBitrate = configuration.videoAdaptiveBitrate

    @JvmField val videoMinBitrate = configuration.videoMinimumBitrate.coerceAtLeast(0)

    @JvmField val holdMusicPath =
        configuration.audio.holdMusicFile
            ?.path
            .cStringOrNull()

    @JvmField val sessionExpires = configuration.sessionTimer?.wholeSeconds() ?: 0

    @JvmField val sessionMinSe = configuration.minimumSessionTimer.wholeSeconds()

    @JvmField val audioSourceModule = configuration.audio.sourceModule.cString()

    @JvmField val audioSourceDevice = configuration.audio.sourceDevice.cStringOrNull()

    @JvmField val audioPlayerModule = configuration.audio.playerModule.cString()

    @JvmField val audioPlayerDevice = configuration.audio.playerDevice.cStringOrNull()

    @JvmField val sampleRate = configuration.audio.sampleRate?.coerceAtLeast(0) ?: 0

    @JvmField val channels = configuration.audio.channels?.coerceAtLeast(0) ?: 0

    @JvmField val ptimeMs = configuration.audio.packetTime.wholeMilliseconds()

    @JvmField val jitterBufferMinMs =
        configuration.audio.jitterBufferRange.first
            .coerceAtLeast(0)

    @JvmField val jitterBufferMaxMs =
        configuration.audio.jitterBufferRange.last
            .coerceAtLeast(0)

    @JvmField val jitterBufferAdaptive = configuration.audio.adaptiveJitterBuffer

    @JvmField val audioCodecs = configuration.audio.codecs.cStrings()

    @JvmField val videoSourceModule = configuration.video.sourceModule.cString()

    @JvmField val videoSourceDevice = configuration.video.sourceDevice.cStringOrNull()

    @JvmField val videoWidth = configuration.video.width.coerceAtLeast(0)

    @JvmField val videoHeight = configuration.video.height.coerceAtLeast(0)

    @JvmField val videoFps = configuration.video.framesPerSecond.coerceAtLeast(0)

    @JvmField val videoBitrate = configuration.video.bitrate.coerceAtLeast(0)

    @JvmField val videoCodecs = configuration.video.codecs.cStrings()

    @JvmField val caPem = configuration.tls.caCertificatesPem

    @JvmField val clientCertPem = configuration.tls.clientCertificatePem

    @JvmField val pins = configuration.tls.pinnedSpkiSha256.cStrings()

    @JvmField val cipherList = configuration.tls.cipherList.cStringOrNull()

    @JvmField val tlsMinVersion = configuration.tls.minimumVersion.wire

    @JvmField val insecureSkipVerify = !configuration.tls.verifyServer
}

internal class NativeAccountConfig(
    account: BaresipAccountConfiguration,
) {
    @JvmField val aor = account.aor.cString()

    @JvmField val displayName = account.displayName.cStringOrNull()

    @JvmField val registrar = account.registrar.cStringOrNull()

    @JvmField val outboundProxy = account.outboundProxy.cStringOrNull()

    @JvmField val transport = account.transport.ordinal

    @JvmField val authUser = account.authUser.cStringOrNull()

    @JvmField val authPassword = account.authPassword.cStringOrNull()

    @JvmField val expires = account.registerExpires.wholeSeconds()

    @JvmField val sipOutbound = account.sipOutbound

    @JvmField val mediaEncryption = account.mediaEncryption.ordinal

    @JvmField val dtmfMode = account.dtmfMode.ordinal

    @JvmField val contactNames = account.contactParameters.names()

    @JvmField val contactValues = account.contactParameters.values()

    @JvmField val audioCodecs = account.audioCodecs.cStrings()

    @JvmField val videoCodecs = account.videoCodecs.cStrings()

    @JvmField val answerEarlyMedia = account.answerEarlyMedia

    @JvmField val rejectTransfers = !account.acceptTransfers

    @JvmField val rtcpMux = account.nat.rtcpMultiplexing

    @JvmField val natPinhole = account.nat.pinhole

    @JvmField val vfuInfo = account.pictureUpdateOverSipInfo

    @JvmField val incomingHeaders = account.incomingHeaders.cStrings()

    @JvmField val natMode = account.nat.mode.ordinal

    @JvmField val stunUri = account.nat.stunUri.cStringOrNull()

    @JvmField val rtpTimeoutMs = account.nat.rtpTimeout.wholeMilliseconds()

    @JvmField val turnUri =
        account.nat.turnServers
            .firstOrNull()
            ?.uri
            .cStringOrNull()

    @JvmField val turnUsername =
        account.nat.turnServers
            .firstOrNull()
            ?.username
            .cStringOrNull()

    @JvmField val turnPassword =
        account.nat.turnServers
            .firstOrNull()
            ?.password
            .cStringOrNull()
}

internal fun List<BaresipContactParameter>.names(): Array<ByteArray> = Array(size) { this[it].name.cString() }

internal fun List<BaresipContactParameter>.values(): Array<ByteArray?> = Array(size) { this[it].value.cStringOrNull() }

internal fun Duration.wholeSeconds(): Int = inWholeSeconds.coerceIn(0, Int.MAX_VALUE.toLong()).toInt()

internal fun Duration.wholeMilliseconds(): Int = inWholeMilliseconds.coerceIn(0, Int.MAX_VALUE.toLong()).toInt()
