package io.github.mariokovacevic.baresipkit.compose

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.mariokovacevic.baresipkit.BaresipAccountID
import io.github.mariokovacevic.baresipkit.BaresipCallController
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipEvent
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * The engine's registrations and calls as observable Compose state.
 *
 * The phone applies the engine's events to its state while [run] runs, so composables follow
 * registration and call state without handling events themselves. Create it once for an engine,
 * for example in a `ViewModel` with its `viewModelScope`, and run it there:
 *
 * ```kotlin
 * class PhoneViewModel(engine: BaresipEngine) : ViewModel() {
 *     val phone = BaresipPhone(engine, scope = viewModelScope)
 *     init { viewModelScope.launch { phone.run() } }
 * }
 * ```
 *
 * State changes happen on the [scope]'s dispatcher; use the main dispatcher for UI.
 *
 * @param engine The engine to follow. The phone neither starts nor stops it.
 * @param callController Takes call actions through a system call interface such as Telecom, or
 *   `null` to use the engine directly.
 * @param scope Where the phone reads call details after changes.
 */
class BaresipPhone(
    /** The engine whose events the phone applies. */
    val engine: BaresipEngine,
    callController: BaresipCallController? = null,
    internal val scope: CoroutineScope,
) {
    private val registrationState = mutableStateMapOf<BaresipAccountID, BaresipRegistrationState>()
    private val callList = mutableStateListOf<BaresipPhoneCall>()
    private val released = mutableSetOf<BaresipCallID>()
    private val observedControllers = mutableSetOf<BaresipCallController>()

    /** The registration state of every account of the engine. */
    val registrations: Map<BaresipAccountID, BaresipRegistrationState>
        get() = registrationState

    /** The calls that are not released yet, in the order they appeared. */
    val calls: List<BaresipPhoneCall>
        get() = callList

    /**
     * The call a call screen shows: the call placed or answered last, also on the system call
     * screen, or the one made active with [makeActive]. When the active call ends, the next call
     * becomes active, a held one first.
     */
    var activeCall: BaresipPhoneCall? by mutableStateOf(null)
        private set

    /**
     * Takes call actions through a system call interface such as Telecom, for the calls it
     * controls. The calls' actions use the engine directly when it is `null` or does not control
     * a call.
     */
    var callController: BaresipCallController? = callController
        set(value) {
            field = value
            observeMuting(value)
        }

    /** Whether a held call is resumed when the active call ends. On by default. */
    var resumesHeldCallWhenActiveCallEnds: Boolean = true

    init {
        observeMuting(callController)
    }

    /** The first call that is ringing and not answered yet. */
    val incomingCall: BaresipPhoneCall?
        get() = callList.firstOrNull { it.isRinging }

    /**
     * Applies the engine's events until the calling coroutine is cancelled. Each run first brings
     * [calls] in line with the engine, so running it again after a cancellation is safe.
     */
    suspend fun run() {
        synchronize()
        engine.events.collect { apply(it) }
    }

    /** The call with an identifier, if it is not released yet. */
    fun call(id: BaresipCallID): BaresipPhoneCall? = callList.firstOrNull { it.id == id }

    /**
     * Places a call and adds it to [calls]. The call goes through [callController] when one is set,
     * unless it uses another account or no audio, and becomes the [activeCall] unless an
     * established call is active.
     *
     * @param video Whether to send the camera; the other side's video is received either way.
     * @param audio Whether to open the microphone and play the other side's audio.
     */
    suspend fun makeCall(
        destination: String,
        account: BaresipAccountID? = null,
        video: Boolean = false,
        audio: Boolean = true,
    ): BaresipPhoneCall {
        val controller = callController
        val id =
            if (controller != null && account == null && audio) {
                controller.placeCall(destination, video)
            } else {
                engine.makeCall(account, destination, video, audio)
            }
        if (id in released) {
            return BaresipPhoneCall(id, BaresipCallState.RELEASED, engine).also { it.markOutgoing(destination, video) }
        }
        val placed = trackedCall(id, BaresipCallState.OUTGOING_INIT)
        placed.markOutgoing(destination, video)
        val active = activeCall
        if (active == null || active === placed || active.isOnHold || !active.isConnected) activeCall = placed
        placed.refresh()
        return placed
    }

    /** Makes a call the active one: the engine puts other established calls on hold and resumes this one. */
    suspend fun makeActive(call: BaresipPhoneCall) {
        if (callList.size > 1) engine.setActiveCall(call.id)
        activeCall = call
        call.refresh()
    }

    /**
     * The established call whose other side has a SIP address, for example to show a SIP MESSAGE
     * from that side on the call's screen. The [activeCall] comes first; calls that ring or have
     * ended do not count.
     */
    fun call(withPeer: String): BaresipPhoneCall? {
        val established = callList.filter { it.isConnected || it.isOnHold || it.isHeldByRemote }
        activeCall?.let { active -> if (established.any { it === active } && active.isPeer(withPeer)) return active }
        return established.firstOrNull { it.isPeer(withPeer) }
    }

    internal suspend fun callWasAnswered(call: BaresipPhoneCall) {
        if (call(call.id) == null) return
        if (callList.any { it !== call && it.isConnected }) runCatching { engine.setActiveCall(call.id) }
        activeCall = call
    }

    internal fun apply(event: BaresipEvent) {
        when (event) {
            is BaresipEvent.Registration -> registrationState[event.account] = event.state
            is BaresipEvent.IncomingCall ->
                if (event.info.id !in released) trackedCall(event.info.id, event.info.state).update(event.info)
            is BaresipEvent.Call -> applyState(event.state, event.error, event.call)
            is BaresipEvent.Media -> call(event.call)?.refresh()
            is BaresipEvent.Dtmf -> if (!event.dtmf.isEnd) call(event.call)?.didReceiveDtmf(event.dtmf.digit)
            else -> Unit
        }
    }

    internal suspend fun synchronize() {
        registrationState.putAll(engine.accounts())
        val active = engine.activeCalls()
        callList.map { it.id }.filter { it !in active }.forEach { release(it) }
        for (id in active) {
            if (id in released) continue
            val info = runCatching { engine.callInfo(id) }.getOrNull() ?: continue
            applySnapshot(id, info.state)?.update(info)
        }
    }

    internal fun applySnapshot(
        id: BaresipCallID,
        state: BaresipCallState,
    ): BaresipPhoneCall? {
        if (id in released) return null
        if (state == BaresipCallState.RELEASED) {
            release(id)
            return null
        }
        return trackedCall(id, state).also { it.update(state, null) }
    }

    private fun applyState(
        state: BaresipCallState,
        error: BaresipError?,
        id: BaresipCallID,
    ) {
        if (state == BaresipCallState.RELEASED) {
            release(id)
            return
        }
        if (id in released) return
        val current = trackedCall(id, state)
        val wasRinging = current.isRinging
        current.update(state, error)
        if (wasRinging && current.isConnected) activeCall = current
        current.refresh()
    }

    private fun release(id: BaresipCallID) {
        released += id
        call(id)?.update(BaresipCallState.RELEASED, null)
        callList.removeAll { it.id == id }
        if (activeCall?.id != id) return
        val next = callList.firstOrNull { it.isOnHold } ?: callList.firstOrNull()
        activeCall = next
        if (next != null && next.isOnHold && resumesHeldCallWhenActiveCallEnds) {
            scope.launch { runCatching { next.setOnHold(false) } }
        }
    }

    private fun trackedCall(
        id: BaresipCallID,
        state: BaresipCallState,
    ): BaresipPhoneCall {
        call(id)?.let { return it }
        val created = BaresipPhoneCall(id, state, engine)
        created.phone = this
        callList += created
        if (activeCall == null) activeCall = created
        return created
    }

    private fun observeMuting(controller: BaresipCallController?) {
        if (controller == null || !observedControllers.add(controller)) return
        controller.addMuteObserver { id, muted -> scope.launch { call(id)?.applyMuted(muted) } }
    }
}
