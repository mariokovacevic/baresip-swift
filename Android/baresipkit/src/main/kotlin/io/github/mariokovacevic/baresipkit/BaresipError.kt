package io.github.mariokovacevic.baresipkit

/**
 * An error thrown by BaresipKit.
 *
 * [code] tells what kind of failure happened. SIP failures also carry the response code and
 * reason phrase, and [detail] holds a human-readable explanation from the core.
 *
 * ```kotlin
 * try {
 *     engine.hold(call)
 * } catch (error: BaresipError) {
 *     if (error.code == BaresipError.Code.NOT_FOUND) println("The call has already ended")
 * }
 * ```
 */
class BaresipError(
    /** The category of the failure. */
    val code: Code,
    /** The underlying POSIX `errno`, or `0` when there is none. */
    val systemErrno: Int = 0,
    /** The SIP response code when the failure came from a SIP transaction. */
    val sipStatus: Int? = null,
    /** The SIP reason phrase, or an empty string. */
    val sipReason: String = "",
    /** A human-readable explanation, or an empty string. */
    val detail: String = "",
    /**
     * For an incoming call that ended while it rang, whether another device answered or
     * declined it, as the `Reason` header of the server's CANCEL said (RFC 3326); `null`
     * otherwise. [sipStatus] and [sipReason] then hold the header's cause and text.
     */
    val endReason: BaresipCallEndReason? = null,
) : Exception() {
    /** `true` unless [code] is [Code.OK]. */
    val isFailure: Boolean
        get() = code != Code.OK

    override val message: String
        get() =
            buildList {
                add(code.name)
                sipStatus?.let { add("SIP $it $sipReason".trimEnd()) }
                endReason?.let { add(it.name) }
                if (detail.isNotEmpty()) add(detail)
            }.joinToString(": ")

    override fun equals(other: Any?): Boolean =
        other is BaresipError &&
            code == other.code &&
            systemErrno == other.systemErrno &&
            sipStatus == other.sipStatus &&
            sipReason == other.sipReason &&
            detail == other.detail &&
            endReason == other.endReason

    override fun hashCode(): Int = listOf(code, systemErrno, sipStatus, sipReason, detail, endReason).hashCode()

    override fun toString(): String = "BaresipError($message)"

    /**
     * The category of a failed BaresipKit operation. The codes mirror the status codes of the C
     * core one to one.
     */
    enum class Code {
        /** The operation succeeded. */
        OK,

        /** An argument was missing, empty or malformed. */
        INVALID_ARGUMENT,

        /** The engine, account or call is not in a state that allows the operation. */
        INVALID_STATE,

        /** No account, call or message with the given identifier exists. */
        NOT_FOUND,

        /** The core could not allocate memory. */
        NO_MEMORY,

        /** The operation is not available in this build or for this call. */
        UNSUPPORTED,

        /** The resource is busy, for example the maximum number of calls is reached. */
        BUSY,

        /** The operation did not finish in time. */
        TIMEOUT,

        /** A network or transport error occurred. */
        NETWORK,

        /** The TLS handshake or certificate validation failed. */
        TLS,

        /** The server rejected the credentials. */
        AUTHENTICATION,

        /** The SIP transaction failed; [BaresipError.sipStatus] holds the response code. */
        SIP,

        /** Audio or video setup failed. */
        MEDIA,

        /** A buffer supplied to the core was too small. */
        BUFFER_TOO_SMALL,

        /** An unexpected internal error occurred. */
        INTERNAL_ERROR,
        ;

        internal companion object {
            fun of(code: Int): Code = entries.getOrElse(code) { INTERNAL_ERROR }
        }
    }

    internal companion object {
        fun invalid(detail: String) = BaresipError(Code.INVALID_ARGUMENT, detail = detail)
    }
}
