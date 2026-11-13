package io.github.mariokovacevic.baresipkit.compose

import io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration
import io.github.mariokovacevic.baresipkit.BaresipAccountID
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipEvent
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.BaresipTransport
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import kotlin.time.Duration.Companion.seconds

class BaresipPhoneTest {
    @Before
    fun hostCore() = requireHostCore()

    @Test
    fun registrationEventsUpdateTheAccountState() =
        runBlocking {
            val phone = phone()
            val account = BaresipAccountID(7)
            phone.apply(BaresipEvent.Registration(account, BaresipRegistrationState.REGISTERING, null, null))
            assertEquals(BaresipRegistrationState.REGISTERING, phone.registrations[account])
            phone.apply(BaresipEvent.Registration(account, BaresipRegistrationState.REGISTERED, 600.seconds, null))
            assertEquals(BaresipRegistrationState.REGISTERED, phone.registrations[account])
        }

    @Test
    fun synchronizeKeepsRegistrationsOfAStoppedEngine() =
        runBlocking {
            val phone = phone()
            val account = BaresipAccountID(7)
            phone.apply(BaresipEvent.Registration(account, BaresipRegistrationState.REGISTERED, 600.seconds, null))
            phone.synchronize()
            assertEquals(BaresipRegistrationState.REGISTERED, phone.registrations[account])
        }

    @Test
    fun synchronizeReadsTheAccountsOfARunningEngine() =
        runBlocking {
            val phone = phone()
            phone.engine.start()
            val account = phone.engine.addAccount(BaresipAccountConfiguration(aor = "sip:alice@example.invalid", transport = BaresipTransport.UDP))
            phone.synchronize()
            val listed = phone.engine.accounts()
            phone.engine.stop()
            phone.engine.close()
            assertEquals(BaresipRegistrationState.NONE, phone.registrations[account])
            assertEquals(mapOf(account to BaresipRegistrationState.NONE), listed)
        }

    @Test
    fun callEventsTrackTheCallUntilReleased() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(42)
            phone.apply(state(id, BaresipCallState.OUTGOING_RINGING))
            assertEquals(listOf(id), phone.calls.map { it.id })
            assertEquals(BaresipCallState.OUTGOING_RINGING, phone.call(id)?.state)
            phone.apply(state(id, BaresipCallState.PAUSED))
            assertEquals(true, phone.call(id)?.isOnHold)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            assertEquals(true, phone.call(id)?.isConnected)
            assertEquals(false, phone.call(id)?.isOnHold)
            phone.apply(state(id, BaresipCallState.RELEASED))
            assertTrue(phone.calls.isEmpty())
        }

    @Test
    fun aFailedCallKeepsItsError() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(9)
            phone.apply(BaresipEvent.Call(id, BaresipCallState.FAILED, BaresipError(BaresipError.Code.NETWORK, detail = "unreachable")))
            assertEquals(BaresipCallState.FAILED, phone.call(id)?.state)
            assertEquals(BaresipError.Code.NETWORK, phone.call(id)?.error?.code)
        }

    @Test
    fun eachCallIsTrackedOnce() =
        runBlocking {
            val phone = phone()
            val first = BaresipCallID(1)
            val second = BaresipCallID(2)
            phone.apply(state(first, BaresipCallState.INCOMING))
            phone.apply(state(second, BaresipCallState.OUTGOING_INIT))
            phone.apply(state(first, BaresipCallState.EARLY_MEDIA))
            assertEquals(listOf(first, second), phone.calls.map { it.id })
            assertEquals(first, phone.incomingCall?.id)
        }

    @Test
    fun aReleasedCallIsNotTrackedAgain() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(5)
            phone.apply(state(id, BaresipCallState.CONNECTED))
            phone.apply(state(id, BaresipCallState.RELEASED))
            phone.apply(state(id, BaresipCallState.ENDED))
            assertTrue(phone.calls.isEmpty())
        }

    @Test
    fun earlyMediaOfUnknownDirectionIsNotIncoming() =
        runBlocking {
            val phone = phone()
            phone.apply(state(BaresipCallID(3), BaresipCallState.EARLY_MEDIA))
            assertNull(phone.incomingCall)
            assertEquals(false, phone.calls.first().isDirectionKnown)
        }

    @Test
    fun anOutgoingCallInEarlyMediaIsNotIncoming() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(4)
            phone.apply(state(id, BaresipCallState.OUTGOING_RINGING))
            phone.apply(state(id, BaresipCallState.EARLY_MEDIA))
            assertNull(phone.incomingCall)
            assertEquals(true, phone.call(id)?.isOutgoing)
        }

    @Test
    fun holdStates() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(6)
            phone.apply(state(id, BaresipCallState.RESUMING))
            assertEquals(true, phone.call(id)?.isOnHold)
            phone.apply(state(id, BaresipCallState.PAUSED_BY_REMOTE))
            assertEquals(false, phone.call(id)?.isOnHold)
            assertEquals(true, phone.call(id)?.isHeldByRemote)
        }

    @Test
    fun snapshotsUpdateOrAddCallsButDoNotBringBackReleasedOnes() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(10)
            phone.apply(state(id, BaresipCallState.INCOMING))
            assertEquals(id, phone.incomingCall?.id)
            val refreshed = phone.applySnapshot(id, BaresipCallState.CONNECTED)
            assertSame(phone.call(id), refreshed)
            assertEquals(BaresipCallState.CONNECTED, phone.call(id)?.state)
            assertNull(phone.incomingCall)
            assertNotNull(phone.applySnapshot(BaresipCallID(11), BaresipCallState.STREAMS_RUNNING))
            phone.apply(state(id, BaresipCallState.RELEASED))
            assertNull(phone.applySnapshot(id, BaresipCallState.CONNECTED))
            assertFalse(phone.calls.any { it.id == id })
        }

    @Test
    fun synchronizeRemovesCallsTheEngineNoLongerHas() =
        runBlocking {
            val phone = phone()
            val id = BaresipCallID(8)
            phone.apply(state(id, BaresipCallState.STREAMS_RUNNING))
            phone.synchronize()
            assertTrue(phone.calls.isEmpty())
            phone.apply(state(id, BaresipCallState.ENDED))
            assertTrue(phone.calls.isEmpty())
        }
}
