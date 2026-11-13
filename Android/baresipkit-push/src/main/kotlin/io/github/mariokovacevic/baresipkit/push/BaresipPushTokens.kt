package io.github.mariokovacevic.baresipkit.push

import io.github.mariokovacevic.baresipkit.BaresipContactParameter

/**
 * The push token of an app, encoded as `Contact` header parameters for the registrar.
 *
 * The parameters follow the format push-capable SIP servers such as Flexisip and Kamailio's push
 * module use: `app-id`, `pn-type`, `pn-tok`, `pn-silent`, `pn-timeout` and an optional
 * `pn-channel`, the same names as on iOS with the Firebase token in `pn-tok`.
 */
data class BaresipPushTokens(
    /** The app's package name, sent as `app-id`. */
    val appId: String,
    /** The Firebase Cloud Messaging registration token. */
    val token: String? = null,
    /** The push platform, sent as `pn-type`. */
    val platform: String = "firebase",
    /** Whether the server should send data-only pushes, sent as `pn-silent`. */
    val silent: Boolean = true,
    /** The push timeout the server should use, sent as `pn-timeout`. */
    val timeout: Int = 0,
    /** An optional channel, sent as `pn-channel`. */
    val channel: String? = null,
) {
    /** The `Contact` parameters for `BaresipEngine.updateContactParameters`. */
    val contactParameters: List<BaresipContactParameter>
        get() =
            buildList {
                add(BaresipContactParameter("app-id", appId))
                add(BaresipContactParameter("pn-type", platform))
                token?.takeIf { it.isNotEmpty() }?.let { add(BaresipContactParameter("pn-tok", it)) }
                add(BaresipContactParameter("pn-silent", if (silent) "1" else "0"))
                add(BaresipContactParameter("pn-timeout", timeout.toString()))
                channel?.let { add(BaresipContactParameter("pn-channel", it)) }
            }

    internal fun mergedContactParameters(additional: List<BaresipContactParameter>): List<BaresipContactParameter> {
        val push = contactParameters
        val names = push.map { it.name.lowercase() }.toSet()
        return push + additional.filter { it.name.lowercase() !in names }
    }
}

/** A call announced by a push message: the payload keys `from`, `name`, `video` and `uuid`. */
data class BaresipPushCall(
    /** The caller's SIP URI, if the push names one. */
    val remoteUri: String?,
    /** The caller's name to show. */
    val displayName: String?,
    /** Whether the call is a video call. */
    val hasVideo: Boolean,
    /** The call's UUID, the one the INVITE also carries, if the push names one. */
    val uuid: java.util.UUID?,
) {
    companion object {
        /**
         * Reads a call from the data of a push message, as `RemoteMessage.data` delivers it.
         * Returns `null` for a message that announces no call.
         */
        fun from(data: Map<String, String>): BaresipPushCall? {
            if (data.isEmpty() || data["type"]?.let { it != "call" } == true) return null
            if (!data.containsKey("from") && !data.containsKey("uuid")) return null
            return BaresipPushCall(
                remoteUri = data["from"]?.takeIf { it.isNotBlank() },
                displayName = data["name"]?.takeIf { it.isNotBlank() },
                hasVideo = data["video"]?.lowercase() in setOf("1", "true", "yes"),
                uuid = data["uuid"]?.let { runCatching { java.util.UUID.fromString(it.trim()) }.getOrNull() },
            )
        }
    }
}
