package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.zvono.model.Door
import io.github.mariokovacevic.baresipkit.zvono.model.SipNames
import io.github.mariokovacevic.baresipkit.zvono.model.matching
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DoorMatchingTest {
    private val front = Door(id = "front", name = "Front door", address = "sip:frontdoor@pbx.example.com:5061", code = "1234")
    private val gate = Door(id = "gate", name = "", address = "gate", code = "")
    private val doors = listOf(front, gate)

    @Test
    fun matchesByTheSipUserWhateverTheHostPortAndParameters() {
        assertEquals(front, doors.matching("sip:frontdoor@192.0.2.7;transport=tls"))
        assertEquals(front, doors.matching("sip:frontdoor@pbx.example.com"))
        assertEquals(gate, doors.matching("sips:gate@pbx.example.com"))
    }

    @Test
    fun doesNotMatchOtherUsersOrEmptyAddresses() {
        assertNull(doors.matching("sip:reception@pbx.example.com"))
        assertNull(doors.matching(""))
        assertNull(listOf(Door(address = "")).matching("sip:@pbx.example.com"))
    }

    @Test
    fun titleFallsBackToTheUserAndOpeningNeedsACode() {
        assertEquals("Front door", front.title)
        assertEquals("gate", gate.title)
        assertTrue(front.canOpen)
        assertFalse(gate.canOpen)
    }

    @Test
    fun openRequestCarriesTheCodeTheReplyDigitAndHangUp() {
        val door = front.copy(code = " 1234# ", replyDigit = "9", hangsUpAfterOpening = false)
        val request = door.openRequest
        assertEquals("1234#", request.digits)
        assertEquals('9', request.replyDigit)
        assertFalse(request.hangUp)
        assertNull(front.openRequest.replyDigit)
    }

    @Test
    fun destinationsAreCompletedWithTheDomain() {
        assertEquals("sip:100@pbx.example.com", SipNames.normalized(" 100 ", "pbx.example.com"))
        assertEquals("sip:desk@other.example.com", SipNames.normalized("desk@other.example.com", "pbx.example.com"))
        assertEquals("sips:door@pbx.example.com", SipNames.normalized("sips:door@pbx.example.com", "x"))
        assertEquals("", SipNames.normalized("  ", "pbx.example.com"))
        assertEquals("door@pbx.example.com", SipNames.address("sip:door@pbx.example.com;transport=tls"))
        assertEquals("FD", SipNames.initials("Front door"))
        assertEquals("G", SipNames.initials("gate"))
    }
}
