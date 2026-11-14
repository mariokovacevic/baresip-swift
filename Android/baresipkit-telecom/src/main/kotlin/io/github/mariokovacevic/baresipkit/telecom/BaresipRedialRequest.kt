package io.github.mariokovacevic.baresipkit.telecom

import android.content.Intent
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import java.net.URLDecoder

/**
 * A call the user asked for outside the app, for example with a tap on a `sip:` link, on a
 * contact's SIP address or on one of the app's calls in the call log of the Phone app.
 *
 * Android hands the request to the app as an [Intent] with the action [Intent.ACTION_CALL],
 * [Intent.ACTION_DIAL] or [Intent.ACTION_VIEW] and a `sip:`, `sips:` or `tel:` URI. Only
 * `ACTION_CALL` asks for the call to start at once ([callsNow]); `ACTION_DIAL` and
 * `ACTION_VIEW`, which any web page can send, ask the app to show the destination and let the user
 * start the call. Receive `ACTION_CALL` on a component that requires
 * `android.permission.CALL_PHONE`, as the Phone app and the contacts app hold it, and treat a
 * request that reached another component as one to show:
 *
 * ```kotlin
 * override fun onNewIntent(intent: Intent) {
 *     super.onNewIntent(intent)
 *     val request = BaresipRedialRequest.from(intent) ?: return
 *     if (request.callsNow && intent.component?.className == CALL_ALIAS) {
 *         lifecycleScope.launch { phone.makeCall(request.destination, video = request.video) }
 *     } else {
 *         showKeypad(request.destination)
 *     }
 * }
 * ```
 *
 * For a `sip:` or `sips:` URI the destination is the URI, for a `tel:` URI the number, which is
 * what [BaresipTelecomAdapter] gives Telecom with [io.github.mariokovacevic.baresipkit.BaresipHandleStyle.PHONE_NUMBER_WHEN_NUMERIC].
 * Whether the Phone app sends a tap in its call log to the app depends on the device; links and
 * contacts always use these intents.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipRedialRequest(
    /** The SIP URI or number to call. */
    val destination: String,
    /** Whether a video call was asked for. */
    val video: Boolean,
    /** Whether the intent asked for the call to start at once ([Intent.ACTION_CALL]) rather than to be shown. */
    val callsNow: Boolean = false,
) {
    /** Reading requests from intents. */
    companion object {
        private const val ACTION_CALL_PRIVILEGED = "android.intent.action.CALL_PRIVILEGED"
        private val calling = setOf(Intent.ACTION_CALL, ACTION_CALL_PRIVILEGED)
        private val actions = calling + setOf(Intent.ACTION_DIAL, Intent.ACTION_VIEW)
        private const val VIDEO_BITS = VideoProfile.STATE_TX_ENABLED or VideoProfile.STATE_RX_ENABLED

        /**
         * Reads the request from an intent.
         *
         * @param intent The intent the app was started or resumed with.
         * @return `null` when the intent asks for no call or names nobody to call.
         */
        fun from(intent: Intent?): BaresipRedialRequest? {
            intent ?: return null
            if (intent.action !in actions) return null
            val state = intent.getIntExtra(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, VideoProfile.STATE_AUDIO_ONLY)
            return parse(intent.action, intent.dataString, state)
        }

        internal fun parse(
            action: String?,
            uri: String?,
            videoState: Int,
        ): BaresipRedialRequest? {
            if (action !in actions || uri == null) return null
            val scheme = uri.substringBefore(':', "").lowercase()
            val rest = uri.substringAfter(':', "").removePrefix("//")
            val destination =
                when (scheme) {
                    "sip", "sips" -> decode(rest).trim().takeIf { it.isNotEmpty() }?.let { "$scheme:$it" }
                    "tel" -> decode(rest.substringBefore(';')).filterNot { it == ' ' || it == '-' || it == '(' || it == ')' }
                    else -> null
                }
            if (destination.isNullOrEmpty()) return null
            return BaresipRedialRequest(destination, videoState and VIDEO_BITS != 0, action in calling)
        }

        private fun decode(text: String): String = runCatching { URLDecoder.decode(text.replace("+", "%2B"), "UTF-8") }.getOrDefault(text)
    }
}
