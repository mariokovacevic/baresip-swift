package io.github.mariokovacevic.baresipkit.telecom

import androidx.core.telecom.CallControlResult
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.fail
import org.junit.Test
import kotlin.time.Duration.Companion.seconds

class TelecomActionsTest {
    @Test
    fun aSuccessfulActionReturns() =
        runTest {
            TelecomActions.perform(10.seconds, "answer") { CallControlResult.Success() }
            assertEquals("ready", TelecomActions.ready(CompletableDeferred("ready"), 10.seconds, "addCall"))
        }

    @Test
    fun aRefusedActionFailsItsCallerWithTheTelecomError() =
        runTest {
            val error = failure { TelecomActions.perform(10.seconds, "setInactive") { CallControlResult.Error(3) } }
            assertEquals(BaresipTelecomException.Reason.REFUSED, error.reason)
            assertEquals("setInactive", error.action)
            assertEquals(3, error.errorCode)
        }

    @Test
    fun aTimedOutActionFailsItsCaller() =
        runTest {
            val error = failure { TelecomActions.perform(10.seconds, "disconnect") { awaitCancellation() } }
            assertEquals(BaresipTelecomException.Reason.ACTION_TIMED_OUT, error.reason)
            assertNull(error.errorCode)
        }

    @Test
    fun aCallTelecomNeverAddsTimesOut() =
        runTest {
            val error = failure { TelecomActions.ready(CompletableDeferred<String>(), 10.seconds, "addCall") }
            assertEquals(BaresipTelecomException.Reason.ACTION_TIMED_OUT, error.reason)
            assertEquals("addCall", error.action)
        }

    private suspend fun failure(block: suspend () -> Unit): BaresipTelecomException {
        try {
            block()
        } catch (error: BaresipTelecomException) {
            return error
        }
        fail("the action did not fail")
        throw AssertionError()
    }
}
