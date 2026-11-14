package io.github.mariokovacevic.baresipkit.compose

import io.github.mariokovacevic.baresipkit.BaresipAccountID
import io.github.mariokovacevic.baresipkit.BaresipCallController
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallInfo
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipConfiguration
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipEvent
import io.github.mariokovacevic.baresipkit.BaresipMediaDirection
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.time.Duration

fun requireHostCore() = assumeTrue(System.getProperty("baresipkit.hostCore") == "true")

fun testEngine(): BaresipEngine =
    BaresipEngine(
        BaresipConfiguration {
            modules = listOf("g711")
            audio {
                sourceModule = "ausine"
                playerModule = "aufile"
                playerDevice = "/dev/null"
            }
            extraConfiguration = "sip_listen\t\t0.0.0.0:0"
        },
    )

fun CoroutineScope.phone(controller: BaresipCallController? = null) = BaresipPhone(testEngine(), controller, this)

fun state(
    id: BaresipCallID,
    state: BaresipCallState,
) = BaresipEvent.Call(id, state, null)

fun incoming(
    id: BaresipCallID,
    uri: String,
) = BaresipEvent.IncomingCall(
    BaresipCallInfo(
        id,
        BaresipAccountID(1),
        BaresipCallState.INCOMING,
        false,
        false,
        BaresipMediaDirection.SEND_RECEIVE,
        BaresipMediaDirection.INACTIVE,
        "",
        uri,
        "",
        "",
        "",
        Duration.ZERO,
        Duration.ZERO,
        false,
    ),
    false,
)

suspend fun waitUntil(condition: () -> Boolean) {
    repeat(100) {
        if (condition()) return
        delay(10)
    }
    assertTrue(condition())
}

class RecordingController(
    controls: Set<BaresipCallID>,
    private val placedCall: BaresipCallID = BaresipCallID(99),
) : BaresipCallController {
    private val controlled = controls.toMutableSet()
    val actions = CopyOnWriteArrayList<String>()
    private val observers = CopyOnWriteArrayList<(BaresipCallID, Boolean) -> Unit>()

    override fun controls(call: BaresipCallID) = call in controlled

    override suspend fun placeCall(
        destination: String,
        video: Boolean,
    ): BaresipCallID {
        actions += "place $destination video=$video"
        return placedCall
    }

    override suspend fun answer(
        call: BaresipCallID,
        video: Boolean,
    ) {
        actions += "answer ${call.rawValue} video=$video"
    }

    override suspend fun end(call: BaresipCallID) {
        actions += "end ${call.rawValue}"
    }

    override suspend fun setOnHold(
        onHold: Boolean,
        call: BaresipCallID,
    ) {
        actions += "hold ${call.rawValue} $onHold"
    }

    override suspend fun setMuted(
        muted: Boolean,
        call: BaresipCallID,
    ) {
        actions += "mute ${call.rawValue} $muted"
        reportMuted(muted, call)
    }

    override fun addMuteObserver(observer: (BaresipCallID, Boolean) -> Unit) {
        observers += observer
    }

    fun reportMuted(
        muted: Boolean,
        call: BaresipCallID,
    ) = observers.forEach { it(call, muted) }
}
