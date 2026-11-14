package io.github.mariokovacevic.baresipkit.compose

import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipDtmfEvent
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipEvent
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds
import kotlin.time.TimeSource

class BaresipPhoneControlTest {
    @Before
    fun hostCore() = requireHostCore()

    private fun dtmf(
        id: BaresipCallID,
        digit: Char,
        end: Boolean = false,
    ) = BaresipEvent.Dtmf(id, BaresipDtmfEvent(digit, end, false))

    @Test
    fun theFirstCallBecomesActive() =
        runBlocking {
            val phone = phone()
            phone.apply(state(BaresipCallID(1), BaresipCallState.STREAMS_RUNNING))
            phone.apply(state(BaresipCallID(2), BaresipCallState.INCOMING))
            assertEquals(BaresipCallID(1), phone.activeCall?.id)
        }

    @Test
    fun whenTheActiveCallEndsTheHeldCallIsResumed() =
        runBlocking {
            val first = BaresipCallID(1)
            val second = BaresipCallID(2)
            val controller = RecordingController(setOf(first, second))
            val phone = phone(controller)
            phone.apply(state(first, BaresipCallState.PAUSED))
            phone.apply(state(second, BaresipCallState.INCOMING))
            phone.call(second)!!.answer()
            assertEquals(second, phone.activeCall?.id)
            phone.apply(state(second, BaresipCallState.RELEASED))
            assertEquals(first, phone.activeCall?.id)
            waitUntil { controller.actions == listOf("answer 2 video=false", "hold 1 false") }
        }

    @Test
    fun aHeldCallStaysHeldWhenResumingIsOff() =
        runBlocking {
            val first = BaresipCallID(1)
            val second = BaresipCallID(2)
            val controller = RecordingController(setOf(first, second))
            val phone = phone(controller)
            phone.resumesHeldCallWhenActiveCallEnds = false
            phone.apply(state(first, BaresipCallState.STREAMS_RUNNING))
            phone.apply(state(second, BaresipCallState.PAUSED))
            phone.apply(state(first, BaresipCallState.RELEASED))
            delay(50)
            assertEquals(second, phone.activeCall?.id)
            assertEquals(emptyList<String>(), controller.actions)
        }

    @Test
    fun actionsOfAControlledCallGoThroughTheController() =
        runBlocking {
            val id = BaresipCallID(5)
            val controller = RecordingController(setOf(id))
            val phone = phone(controller)
            phone.apply(state(id, BaresipCallState.INCOMING))
            val call = phone.call(id)!!
            call.answer(video = true)
            call.setMuted(true)
            call.setOnHold(true)
            call.hangUp()
            assertEquals(listOf("answer 5 video=true", "mute 5 true", "hold 5 true", "end 5"), controller.actions)
            waitUntil { call.isMuted }
            assertTrue(call.isSendingVideo)
            assertEquals(id, phone.activeCall?.id)
        }

    @Test
    fun actionsOfAnUncontrolledCallGoToTheEngine() =
        runBlocking {
            val id = BaresipCallID(5)
            val controller = RecordingController(emptySet())
            val phone = phone(controller)
            phone.apply(state(id, BaresipCallState.INCOMING))
            if (runCatching { phone.call(id)!!.hangUp() }.isSuccess) fail("the engine accepted a hang-up for an unknown call")
            assertEquals(emptyList<String>(), controller.actions)
        }

    @Test
    fun answerWithoutAudioSkipsTheController() =
        runBlocking {
            val id = BaresipCallID(5)
            val controller = RecordingController(setOf(id))
            val phone = phone(controller)
            phone.apply(state(id, BaresipCallState.INCOMING))
            runCatching { phone.call(id)?.answer(audio = false) }
            assertEquals(emptyList<String>(), controller.actions)
        }

    @Test
    fun callsArePlacedThroughTheController() =
        runBlocking {
            val placed = BaresipCallID(99)
            val controller = RecordingController(setOf(placed), placed)
            val phone = phone(controller)
            val call = phone.makeCall("sip:door@example.com", video = true)
            assertEquals(listOf("place sip:door@example.com video=true"), controller.actions)
            assertEquals(placed, call.id)
            assertTrue(call.isOutgoing)
            assertTrue(call.isSendingVideo)
            assertEquals(placed, phone.activeCall?.id)
        }

    @Test
    fun mutingFromTheSystemUpdatesTheCall() =
        runBlocking {
            val id = BaresipCallID(3)
            val controller = RecordingController(setOf(id))
            val phone = phone(controller)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            controller.reportMuted(true, id)
            waitUntil { phone.call(id)?.isMuted == true }
        }

    @Test
    fun receivedDtmfIsCollected() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(4)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            phone.apply(dtmf(id, '1'))
            phone.apply(dtmf(id, '1', end = true))
            phone.apply(dtmf(id, '#'))
            assertEquals("1#", phone.call(id)?.receivedDtmf)
        }

    @Test
    fun aDoorCodeIsConfirmedByTheExpectedDigit() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(4)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            val sent = mutableListOf<String>()
            val reply =
                phone.call(id)!!.sendDtmf("1234", '#', 5.seconds) { digits ->
                    sent += digits
                    phone.apply(dtmf(id, '#'))
                }
            assertEquals(listOf("1234"), sent)
            assertEquals(BaresipDtmfReply.Confirmed, reply)
        }

    @Test
    fun anotherDigitIsReported() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(4)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            val reply = phone.call(id)!!.sendDtmf("1234", '#', 5.seconds) { phone.apply(dtmf(id, '9')) }
            assertEquals(BaresipDtmfReply.Other('9'), reply)
        }

    @Test
    fun noReplyEndsAfterTheTimeout() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(4)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            val start = TimeSource.Monotonic.markNow()
            val reply = phone.call(id)!!.sendDtmf("1234", '#', 100.milliseconds) {}
            assertEquals(BaresipDtmfReply.NoReply, reply)
            assertTrue(start.elapsedNow() < 2.seconds)
        }

    @Test
    fun aFailedSendThrowsWithoutWaiting() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(4)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            val result =
                runCatching {
                    phone.call(id)!!.sendDtmf("1234", '#', 30.seconds) { throw BaresipError(BaresipError.Code.NETWORK, detail = "gone") }
                }
            assertTrue(result.isFailure)
        }

    @Test
    fun theConnectionTimeIsKeptFromTheFirstConnect() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(6)
            phone.apply(state(id, BaresipCallState.OUTGOING_RINGING))
            assertNull(phone.call(id)?.connectedAt)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            val connected = phone.call(id)?.connectedAt
            assertNotNull(connected)
            phone.apply(state(id, BaresipCallState.PAUSED))
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            assertSame(connected, phone.call(id)?.connectedAt)
        }

    @Test
    fun userPartOfSipUris() {
        assertEquals("alice", BaresipPhoneCall.userPart("sip:alice@example.com;transport=tls"))
        assertEquals("1002", BaresipPhoneCall.userPart("sips:1002@pbx"))
        assertEquals("+385123", BaresipPhoneCall.userPart("tel:+385123"))
        assertEquals("sip:@", BaresipPhoneCall.userPart("sip:@"))
    }

    @Test
    fun aCallAnsweredOnTheSystemScreenBecomesActive() =
        runBlocking {
            val phone = phone()
            phone.apply(state(BaresipCallID(1), BaresipCallState.STREAMS_RUNNING))
            phone.apply(state(BaresipCallID(2), BaresipCallState.INCOMING))
            assertEquals(BaresipCallID(1), phone.activeCall?.id)
            phone.apply(state(BaresipCallID(2), BaresipCallState.CONNECTED))
            assertEquals(BaresipCallID(2), phone.activeCall?.id)
        }

    @Test
    fun samePeers() {
        assertTrue(BaresipPhoneCall.samePeer("\"Front door\" <sip:Door1@PBX.example.com:5061;transport=tls>", "sip:door1@pbx.example.com"))
        assertTrue(BaresipPhoneCall.samePeer("sips:door1@pbx.example.com?subject=x", "<sip:door1@pbx.example.com>"))
        assertTrue(BaresipPhoneCall.samePeer("sip:100@[2001:db8::1]:5060", "sip:100@[2001:db8::1]"))
        assertTrue(BaresipPhoneCall.samePeer("door1", "sip:door1@pbx.example.com"))
        assertTrue(BaresipPhoneCall.samePeer("tel:+15555550100", "sip:+15555550100@pbx.example.com"))
        assertFalse(BaresipPhoneCall.samePeer("sip:door2@pbx.example.com", "sip:door1@pbx.example.com"))
        assertFalse(BaresipPhoneCall.samePeer("sip:door1@other.example.com", "sip:door1@pbx.example.com"))
        assertFalse(BaresipPhoneCall.samePeer("sip:door10@pbx.example.com", "sip:door1@pbx.example.com"))
        assertFalse(BaresipPhoneCall.samePeer("", "sip:door1@pbx.example.com"))
        assertFalse(BaresipPhoneCall.samePeer("sip:@pbx.example.com", "sip:@pbx.example.com"))
    }

    @Test
    fun aMessageBelongsToTheEstablishedCallWithItsSender() =
        runBlocking {
            val phone = phone()
            val door = BaresipCallID(1)
            val neighbour = BaresipCallID(2)
            val ringing = BaresipCallID(3)
            phone.apply(incoming(door, "sip:door1@pbx.example.com"))
            phone.apply(state(door, BaresipCallState.STREAMS_RUNNING))
            phone.apply(incoming(neighbour, "sip:101@pbx.example.com"))
            phone.apply(state(neighbour, BaresipCallState.PAUSED))
            phone.apply(incoming(ringing, "sip:gate@pbx.example.com"))
            assertEquals(door, phone.call(withPeer = "\"Front door\" <sip:door1@pbx.example.com>")?.id)
            assertEquals(neighbour, phone.call(withPeer = "sip:101@pbx.example.com")?.id)
            assertNull(phone.call(withPeer = "sip:gate@pbx.example.com"))
            assertNull(phone.call(withPeer = "sip:202@pbx.example.com"))
            phone.apply(state(door, BaresipCallState.ENDED))
            assertNull(phone.call(withPeer = "sip:door1@pbx.example.com"))
        }
}
