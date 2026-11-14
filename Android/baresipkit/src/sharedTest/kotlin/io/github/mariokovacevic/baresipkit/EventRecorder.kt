package io.github.mariokovacevic.baresipkit

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.CopyOnWriteArrayList

class EventRecorder private constructor(
    private val job: Job,
    val events: CopyOnWriteArrayList<BaresipEvent>,
) {
    suspend fun <T : Any> await(
        what: String,
        timeoutMs: Long = 10_000,
        match: (BaresipEvent) -> T?,
    ): T =
        withTimeoutOrNull(timeoutMs) {
            while (true) {
                events.firstNotNullOfOrNull(match)?.let { return@withTimeoutOrNull it }
                delay(20)
            }
            @Suppress("UNREACHABLE_CODE")
            null
        } ?: error("no event for $what within $timeoutMs ms; got ${events.joinToString("\n")}")

    suspend fun awaitCall(
        call: BaresipCallID,
        state: BaresipCallState,
    ): BaresipEvent.Call = await("$call $state") { event -> (event as? BaresipEvent.Call)?.takeIf { it.call == call && it.state == state } }

    fun stop() = job.cancel()

    companion object {
        suspend fun start(
            engine: BaresipEngine,
            scope: CoroutineScope,
        ): EventRecorder {
            val events = CopyOnWriteArrayList<BaresipEvent>()
            val job = scope.launch(Dispatchers.Default, start = CoroutineStart.UNDISPATCHED) { engine.events.collect { events += it } }
            return EventRecorder(job, events)
        }
    }
}
