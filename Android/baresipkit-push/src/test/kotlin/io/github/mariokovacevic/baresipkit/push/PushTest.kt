package io.github.mariokovacevic.baresipkit.push

import io.github.mariokovacevic.baresipkit.BaresipAccountID
import io.github.mariokovacevic.baresipkit.BaresipContactParameter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class PushTest {
    @Test
    fun tokensBecomeContactParameters() {
        val tokens = BaresipPushTokens("com.example.app", token = "abc:APA91b")
        assertEquals(
            listOf(
                BaresipContactParameter("app-id", "com.example.app"),
                BaresipContactParameter("pn-type", "firebase"),
                BaresipContactParameter("pn-tok", "abc:APA91b"),
                BaresipContactParameter("pn-silent", "1"),
                BaresipContactParameter("pn-timeout", "0"),
            ),
            tokens.contactParameters,
        )
        assertFalse(BaresipPushTokens("com.example.app").contactParameters.any { it.name == "pn-tok" })
        assertTrue(BaresipPushTokens("a", channel = "calls").contactParameters.contains(BaresipContactParameter("pn-channel", "calls")))
    }

    @Test
    fun additionalParametersNeverReplacePushOnes() {
        val merged =
            BaresipPushTokens("com.example.app", token = "t").mergedContactParameters(
                listOf(BaresipContactParameter("PN-TOK", "evil"), BaresipContactParameter("x-tenant", "7")),
            )
        assertEquals(1, merged.count { it.name.lowercase() == "pn-tok" })
        assertEquals("t", merged.first { it.name == "pn-tok" }.value)
        assertTrue(merged.contains(BaresipContactParameter("x-tenant", "7")))
    }

    @Test
    fun aPushPayloadNamesTheCall() {
        val uuid = UUID.randomUUID()
        val call = BaresipPushCall.from(mapOf("from" to "sip:door@pbx.example.com", "name" to "Front door", "video" to "true", "uuid" to uuid.toString()))
        assertEquals(BaresipPushCall("sip:door@pbx.example.com", "Front door", true, uuid), call)
        assertEquals(false, BaresipPushCall.from(mapOf("from" to "sip:a@b", "video" to "0"))?.hasVideo)
        assertNull(BaresipPushCall.from(mapOf("uuid" to "not-a-uuid", "from" to "sip:a@b"))?.uuid)
    }

    @Test
    fun aMessageWithoutACallIsNotOne() {
        assertNull(BaresipPushCall.from(emptyMap()))
        assertNull(BaresipPushCall.from(mapOf("text" to "hello")))
        assertNull(BaresipPushCall.from(mapOf("type" to "message", "from" to "sip:a@b")))
    }

    @Test
    fun contactParameterUpdatesSendOnlyTheLatestWhileOneIsInFlight() {
        val updates = ContactParameterUpdates()
        val account = BaresipAccountID(1)
        val first = ContactParameterUpdates.Request(account, listOf(BaresipContactParameter("pn-tok", "1")))
        val second = ContactParameterUpdates.Request(account, listOf(BaresipContactParameter("pn-tok", "2")))
        val third = ContactParameterUpdates.Request(account, listOf(BaresipContactParameter("pn-tok", "3")))
        assertTrue(updates.submit(first))
        assertEquals(first, updates.next())
        assertFalse(updates.submit(second))
        assertFalse(updates.submit(third))
        assertEquals(third, updates.next())
        assertNull(updates.next())
        assertTrue(updates.submit(first))
    }
}
