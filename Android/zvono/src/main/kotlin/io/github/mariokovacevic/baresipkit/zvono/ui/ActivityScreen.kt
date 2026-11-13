package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.github.mariokovacevic.baresipkit.zvono.model.ActivityEntry
import io.github.mariokovacevic.baresipkit.zvono.model.ActivityFormat
import io.github.mariokovacevic.baresipkit.zvono.model.AppTab
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.CallRecord
import io.github.mariokovacevic.baresipkit.zvono.model.Repeat
import io.github.mariokovacevic.baresipkit.zvono.model.activity
import io.github.mariokovacevic.baresipkit.zvono.model.open
import io.github.mariokovacevic.baresipkit.zvono.model.redial
import io.github.mariokovacevic.baresipkit.zvono.model.removeRecord
import io.github.mariokovacevic.baresipkit.zvono.model.repeatCall

@Composable
fun ActivityScreen(model: CallModel) {
    var filter by rememberSaveable { mutableStateOf(ActivityEntry.Filter.ALL) }
    var confirmClear by remember { mutableStateOf(false) }
    val format = remember { ActivityFormat() }
    val days = ActivityEntry.days(model.activity, filter, format)
    Page(actions = { TextAction("Clear", color = Palette.alert, enabled = model.history.isNotEmpty()) { confirmClear = true } }) {
        ScreenTitle("Activity")
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (choice in ActivityEntry.Filter.entries) FilterChip(choice.title, filter == choice) { filter = choice }
        }
        if (days.isEmpty()) Note(if (model.history.isEmpty()) "Rings, calls and opened doors appear here." else "Nothing here.")
        for ((day, entries) in days) {
            TitledSection(day) {
                Card {
                    entries.forEachIndexed { index, entry ->
                        if (index > 0) RowDivider()
                        ActivityRow(model, entry, format)
                    }
                }
            }
        }
        if (model.history.isNotEmpty()) {
            Note("The button on the right repeats the call or the opening. Pictures stay on this phone with the last ${CallRecord.LIMIT} entries.")
        }
    }
    if (confirmClear) ConfirmDialog("Clear all activity?", "Clear", onDismiss = { confirmClear = false }) { model.history = emptyList() }
}

@Composable
fun ActivityRow(
    model: CallModel,
    entry: ActivityEntry,
    format: ActivityFormat,
) {
    var showOptions by remember { mutableStateOf(false) }
    val record = entry.record
    Row(
        Modifier.fillMaxWidth().padding(start = 12.dp, end = 6.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            Modifier.weight(1f).clickable(onClickLabel = "Show options to call again") { showOptions = true }.testTag("recents.row"),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Thumbnail(model, entry)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    entry.title,
                    style = Type.subheadlineStrong,
                    color = if (entry.kind == ActivityEntry.Kind.MISSED) Palette.alert else Palette.text,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(entry.subtitle(format), style = Type.footnote, color = Palette.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Spacer(Modifier.width(6.dp))
        val opened = entry.kind == ActivityEntry.Kind.OPENED
        Box(
            Modifier
                .size(44.dp)
                .clip(CircleShape)
                .clickable(role = Role.Button) {
                    val door = entry.door
                    model.act { if (opened && door != null) open(door) else repeatCall(record, Repeat.SAME) }
                }.semantics { contentDescription = if (opened) "Open again" else "Call again" },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                when {
                    opened -> Icons.Filled.Key
                    record.video -> Icons.Outlined.Videocam
                    else -> Icons.Filled.Call
                },
                contentDescription = null,
                tint = if (opened) Palette.brass else Palette.info,
                modifier = Modifier.size(20.dp),
            )
        }
    }
    if (showOptions) {
        val choices = mutableListOf<Pair<String, () -> Unit>>()
        choices += "Repeat: ${record.kindText}" to { model.act { repeatCall(record, Repeat.SAME) } }
        if (record.dtmfRequest != null || record.video) choices += "Audio call" to { model.act { repeatCall(record, Repeat.AUDIO) } }
        if (record.dtmfRequest != null || !record.video) choices += "Video call" to { model.act { repeatCall(record, Repeat.VIDEO) } }
        choices += "Edit address" to {
            model.redial(record)
            model.tab = AppTab.KEYPAD
        }
        choices += "Remove from Activity" to { model.removeRecord(record) }
        ChoiceDialog(record.name, record.uri, choices) { showOptions = false }
    }
}

@Composable
private fun Thumbnail(
    model: CallModel,
    entry: ActivityEntry,
) {
    val shape = RoundedCornerShape(10.dp)
    val image = entry.record.snapshotFile?.let { model.snapshots.image(it) }
    val frame = Modifier.size(width = 60.dp, height = 46.dp)
    when {
        image != null -> CameraPicture(image, frame.clip(shape).border(1.dp, Palette.field, shape))
        entry.kind == ActivityEntry.Kind.OPENED ->
            Box(frame.clip(shape).background(Palette.brassSoft).border(1.dp, Palette.brassLine, shape), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Key, contentDescription = null, tint = Palette.brass, modifier = Modifier.size(20.dp))
            }
        entry.door != null -> CameraPicture(null, frame.clip(shape).border(1.dp, Palette.field, shape), markSize = 24.dp)
        else -> Box(frame, contentAlignment = Alignment.Center) { Avatar(entry.record.initials, size = 46.dp, corner = 10.dp) }
    }
}
