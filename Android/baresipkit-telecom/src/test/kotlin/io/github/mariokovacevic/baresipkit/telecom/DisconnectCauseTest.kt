package io.github.mariokovacevic.baresipkit.telecom

import android.telecom.DisconnectCause
import io.github.mariokovacevic.baresipkit.BaresipCallEndReason
import io.github.mariokovacevic.baresipkit.BaresipError
import org.junit.Assert.assertEquals
import org.junit.Test

class DisconnectCauseTest {
    private fun sip(status: Int) = BaresipError(BaresipError.Code.SIP, sipStatus = status)

    @Test
    fun aNormalEndIsRemote() {
        assertEquals(DisconnectCause.REMOTE, BaresipTelecomAdapter.disconnectCode(null))
    }

    @Test
    fun aCallTakenElsewhereIsReportedSo() {
        val answered = BaresipError(BaresipError.Code.OK, sipStatus = 200, endReason = BaresipCallEndReason.ANSWERED_ELSEWHERE)
        val declined = BaresipError(BaresipError.Code.OK, sipStatus = 603, endReason = BaresipCallEndReason.DECLINED_ELSEWHERE)
        assertEquals(DisconnectCause.ANSWERED_ELSEWHERE, BaresipTelecomAdapter.disconnectCode(answered))
        assertEquals(DisconnectCause.REJECTED, BaresipTelecomAdapter.disconnectCode(declined))
    }

    @Test
    fun aReplacedCallIsNoError() {
        val replaced = BaresipError(BaresipError.Code.OK, endReason = BaresipCallEndReason.REPLACED)
        assertEquals(DisconnectCause.REMOTE, BaresipTelecomAdapter.disconnectCode(replaced))
    }

    @Test
    fun busyAndDeclineAreNotErrors() {
        assertEquals(DisconnectCause.BUSY, BaresipTelecomAdapter.disconnectCode(sip(486)))
        assertEquals(DisconnectCause.REJECTED, BaresipTelecomAdapter.disconnectCode(sip(600)))
        assertEquals(DisconnectCause.REJECTED, BaresipTelecomAdapter.disconnectCode(sip(603)))
        assertEquals(DisconnectCause.ERROR, BaresipTelecomAdapter.disconnectCode(sip(500)))
        assertEquals(DisconnectCause.ERROR, BaresipTelecomAdapter.disconnectCode(BaresipError(BaresipError.Code.NETWORK)))
    }
}
