package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.zvono.model.CallCaption
import io.github.mariokovacevic.baresipkit.zvono.model.CallRow
import io.github.mariokovacevic.baresipkit.zvono.model.CallText
import io.github.mariokovacevic.baresipkit.zvono.model.ChatMessage
import io.github.mariokovacevic.baresipkit.zvono.model.ChatStatus
import io.github.mariokovacevic.baresipkit.zvono.model.Conversations
import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Duration.Companion.seconds

class CaptionTest {
    @Test
    fun captionsStayFourSecondsAndALittleMorePerWordAtMostTen() {
        assertEquals(4000.milliseconds, CallCaption(0, "Door", "").lifetime)
        assertEquals(4300.milliseconds, CallCaption(0, "Door", "Hello").lifetime)
        assertEquals(6100.milliseconds, CallCaption(0, "Door", "A parcel is waiting  at\nthe desk").lifetime)
        assertEquals(10.seconds, CallCaption(0, "Door", List(40) { "word" }.joinToString(" ")).lifetime)
    }

    @Test
    fun atMostThreeCaptionsShowTheNewest() {
        var shown = emptyList<CallCaption>()
        for (id in 0L..4L) shown = CallCaption.adding(shown, CallCaption(id, "Door", "message $id"))
        assertEquals(listOf(2L, 3L, 4L), shown.map { it.id })
    }

    @Test
    fun unreadMessagesCountPerPeer() {
        val messages =
            listOf(
                ChatMessage(peer = "sip:frontdoor@pbx.example.com", text = "Hi", outgoing = false, status = ChatStatus.Received, read = false),
                ChatMessage(peer = "sip:frontdoor@192.0.2.2", text = "Again", outgoing = false, status = ChatStatus.Received, read = false),
                ChatMessage(peer = "sip:reception@pbx.example.com", text = "Parcel", outgoing = false, status = ChatStatus.Received, read = false),
                ChatMessage(peer = "sip:frontdoor@pbx.example.com", text = "Mine", outgoing = true, status = ChatStatus.Delivered, read = false),
            )
        assertEquals(3, Conversations.unread(messages))
        assertEquals(2, Conversations.unread(messages, "sip:frontdoor@pbx.example.com"))
        assertEquals(listOf("frontdoor", "reception"), Conversations.of(messages).map { it.peer })
    }

    @Test
    fun durationsAndStatusText() {
        assertEquals("00:09", CallText.duration(9.seconds))
        assertEquals("02:10", CallText.duration(130.seconds))
        assertEquals("1:01:01", CallText.duration(61.minutes + 1.seconds))
        val row = CallRow(id = null, remoteUri = "sip:bob@pbx.example.com", remoteName = "", state = BaresipCallState.OUTGOING_RINGING, outgoing = true)
        assertEquals("Ringing…", CallText.status(row))
        assertEquals("Held by the other side", CallText.status(row.copy(state = BaresipCallState.PAUSED_BY_REMOTE)))
        assertEquals("bob", row.title)
    }
}
