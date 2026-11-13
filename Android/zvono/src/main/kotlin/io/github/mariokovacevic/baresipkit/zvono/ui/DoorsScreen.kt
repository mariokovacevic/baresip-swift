package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.zvono.model.ActivityFormat
import io.github.mariokovacevic.baresipkit.zvono.model.AppTab
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.CallRecord
import io.github.mariokovacevic.baresipkit.zvono.model.CallText
import io.github.mariokovacevic.baresipkit.zvono.model.Door
import io.github.mariokovacevic.baresipkit.zvono.model.Screen
import io.github.mariokovacevic.baresipkit.zvono.model.activeRow
import io.github.mariokovacevic.baresipkit.zvono.model.activity
import io.github.mariokovacevic.baresipkit.zvono.model.callOnScreen
import io.github.mariokovacevic.baresipkit.zvono.model.calls
import io.github.mariokovacevic.baresipkit.zvono.model.lastPicture
import io.github.mariokovacevic.baresipkit.zvono.model.lastRecord
import io.github.mariokovacevic.baresipkit.zvono.model.look
import io.github.mariokovacevic.baresipkit.zvono.model.open

@Composable
fun DoorsScreen(model: CallModel) {
    Page(actions = { RoundIcon(Icons.Filled.Add, "Add a door", size = 40.dp) { model.open(Screen.DoorEditor(null)) } }) {
        ScreenTitle("Doors")
        if (model.callOnScreen != null && model.callMinimized) ReturnToCallBar(model)
        ReachabilityLine(model)
        if (model.doors.isEmpty()) AddFirstDoor(model)
        for (door in model.doors) DoorCard(model, door)
        TodaySection(model)
    }
}

@Composable
private fun AddFirstDoor(model: CallModel) {
    Card {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Add your door", style = Type.display(22.sp), color = Palette.text)
            Text(
                "Enter the door station's SIP user and the code that opens it. Rings from it then show its picture and an Open button.",
                style = Type.subheadline,
                color = Palette.secondary,
            )
            FilledButton("Add a door", ButtonKind.BRASS, icon = Icons.Filled.Add, height = 48.dp) { model.open(Screen.DoorEditor(null)) }
        }
    }
}

@Composable
private fun TodaySection(model: CallModel) {
    val format = ActivityFormat()
    val today = model.activity.takeWhile { it.day(format) == ActivityFormat.TODAY }.take(3)
    if (today.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionTitle("Today")
            Spacer(Modifier.weight(1f))
            TextAction("See all") { model.tab = AppTab.ACTIVITY }
        }
        Card {
            today.forEachIndexed { index, entry ->
                if (index > 0) RowDivider()
                ActivityRow(model, entry, format)
            }
        }
    }
}

@Composable
fun ReachabilityLine(model: CallModel) {
    val (text, color) =
        when (model.registration) {
            BaresipRegistrationState.REGISTERED ->
                (
                    if (model.settings.reachableInBackground) {
                        "Reachable. Rings arrive even when the app is closed."
                    } else {
                        "Reachable while Zvono is open. Turn on push in Settings to get rings when it is closed."
                    }
                ) to Palette.info
            BaresipRegistrationState.REGISTERING -> "Connecting to ${model.settings.domain.trim()}…" to Palette.brass
            BaresipRegistrationState.UNREGISTERING -> "Signing out…" to Palette.brass
            BaresipRegistrationState.FAILED -> "Not connected${model.registrationError?.let { ": $it" }.orEmpty()}" to Palette.alert
            BaresipRegistrationState.NONE -> (model.registrationError ?: "Offline") to Palette.secondary
        }
    Row(
        Modifier.semantics(mergeDescendants = true) {}.testTag("doors.reachability"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        StatusDot(color)
        Text(text, style = Type.footnote, color = Palette.secondary, maxLines = 2)
    }
}

@Composable
fun ReturnToCallBar(model: CallModel) {
    rememberTick()
    val row = model.activeRow
    val count = model.calls.size
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 60.dp)
            .clip(shape)
            .background(Palette.raised)
            .border(1.dp, Palette.raisedLine, shape)
            .clickable(role = Role.Button) { if (count > 1) model.open(Screen.Calls) else model.callMinimized = false }
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        StatusDot(Palette.info)
        Column(Modifier.weight(1f)) {
            Text(if (count > 1) "$count calls" else row?.title ?: "Call", style = Type.subheadlineStrong, color = Palette.text)
            if (row != null) Text(CallText.status(row), style = Type.footnote, color = Palette.info)
        }
        Text("Return", style = Type.subheadlineStrong, color = Palette.info)
    }
}

@Composable
fun DoorCard(
    model: CallModel,
    door: Door,
) {
    Card {
        Row(
            Modifier.padding(start = if (door.hasCamera) 12.dp else 16.dp, end = 14.dp, top = 12.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (door.hasCamera) DoorThumbnail(model, door)
            Column(
                Modifier
                    .weight(1f)
                    .heightIn(min = 48.dp)
                    .clickable { model.open(Screen.DoorEditor(door.id)) },
                verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
            ) {
                Text(door.title, style = Type.display(22.sp), color = Palette.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                val record = model.lastRecord(door)
                if (record != null) {
                    val missed = record.durationSeconds == null && !record.outgoing
                    Text(ringText(record), style = Type.footnote, color = if (missed) Palette.alert else Palette.secondary, maxLines = 1)
                } else {
                    val kind = if (door.hasCamera) "With camera" else "Audio only"
                    Text(if (door.canOpen) kind else "$kind, no code set", style = Type.footnote, color = Palette.secondary, maxLines = 1)
                }
            }
            if (door.canOpen) {
                FilledButton(
                    "Open",
                    ButtonKind.BRASS,
                    icon = Icons.Filled.Key,
                    height = 48.dp,
                    expands = false,
                    modifier = Modifier.testTag("door.open").semantics { contentDescription = "Open ${door.title}" },
                ) { model.act { open(door) } }
            } else {
                FilledButton("Call", ButtonKind.RAISED, icon = Icons.Filled.Call, height = 48.dp, expands = false) { model.act { look(door) } }
            }
        }
    }
}

@Composable
private fun DoorThumbnail(
    model: CallModel,
    door: Door,
) {
    val shape = RoundedCornerShape(12.dp)
    val image = model.lastPicture(door)?.let { model.snapshots.image(it) }
    Box(
        Modifier
            .size(64.dp)
            .clip(shape)
            .border(1.dp, Palette.line, shape)
            .clickable(role = Role.Button) { model.act { look(door) } }
            .semantics { contentDescription = "Look at ${door.title}" }
            .testTag("door.look"),
    ) {
        CameraPicture(image, Modifier.size(64.dp), markSize = 26.dp)
        Box(
            Modifier
                .align(Alignment.BottomEnd)
                .padding(4.dp)
                .size(20.dp)
                .clip(CircleShape)
                .background(Palette.bar),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Videocam, contentDescription = null, tint = Palette.text, modifier = Modifier.size(12.dp))
        }
    }
}

private fun ringText(record: CallRecord): String {
    val time = ActivityFormat().time(record.startedAt)
    if (record.outgoing) return if (record.dtmf.isEmpty()) "Called $time" else "Opened $time"
    return if (record.durationSeconds == null) "Rang $time, missed" else "Rang $time, answered"
}
