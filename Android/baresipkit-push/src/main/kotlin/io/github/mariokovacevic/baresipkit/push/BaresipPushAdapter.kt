package io.github.mariokovacevic.baresipkit.push

import io.github.mariokovacevic.baresipkit.BaresipAccountID
import io.github.mariokovacevic.baresipkit.BaresipContactParameter
import io.github.mariokovacevic.baresipkit.BaresipEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Keeps the account's push `Contact` parameters current and wakes the engine for pushed calls,
 * the counterpart of the iOS PushKit adapter.
 *
 * The adapter does not depend on Firebase: forward the two calls of your
 * `FirebaseMessagingService` to it.
 *
 * ```kotlin
 * class PushService : FirebaseMessagingService() {
 *     override fun onNewToken(token: String) = app.push.updateToken(token)
 *     override fun onMessageReceived(message: RemoteMessage) {
 *         runBlocking { app.push.handle(message.data) }
 *     }
 * }
 *
 * val push = BaresipPushAdapter(engine, appId = context.packageName) { call ->
 *     telecom.reportIncomingCallFromPush(call.uuid, call.remoteUri, call.displayName, call.hasVideo)
 * }
 * push.bind(account)
 * ```
 *
 * The adapter owns the `Contact` parameters of the bound account: every update replaces all of
 * them. Pass the parameters the account needs besides the push ones as
 * [additionalContactParameters].
 *
 * @param onIncomingCall Reports a pushed call to the system, for example to Telecom.
 */
public class BaresipPushAdapter(
    private val engine: BaresipEngine,
    appId: String,
    account: BaresipAccountID? = null,
    additionalContactParameters: List<BaresipContactParameter> = emptyList(),
    private val onIncomingCall: suspend (BaresipPushCall) -> Unit,
) {
    /** What the adapter was doing when an error occurred. */
    public enum class Step {
        /** Sending the `Contact` parameters to the engine. */
        CONTACT_PARAMETERS,

        /** Reporting a pushed call to the system. */
        INCOMING_PUSH,

        /** Waking the engine after a push. The INVITE may not arrive. */
        ENGINE_WAKE_UP,
    }

    private val lock = Any()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var tokens = BaresipPushTokens(appId)
    private var additional = additionalContactParameters
    private var account = account
    private val updates = ContactParameterUpdates()

    @Volatile private var errorHandler: ((Step, Throwable) -> Unit)? = null

    /** The current tokens. */
    public val currentTokens: BaresipPushTokens
        get() = synchronized(lock) { tokens }

    /** Sets a handler for errors of work the adapter does on its own; without one they are dropped. */
    public fun setErrorHandler(handler: ((Step, Throwable) -> Unit)?) {
        errorHandler = handler
    }

    /** Sets the account that receives the push parameters and updates its registration. */
    public fun bind(account: BaresipAccountID) {
        synchronized(lock) { this.account = account }
        sendContactParameters()
    }

    /** Stores a new Firebase token, from `onNewToken`, and updates the account's registration. */
    public fun updateToken(token: String?): Unit = updateTokens { it.copy(token = token) }

    /** Changes the `app-id` sent to the server and updates the account's registration. */
    public fun updateAppId(appId: String): Unit = updateTokens { it.copy(appId = appId) }

    /** Replaces the `Contact` parameters sent together with the push ones. */
    public fun updateAdditionalContactParameters(parameters: List<BaresipContactParameter>) {
        val changed =
            synchronized(lock) {
                if (additional == parameters) return
                additional = parameters
                true
            }
        if (changed) sendContactParameters()
    }

    /**
     * Handles the data of a push message from `onMessageReceived`: reports the call, then wakes the
     * engine so the INVITE can arrive.
     *
     * @return `false` when the message announces no call.
     */
    public suspend fun handle(data: Map<String, String>): Boolean {
        val call = BaresipPushCall.from(data) ?: return false
        try {
            onIncomingCall(call)
        } catch (error: Throwable) {
            report(Step.INCOMING_PUSH, error)
        }
        try {
            engine.prepareForPushWakeUp()
        } catch (error: Throwable) {
            report(Step.ENGINE_WAKE_UP, error)
        }
        return true
    }

    private fun updateTokens(change: (BaresipPushTokens) -> BaresipPushTokens) {
        val changed =
            synchronized(lock) {
                val previous = tokens
                tokens = change(tokens)
                tokens != previous
            }
        if (changed) sendContactParameters()
    }

    private fun sendContactParameters() {
        val starts =
            synchronized(lock) {
                val id = account ?: return
                updates.submit(ContactParameterUpdates.Request(id, tokens.mergedContactParameters(additional)))
            }
        if (starts) scope.launch { sendPending() }
    }

    private suspend fun sendPending() {
        while (true) {
            val request = synchronized(lock) { updates.next() } ?: return
            try {
                engine.updateContactParameters(request.account, request.parameters, reregisterNow = true)
            } catch (error: Throwable) {
                report(Step.CONTACT_PARAMETERS, error)
            }
        }
    }

    private fun report(
        step: Step,
        error: Throwable,
    ) {
        errorHandler?.invoke(step, error)
    }
}

internal class ContactParameterUpdates {
    data class Request(
        val account: BaresipAccountID,
        val parameters: List<BaresipContactParameter>,
    )

    private var latest: Request? = null
    private var isSending = false

    fun submit(request: Request): Boolean {
        latest = request
        if (isSending) return false
        isSending = true
        return true
    }

    fun next(): Request? {
        val request = latest
        if (request == null) {
            isSending = false
            return null
        }
        latest = null
        return request
    }
}
