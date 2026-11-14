package io.github.mariokovacevic.baresipkit

import io.github.mariokovacevic.baresipkit.internal.EventDecoder
import io.github.mariokovacevic.baresipkit.internal.wholeMilliseconds
import io.github.mariokovacevic.baresipkit.internal.wholeSeconds
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

class EventDecoderTest {
    private val callState = 2
    private val callMedia = 4
    private val network = 9
    private val ended = 11

    private fun ended(
        sipStatus: Long,
        endReason: Long,
    ): BaresipEvent.Call {
        val n = longArrayOf(0, 0, sipStatus, endReason, ended.toLong())
        return EventDecoder.decode(callState, 1, 7, n, arrayOf(null, null), null) as BaresipEvent.Call
    }

    @Test
    fun aCallAnsweredOnAnotherDeviceSaysSo() {
        val event = ended(200, 1)
        assertEquals(BaresipCallState.ENDED, event.state)
        val error = event.error!!
        assertEquals(BaresipCallEndReason.ANSWERED_ELSEWHERE, error.endReason)
        assertEquals(200, error.sipStatus)
        assertFalse(error.isFailure)
    }

    @Test
    fun aCallDeclinedOnAnotherDeviceSaysSo() {
        assertEquals(BaresipCallEndReason.DECLINED_ELSEWHERE, ended(603, 2).error?.endReason)
    }

    @Test
    fun aCallAnotherCallTookOverIsReplacedNotFailed() {
        val error = ended(0, 3).error!!
        assertEquals(BaresipCallEndReason.REPLACED, error.endReason)
        assertFalse(error.isFailure)
    }

    @Test
    fun anIncomingCallNamesTheCallItReplacesAndKeepsItsEarlyVideoFlag() {
        val n = LongArray(4 + EventDecoder.CALL_INFO_LONGS + 1)
        n[4] = 8
        n[4 + 10] = 7
        n[4 + EventDecoder.CALL_INFO_LONGS] = 1
        val event = EventDecoder.decode(3, 1, 8, n, arrayOfNulls(2 + 5), null) as BaresipEvent.IncomingCall
        assertEquals(BaresipCallID(7), event.info.replacesCallId)
        assertTrue(event.earlyVideo)

        n[4 + 10] = 0
        n[4 + EventDecoder.CALL_INFO_LONGS] = 0
        val plain = EventDecoder.decode(3, 1, 8, n, arrayOfNulls(2 + 5), null) as BaresipEvent.IncomingCall
        assertNull(plain.info.replacesCallId)
        assertFalse(plain.earlyVideo)
    }

    @Test
    fun anOrdinaryEndHasNoReason() {
        assertNull(ended(0, 0).error)
    }

    @Test
    fun networkEventMapping() {
        val event = EventDecoder.decode(network, 0, 0, longArrayOf(0, 0, 0, 0, 1), arrayOf(null, null, "192.0.2.10"), null)
        val net = (event as BaresipEvent.Network).network
        assertTrue(net.transportsReset)
        assertEquals("192.0.2.10", net.localAddress)
    }

    @Test
    fun anUnknownCoreValueIsNoKnownMediaEvent() {
        assertNull(BaresipMediaEvent.of(999))
        assertEquals(BaresipMediaEvent.RECORDING_STOPPED, BaresipMediaEvent.of(11))
        val n = LongArray(4 + 3)
        n[4] = 999
        val event = EventDecoder.decode(callMedia, 1, 7, n, arrayOf(null, null, null), null)
        assertNull((event as BaresipEvent.Media).info.event)
    }

    @Test
    fun hugeDurationsAreClamped() {
        assertEquals(Int.MAX_VALUE, Duration.INFINITE.wholeMilliseconds())
        assertEquals(Int.MAX_VALUE, Long.MAX_VALUE.seconds.wholeSeconds())
        assertEquals(0, (-5).seconds.wholeMilliseconds())
        assertEquals(1500, 1500.milliseconds.wholeMilliseconds())
    }

    @Test
    fun adaptiveBitrateDefaults() {
        val configuration = BaresipConfiguration(HostCore.instanceUuid)
        assertTrue(configuration.videoAdaptiveBitrate)
        assertEquals(150_000, configuration.videoMinimumBitrate)
    }
}
