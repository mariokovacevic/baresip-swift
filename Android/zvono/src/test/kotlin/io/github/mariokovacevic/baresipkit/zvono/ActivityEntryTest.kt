package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.zvono.model.ActivityEntry
import io.github.mariokovacevic.baresipkit.zvono.model.ActivityFormat
import io.github.mariokovacevic.baresipkit.zvono.model.CallRecord
import io.github.mariokovacevic.baresipkit.zvono.model.CallRow
import io.github.mariokovacevic.baresipkit.zvono.model.Door
import io.github.mariokovacevic.baresipkit.zvono.model.DtmfRequest
import io.github.mariokovacevic.baresipkit.zvono.model.DtmfState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale
import kotlin.time.Duration.Companion.seconds
import kotlin.time.TimeSource

class ActivityEntryTest {
    private val zone = ZoneOffset.UTC
    private val today = LocalDate.of(2026, 11, 12)
    private val format = ActivityFormat(zone, Locale.US) { today }
    private val noon = today.atTime(12, 0).toInstant(zone).toEpochMilli()
    private val door = Door(name = "Front door", address = "sip:frontdoor@pbx.example.com", code = "1234")
    private val doors = listOf(door)

    private fun record(
        uri: String = "sip:frontdoor@pbx.example.com",
        outgoing: Boolean = false,
        duration: Double? = null,
        dtmf: String = "",
        result: String? = null,
        elsewhere: String? = null,
        startedAt: Long = noon,
        video: Boolean = false,
        name: String = "Front door",
    ) = CallRecord(
        uri = uri,
        name = name,
        outgoing = outgoing,
        video = video,
        startedAt = startedAt,
        durationSeconds = duration,
        dtmf = dtmf,
        dtmfResult = result,
        elsewhere = elsewhere,
    )

    private fun entry(record: CallRecord) = ActivityEntry.list(listOf(record), doors).single()

    private fun ActivityEntry.plainSubtitle() = subtitle(format).replace('\u202f', ' ')

    @Test
    fun kindsFollowTheCallAndTheDoor() {
        assertEquals(ActivityEntry.Kind.MISSED, entry(record()).kind)
        assertEquals("Missed ring", entry(record()).title)
        assertEquals("Missed call", entry(record(uri = "sip:bob@pbx.example.com", name = "bob")).title)
        assertEquals(ActivityEntry.Kind.OPENED, entry(record(outgoing = true, duration = 6.0, dtmf = "1234", result = "sent")).kind)
        assertEquals("You opened the door", entry(record(outgoing = true, duration = 6.0, dtmf = "1234", result = "door opened")).title)
        assertEquals("Answered, door opened", entry(record(duration = 3.0, dtmf = "1234", result = "sent")).title)
        assertEquals(ActivityEntry.Kind.DOOR, entry(record(duration = 20.0)).kind)
        assertEquals("You looked at the door", entry(record(outgoing = true, duration = 20.0)).title)
        assertEquals(ActivityEntry.Kind.NOT_CONNECTED, entry(record(outgoing = true)).kind)
        assertEquals("Declined on another phone", entry(record(elsewhere = "declined")).title)
        assertEquals("Answered on another phone", entry(record(elsewhere = "answered")).title)
        val call = entry(record(uri = "sip:reception@pbx.example.com", outgoing = true, duration = 130.0, video = true, name = "Reception"))
        assertEquals(ActivityEntry.Kind.CALL, call.kind)
        assertEquals("Video call to Reception", call.title)
    }

    @Test
    fun subtitleShowsTheDoorTimeTalkAndCode() {
        assertEquals("Front door, 12:00 PM, talked 2:10", entry(record(duration = 130.0)).plainSubtitle())
        assertEquals("Front door, 12:00 PM, talked 0:04, code no reply", entry(record(duration = 4.0, dtmf = "1234", result = "no reply")).plainSubtitle())
        assertEquals("reception, 12:00 PM", entry(record(uri = "sip:reception@pbx.example.com", outgoing = true, duration = 0.4, name = "Reception")).plainSubtitle().substringBefore(", talked"))
    }

    @Test
    fun filtersAndDaysGroupTheList() {
        val yesterday = noon - 86_400_000
        val history =
            listOf(
                record(),
                record(outgoing = true, duration = 6.0, dtmf = "1234", result = "sent"),
                record(uri = "sip:reception@pbx.example.com", outgoing = true, duration = 10.0, startedAt = yesterday, name = "Reception"),
                record(startedAt = yesterday - 2 * 86_400_000),
            )
        val entries = ActivityEntry.list(history, doors)
        val all = ActivityEntry.days(entries, ActivityEntry.Filter.ALL, format)
        assertEquals(listOf("Today", "Yesterday", "Nov 9, 2026"), all.map { it.first })
        assertEquals(2, all.first().second.size)
        assertEquals(2, ActivityEntry.days(entries, ActivityEntry.Filter.MISSED, format).sumOf { it.second.size })
        assertEquals(1, ActivityEntry.days(entries, ActivityEntry.Filter.OPENED, format).sumOf { it.second.size })
        assertEquals(listOf("Yesterday"), ActivityEntry.days(entries, ActivityEntry.Filter.CALLS, format).map { it.first })
    }

    @Test
    fun repeatingKeepsTheCodeRequest() {
        val opened = record(outgoing = true, duration = 6.0, dtmf = "4711", result = "sent").copy(dtmfAck = "9", dtmfHangUp = false)
        assertEquals(DtmfRequest("4711", "9", false), opened.dtmfRequest)
        assertEquals("DTMF 4711, reply 9", opened.kindText)
        assertEquals("Video call", record(video = true).kindText)
        assertNull(record().dtmfRequest)
    }

    @Test
    fun aFinishedCallBecomesARecord() {
        val now = TimeSource.Monotonic.markNow()
        val row =
            CallRow(
                id = null,
                remoteUri = "sip:frontdoor@pbx.example.com",
                remoteName = "",
                state = BaresipCallState.ENDED,
                outgoing = true,
                startedAt = now - 20.seconds,
                connectedAt = now - 15.seconds,
            )
        val ended = System.currentTimeMillis()
        val record = CallRecord.of(row, DtmfState(DtmfRequest("1234", "", true), sent = true, result = "sent"), ended, null)
        assertEquals("frontdoor", record.name)
        assertEquals(15.0, record.durationSeconds!!, 1.0)
        assertEquals("1234", record.dtmf)
        assertEquals("sent", record.dtmfResult)
        assertEquals(ActivityEntry.Kind.OPENED, entry(record).kind)
        val unsent = CallRecord.of(row.copy(connectedAt = null), DtmfState(DtmfRequest("1234", "", true)), ended, null)
        assertEquals("not sent", unsent.dtmfResult)
        assertNull(unsent.durationSeconds)
        assertEquals(ActivityEntry.Kind.NOT_CONNECTED, entry(unsent).kind)
    }
}
