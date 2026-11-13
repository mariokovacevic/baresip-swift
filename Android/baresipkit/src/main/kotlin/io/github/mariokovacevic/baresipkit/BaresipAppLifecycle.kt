package io.github.mariokovacevic.baresipkit

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds
import kotlin.time.TimeSource

/**
 * Follows the app's lifecycle for an engine: takes it offline or pauses it in the background when
 * no call runs, and brings it back online when the app is in the foreground again.
 *
 * - The app moves to the background with no call: what happens is [backgroundBehavior]. With
 *   [BackgroundBehavior.GO_OFFLINE] every registered account unregisters. With
 *   [BackgroundBehavior.SUSPEND] the engine is suspended and its registrations stay on the server,
 *   so a push can still announce a call. A call that ends while the app is in the background does
 *   the same.
 * - The app comes to the foreground again: the transports open again and the accounts register.
 *
 * ```kotlin
 * val lifecycle = BaresipAppLifecycle(engine)
 * lifecycle.backgroundBehavior = BaresipAppLifecycle.BackgroundBehavior.GO_OFFLINE
 * lifecycle.start()
 * ```
 */
class BaresipAppLifecycle(
    /** The engine whose lifecycle is followed. */
    val engine: BaresipEngine,
) {
    /** What happens in the background while no call runs. */
    enum class BackgroundBehavior {
        /** Nothing: the engine stays as it is. */
        STAY_ONLINE,

        /** The engine is suspended and its registrations stay on the server, so a push can announce a call. */
        SUSPEND,

        /** Every registered account unregisters; nobody can reach the app until it is in the foreground again. */
        GO_OFFLINE,
    }

    /** What the lifecycle did to the engine. */
    enum class Change {
        /** The engine was suspended in the background. */
        SUSPENDED,

        /** The accounts unregistered in the background. */
        WENT_OFFLINE,

        /** The app is in the foreground again: the transports opened and the accounts register. */
        BACK_ONLINE,
    }

    /** What happens in the background while no call runs. [BackgroundBehavior.SUSPEND] by default. */
    @Volatile var backgroundBehavior: BackgroundBehavior = BackgroundBehavior.SUSPEND

    /** How long going offline waits for the accounts to unregister. */
    @Volatile var unregisterTimeout: Duration = 2.seconds

    /** Whether the lifecycle suspended the engine or took it offline and has not brought it back yet. */
    @Volatile var isAway: Boolean = false
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mutex = Mutex()

    @Volatile private var isInBackground = false
    private var offlineAccounts: List<BaresipAccountID> = emptyList()
    private var eventJob: Job? = null
    private var observer: DefaultLifecycleObserver? = null

    @Volatile private var changeHandler: ((Change) -> Unit)? = null

    /** Sets a handler called after the lifecycle changed the engine, for example to log it. */
    fun setChangeHandler(handler: ((Change) -> Unit)?) {
        changeHandler = handler
    }

    /** Starts following the app's process lifecycle and the engine's calls. Call it on the main thread. */
    fun start() {
        if (observer != null) return
        val watcher =
            object : DefaultLifecycleObserver {
                override fun onStart(owner: LifecycleOwner) = didBecomeActive()

                override fun onStop(owner: LifecycleOwner) = didEnterBackground()
            }
        observer = watcher
        ProcessLifecycleOwner.get().lifecycle.addObserver(watcher)
        watchCalls()
    }

    /** Stops following the app. An engine that is away stays away. Call it on the main thread. */
    fun stop() {
        observer?.let { ProcessLifecycleOwner.get().lifecycle.removeObserver(it) }
        observer = null
        eventJob?.cancel()
        eventJob = null
    }

    internal fun watchCalls() {
        eventJob =
            scope.launch {
                engine.events.collect { event ->
                    if (event is BaresipEvent.Call && event.state == BaresipCallState.RELEASED) goAwayIfIdle()
                }
            }
    }

    internal fun didEnterBackground() {
        isInBackground = true
        scope.launch { goAwayIfIdle() }
    }

    internal fun didBecomeActive() {
        isInBackground = false
        scope.launch { comeBack() }
    }

    private suspend fun comeBack() {
        val accounts =
            mutex.withLock {
                if (!isAway || isInBackground) return
                isAway = false
                offlineAccounts.also { offlineAccounts = emptyList() }
            }
        if (accounts.isEmpty()) {
            runCatching { engine.resumeFromBackground() }
        } else {
            engine.networkDidChange(reregister = false, updateCalls = false)
            for (account in accounts) runCatching { engine.register(account) }
        }
        changeHandler?.invoke(Change.BACK_ONLINE)
    }

    internal suspend fun goAwayIfIdle() {
        mutex.withLock {
            val state = engine.state
            if (backgroundBehavior == BackgroundBehavior.STAY_ONLINE ||
                !isInBackground ||
                isAway ||
                (state != BaresipEngineState.RUNNING && state != BaresipEngineState.READY)
            ) {
                return
            }
            if (engine.activeCalls().isNotEmpty() || !isInBackground) return
            when (backgroundBehavior) {
                BackgroundBehavior.STAY_ONLINE -> return
                BackgroundBehavior.SUSPEND -> {
                    if (runCatching { engine.suspend() }.isFailure) return
                    isAway = true
                    changeHandler?.invoke(Change.SUSPENDED)
                }
                BackgroundBehavior.GO_OFFLINE -> {
                    offlineAccounts = unregisterAll()
                    isAway = true
                    changeHandler?.invoke(Change.WENT_OFFLINE)
                }
            }
        }
        if (!isInBackground) comeBack()
    }

    private suspend fun unregisterAll(): List<BaresipAccountID> {
        val registered =
            engine
                .accounts()
                .filterValues {
                    it == BaresipRegistrationState.REGISTERED || it == BaresipRegistrationState.REGISTERING
                }.keys
                .toList()
        for (account in registered) runCatching { engine.unregister(account) }
        val deadline = TimeSource.Monotonic.markNow() + unregisterTimeout
        while (deadline.hasNotPassedNow()) {
            val states = engine.accounts()
            val pending =
                registered.any {
                    states[it] == BaresipRegistrationState.REGISTERED || states[it] == BaresipRegistrationState.UNREGISTERING
                }
            if (!pending) break
            delay(100.milliseconds)
        }
        return registered
    }
}
