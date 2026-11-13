package io.github.mariokovacevic.baresipkit.zvono.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

class ActivityFormat(
    val zone: ZoneId = ZoneId.systemDefault(),
    val locale: Locale = Locale.getDefault(),
    val today: () -> LocalDate = { LocalDate.now(zone) },
) {
    private val time = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale)
    private val date = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale)
    private val dateTime = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT).withLocale(locale)

    fun time(millis: Long): String = time.format(Instant.ofEpochMilli(millis).atZone(zone))

    fun date(millis: Long): String = date.format(Instant.ofEpochMilli(millis).atZone(zone))

    fun dateTime(millis: Long): String = dateTime.format(Instant.ofEpochMilli(millis).atZone(zone))

    fun day(millis: Long): String {
        val day = Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()
        val now = today()
        return when (day) {
            now -> TODAY
            now.minusDays(1) -> "Yesterday"
            else -> date(millis)
        }
    }

    companion object {
        const val TODAY = "Today"
    }
}

data class ActivityEntry(
    val record: CallRecord,
    val door: Door?,
) {
    enum class Kind { MISSED, ELSEWHERE, OPENED, DOOR, CALL, NOT_CONNECTED }

    enum class Filter(
        val title: String,
    ) {
        ALL("All"),
        MISSED("Missed"),
        OPENED("Opened"),
        CALLS("Calls"),
        ;

        fun includes(kind: Kind): Boolean =
            when (this) {
                ALL -> true
                MISSED -> kind == Kind.MISSED
                OPENED -> kind == Kind.OPENED
                CALLS -> kind == Kind.CALL || kind == Kind.NOT_CONNECTED || kind == Kind.ELSEWHERE
            }
    }

    val id: String
        get() = record.id

    val kind: Kind
        get() {
            val result = record.dtmfResult
            if (record.dtmf.isNotEmpty() && (result == "sent" || result == "door opened")) return Kind.OPENED
            if (record.durationSeconds == null) {
                if (record.elsewhere != null) return Kind.ELSEWHERE
                return if (record.outgoing) Kind.NOT_CONNECTED else Kind.MISSED
            }
            return if (door == null) Kind.CALL else Kind.DOOR
        }

    val title: String
        get() =
            when (kind) {
                Kind.MISSED -> if (door == null) "Missed call" else "Missed ring"
                Kind.ELSEWHERE -> if (record.elsewhere == "declined") "Declined on another phone" else "Answered on another phone"
                Kind.OPENED -> if (record.outgoing) "You opened the door" else "Answered, door opened"
                Kind.DOOR -> if (record.outgoing) "You looked at the door" else "Answered"
                Kind.NOT_CONNECTED -> "Not connected"
                Kind.CALL -> "${if (record.video) "Video call" else "Call"} ${if (record.outgoing) "to" else "from"} ${record.name}"
            }

    fun subtitle(format: ActivityFormat): String {
        val parts = mutableListOf(door?.title ?: if (kind == Kind.CALL) SipNames.user(record.uri) else record.name)
        parts += format.time(record.startedAt)
        record.talkTime?.let { parts += "talked $it" }
        if (record.dtmf.isNotEmpty() && kind != Kind.OPENED) parts += "code ${record.dtmfResult ?: "not sent"}"
        return parts.joinToString(", ")
    }

    fun day(format: ActivityFormat): String = format.day(record.startedAt)

    companion object {
        fun list(
            history: List<CallRecord>,
            doors: List<Door>,
        ): List<ActivityEntry> = history.map { ActivityEntry(it, doors.matching(it.user)) }

        fun days(
            entries: List<ActivityEntry>,
            filter: Filter,
            format: ActivityFormat,
        ): List<Pair<String, List<ActivityEntry>>> {
            val result = mutableListOf<Pair<String, MutableList<ActivityEntry>>>()
            for (entry in entries) {
                if (!filter.includes(entry.kind)) continue
                val day = entry.day(format)
                val last = result.lastOrNull()
                if (last != null && last.first == day) last.second += entry else result += day to mutableListOf(entry)
            }
            return result
        }
    }
}
