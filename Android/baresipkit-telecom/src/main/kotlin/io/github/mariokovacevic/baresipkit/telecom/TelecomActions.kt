package io.github.mariokovacevic.baresipkit.telecom

import androidx.core.telecom.CallControlResult
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.time.Duration

/**
 * A call action Telecom did not carry out.
 *
 * The counterpart of `BaresipCallKitError` on iOS: [reason] says whether Telecom refused the
 * action or did not answer in time.
 */
public class BaresipTelecomException(
    /** Why the action failed. */
    public val reason: Reason,
    /** The action, for example `answer` or `setInactive`. */
    public val action: String,
    /** The error code from `CallControlResult.Error`, or `null` when there is none. */
    public val errorCode: Int? = null,
) : Exception(
        when (reason) {
            Reason.ACTION_TIMED_OUT -> "Telecom did not finish $action in time"
            Reason.REFUSED -> "Telecom refused $action (error $errorCode)"
        },
    ) {
    /** Why an action failed. */
    public enum class Reason {
        /** Telecom did not finish the action within [BaresipTelecomConfiguration.actionTimeout]. */
        ACTION_TIMED_OUT,

        /** Telecom answered the action with an error. */
        REFUSED,
    }
}

internal object TelecomActions {
    suspend fun <T> ready(
        ready: CompletableDeferred<T>,
        timeout: Duration,
        action: String,
    ): T =
        withTimeoutOrNull(timeout) { ready.await() }
            ?: throw BaresipTelecomException(BaresipTelecomException.Reason.ACTION_TIMED_OUT, action)

    suspend fun perform(
        timeout: Duration,
        action: String,
        block: suspend () -> CallControlResult,
    ) {
        val result =
            withTimeoutOrNull(timeout) { block() }
                ?: throw BaresipTelecomException(BaresipTelecomException.Reason.ACTION_TIMED_OUT, action)
        if (result is CallControlResult.Error) {
            throw BaresipTelecomException(BaresipTelecomException.Reason.REFUSED, action, result.errorCode)
        }
    }
}
