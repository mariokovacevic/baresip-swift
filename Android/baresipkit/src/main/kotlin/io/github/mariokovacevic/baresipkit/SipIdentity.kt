package io.github.mariokovacevic.baresipkit

/**
 * The user and host of a SIP or tel URI, lowercased and without scheme, port, parameters or
 * display name, for comparing who a call or message is from.
 *
 * ```kotlin
 * SipIdentity("\"Door\" <sip:100@pbx.example.com:5061;transport=tls>") == SipIdentity("sip:100@pbx.example.com")
 * ```
 */
class SipIdentity(
    uri: String,
) {
    /** The user part, or an empty string. */
    val user: String

    /** The host without the port, or an empty string. */
    val host: String

    init {
        var value = uri.trim().lowercase()
        val open = value.indexOf('<')
        val close = value.lastIndexOf('>')
        if (open >= 0 && close > open) value = value.substring(open + 1, close)
        for (scheme in listOf("sips:", "sip:", "tel:")) {
            if (value.startsWith(scheme)) value = value.removePrefix(scheme)
        }
        val end = value.indexOfFirst { it == ';' || it == '?' }
        if (end >= 0) value = value.substring(0, end)
        val parts = value.split("@", limit = 2)
        user = parts.firstOrNull().orEmpty()
        host = if (parts.size == 2) hostWithoutPort(parts[1]) else ""
    }

    /** `true` when the URI had neither a user nor a host. */
    val isEmpty: Boolean
        get() = user.isEmpty() && host.isEmpty()

    /** The user part when it is a phone number, digits with an optional leading `+`. */
    val phoneNumber: String?
        get() {
            val digits = user.removePrefix("+")
            return user.takeIf { digits.isNotEmpty() && digits.all { it in '0'..'9' } }
        }

    override fun equals(other: Any?): Boolean = other is SipIdentity && user == other.user && host == other.host

    override fun hashCode(): Int = 31 * user.hashCode() + host.hashCode()

    override fun toString(): String = if (host.isEmpty()) user else "$user@$host"

    private companion object {
        fun hostWithoutPort(hostAndPort: String): String {
            if (hostAndPort.startsWith("[")) {
                val close = hostAndPort.indexOf(']')
                if (close >= 0) return hostAndPort.substring(0, close + 1)
            }
            return hostAndPort.split(":").firstOrNull() ?: hostAndPort
        }
    }
}

/** How a system call adapter identifies the other side of a call to the system. */
enum class BaresipHandleStyle {
    /** Every caller is shown with the SIP URI. */
    SIP_URI,

    /**
     * A caller whose user part is a phone number, such as `100` or `+15555550100`, is reported as
     * a `tel:` address, so the system can show a contact with that number. Other callers keep the
     * SIP URI.
     */
    PHONE_NUMBER_WHEN_NUMERIC,
}

/**
 * Carries out the user's call actions through a system call interface, such as Telecom.
 *
 * With Telecom, an app must not answer, end, hold or mute a call on the engine directly: the
 * system would show a different state. A controller takes these actions instead and performs
 * them on the engine once the system agrees. `BaresipTelecomAdapter` is a controller.
 */
interface BaresipCallController {
    /** Whether the call is known to the system call interface, so its actions go through the controller. */
    fun controls(call: BaresipCallID): Boolean

    /** Places a call through the system and returns the engine call once the engine has placed it. */
    suspend fun placeCall(
        destination: String,
        video: Boolean,
    ): BaresipCallID

    /** Answers a call through the system. */
    suspend fun answer(
        call: BaresipCallID,
        video: Boolean,
    )

    /** Ends or declines a call through the system. */
    suspend fun end(call: BaresipCallID)

    /** Holds or resumes a call through the system. */
    suspend fun setOnHold(
        onHold: Boolean,
        call: BaresipCallID,
    )

    /** Mutes or unmutes a call through the system. */
    suspend fun setMuted(
        muted: Boolean,
        call: BaresipCallID,
    )

    /**
     * Adds an observer called after a call was muted or unmuted through the controller, also from
     * the system. The engine reports no event for muting, so this keeps a mute button in step.
     */
    fun addMuteObserver(observer: (BaresipCallID, Boolean) -> Unit)
}
