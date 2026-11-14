package io.github.mariokovacevic.baresipkit.telecom

import io.github.mariokovacevic.baresipkit.BaresipConfigurationDsl
import io.github.mariokovacevic.baresipkit.BaresipHandleStyle
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * Settings for [BaresipTelecomAdapter].
 *
 * Create the settings with the [BaresipTelecomConfiguration] function and change a copy with
 * [copy]:
 *
 * ```kotlin
 * val configuration = BaresipTelecomConfiguration { callUuidHeader = "X-Call-UUID" }
 * ```
 *
 * Settings added in a later release get a default that keeps the earlier behaviour.
 */
class BaresipTelecomConfiguration private constructor(
    builder: Builder,
) {
    /** Whether calls may have video. */
    val supportsVideo: Boolean = builder.supportsVideo

    /** How long a call reported from a push waits for its INVITE before it is ended. */
    val pushInviteTimeout: Duration = builder.pushInviteTimeout

    /** Whether answering a video call sends your camera. The caller's video is received either way. */
    val sendsCameraOnAnswer: Boolean = builder.sendsCameraOnAnswer

    /**
     * Whether a call reported from a push that names no caller is bound to the next INVITE,
     * whoever sends it. Use `false` when every push carries the caller's SIP URI.
     */
    val matchesPushWithoutCaller: Boolean = builder.matchesPushWithoutCaller

    /**
     * The name of an INVITE header that carries the UUID of the call, the one the server also puts
     * in the push. A call reported from a push with a UUID is then bound to the INVITE with the
     * same UUID and to no other.
     */
    val callUuidHeader: String? = builder.callUuidHeader

    /** How callers are identified to the system. */
    val handleStyle: BaresipHandleStyle = builder.handleStyle

    /**
     * How long an action waits for Telecom before it fails with
     * [BaresipTelecomException.Reason.ACTION_TIMED_OUT]. A call whose start times out is given up:
     * if Telecom adds it later, it is disconnected at once.
     */
    val actionTimeout: Duration = builder.actionTimeout

    /** Returns a copy of these settings with the changes made in [block]. */
    fun copy(block: Builder.() -> Unit): BaresipTelecomConfiguration = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean = other is BaresipTelecomConfiguration && values() == other.values()

    override fun hashCode(): Int = values().hashCode()

    override fun toString(): String =
        "BaresipTelecomConfiguration(supportsVideo=$supportsVideo, pushInviteTimeout=$pushInviteTimeout, " +
            "sendsCameraOnAnswer=$sendsCameraOnAnswer, matchesPushWithoutCaller=$matchesPushWithoutCaller, " +
            "callUuidHeader=$callUuidHeader, handleStyle=$handleStyle, actionTimeout=$actionTimeout)"

    private fun values(): List<Any?> =
        listOf(
            supportsVideo,
            pushInviteTimeout,
            sendsCameraOnAnswer,
            matchesPushWithoutCaller,
            callUuidHeader,
            handleStyle,
            actionTimeout,
        )

    /** Collects the settings of a [BaresipTelecomConfiguration]; see the [BaresipTelecomConfiguration] function. */
    @BaresipConfigurationDsl
    class Builder() {
        /** Whether calls may have video. On by default. */
        var supportsVideo: Boolean = true

        /** How long a call reported from a push waits for its INVITE before it is ended, 30 seconds by default. */
        var pushInviteTimeout: Duration = 30.seconds

        /** Whether answering a video call sends your camera. On by default. */
        var sendsCameraOnAnswer: Boolean = true

        /** Whether a call reported from a push that names no caller is bound to the next INVITE. On by default. */
        var matchesPushWithoutCaller: Boolean = true

        /** The name of an INVITE header that carries the UUID of the call, or `null` for none. */
        var callUuidHeader: String? = null

        /** How callers are identified to the system, [BaresipHandleStyle.SIP_URI] by default. */
        var handleStyle: BaresipHandleStyle = BaresipHandleStyle.SIP_URI

        /** How long an action waits for Telecom before it fails, 10 seconds by default. */
        var actionTimeout: Duration = 10.seconds

        /** Starts from the settings of [configuration]. */
        constructor(configuration: BaresipTelecomConfiguration) : this() {
            supportsVideo = configuration.supportsVideo
            pushInviteTimeout = configuration.pushInviteTimeout
            sendsCameraOnAnswer = configuration.sendsCameraOnAnswer
            matchesPushWithoutCaller = configuration.matchesPushWithoutCaller
            callUuidHeader = configuration.callUuidHeader
            handleStyle = configuration.handleStyle
            actionTimeout = configuration.actionTimeout
        }

        /** Creates the settings. */
        fun build(): BaresipTelecomConfiguration = BaresipTelecomConfiguration(this)
    }
}

/** Creates Telecom adapter settings: the defaults, changed by [block]. */
fun BaresipTelecomConfiguration(block: BaresipTelecomConfiguration.Builder.() -> Unit = {}): BaresipTelecomConfiguration =
    BaresipTelecomConfiguration.Builder().apply(block).build()
