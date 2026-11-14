package io.github.mariokovacevic.baresipkit.telecom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BaresipRedialRequestTest {
    private val call = "android.intent.action.CALL"
    private val dial = "android.intent.action.DIAL"
    private val view = "android.intent.action.VIEW"

    @Test
    fun sipUriIsKeptWhole() {
        assertEquals(
            BaresipRedialRequest("sip:frontdoor@pbx.example.com", false),
            BaresipRedialRequest.parse(view, "sip:frontdoor@pbx.example.com", 0),
        )
        assertEquals(
            BaresipRedialRequest("sips:alice@example.com;transport=tls", false, callsNow = true),
            BaresipRedialRequest.parse(call, "sips:alice%40example.com;transport=tls", 0),
        )
    }

    @Test
    fun telUriGivesTheNumber() {
        assertEquals(BaresipRedialRequest("+15555550199", false, callsNow = true), BaresipRedialRequest.parse(call, "tel:%2B1-555-555%200199", 0))
        assertEquals(BaresipRedialRequest("+15555550199", false), BaresipRedialRequest.parse(dial, "tel:+15555550199;phone-context=example.com", 0))
        assertEquals(BaresipRedialRequest("1010", false), BaresipRedialRequest.parse(dial, "tel:1010", 0))
    }

    @Test
    fun videoStateAsksForVideo() {
        assertEquals(true, BaresipRedialRequest.parse(call, "sip:door@example.com", 3)?.video)
        assertEquals(true, BaresipRedialRequest.parse(call, "sip:door@example.com", 1)?.video)
        assertEquals(false, BaresipRedialRequest.parse(call, "sip:door@example.com", 0)?.video)
    }

    @Test
    fun onlyCallStartsTheCallAtOnce() {
        assertEquals(true, BaresipRedialRequest.parse(call, "sip:door@example.com", 0)?.callsNow)
        assertEquals(true, BaresipRedialRequest.parse("android.intent.action.CALL_PRIVILEGED", "sip:door@example.com", 0)?.callsNow)
        assertEquals(false, BaresipRedialRequest.parse(dial, "sip:door@example.com", 0)?.callsNow)
        assertEquals(false, BaresipRedialRequest.parse(view, "sip:door@example.com", 0)?.callsNow)
    }

    @Test
    fun otherIntentsAreNoRequest() {
        assertNull(BaresipRedialRequest.parse("android.intent.action.MAIN", "sip:door@example.com", 0))
        assertNull(BaresipRedialRequest.parse(call, "https://example.com", 0))
        assertNull(BaresipRedialRequest.parse(call, "sip:", 0))
        assertNull(BaresipRedialRequest.parse(call, "tel:", 0))
        assertNull(BaresipRedialRequest.parse(call, null, 0))
    }
}
