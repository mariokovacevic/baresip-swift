package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import io.github.mariokovacevic.baresipkit.zvono.model.ActivityFormat
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.Door
import io.github.mariokovacevic.baresipkit.zvono.model.DtmfRequest
import io.github.mariokovacevic.baresipkit.zvono.model.lastRecord
import io.github.mariokovacevic.baresipkit.zvono.model.look
import io.github.mariokovacevic.baresipkit.zvono.model.remove
import io.github.mariokovacevic.baresipkit.zvono.model.save

@Composable
fun DoorScreen(
    model: CallModel,
    doorId: String?,
) {
    val existing = model.doors.firstOrNull { it.id == doorId }
    val isNew = existing == null
    var draft by remember(doorId) { mutableStateOf(existing ?: Door()) }
    var confirmRemove by remember { mutableStateOf(false) }

    fun change(updated: Door) {
        draft = updated
        if (!isNew) model.save(updated)
    }
    Page(onBack = { model.back() }) {
        ScreenTitle(if (isNew) "New door" else draft.title)
        if (!isNew && draft.hasCamera) DoorPicture(model, draft)
        StackedField("Name", draft.name, { change(draft.copy(name = it)) }, "Front door", tag = "door.name")
        StackedField(
            "Door station (SIP user or address)",
            draft.address,
            { change(draft.copy(address = it)) },
            "door1 or sip:door1@pbx.example.com",
            keyboardType = KeyboardType.Email,
            tag = "door.address",
        )
        TitledSection("Opening", note = "The code goes to the door as tones. Without one the door only talks.") {
            Card {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Icons.Outlined.Lock, contentDescription = null, tint = Palette.brass, modifier = Modifier.size(20.dp))
                    Text("Door code", style = Type.body, color = Palette.text)
                    PlainTextField(
                        draft.code,
                        { change(draft.copy(code = it.filter { char -> char.isDigit() || char in "*#ABCD" })) },
                        "Digits, * or #",
                        Modifier.weight(1f),
                        keyboardType = KeyboardType.Phone,
                        secure = true,
                        alignEnd = true,
                        tag = "door.code",
                    )
                }
                RowDivider()
                MenuRow(
                    "Station replies with",
                    draft.replyDigit,
                    listOf("") + DtmfRequest.replyChoices,
                    { if (it.isEmpty()) "No reply" else it },
                ) { change(draft.copy(replyDigit = it)) }
                RowDivider()
                ToggleRow(
                    "Open from the notification",
                    draft.opensFromNotification,
                    { change(draft.copy(opensFromNotification = it)) },
                    "Answers, sends the code and hangs up",
                )
                RowDivider()
                ToggleRow(
                    "Unlock the phone first",
                    draft.asksToUnlockFirst,
                    { change(draft.copy(asksToUnlockFirst = it)) },
                    "Fingerprint, face or screen lock, so nobody else opens with your phone",
                )
                RowDivider()
                ToggleRow(
                    "Hang up after opening",
                    draft.hangsUpAfterOpening,
                    { change(draft.copy(hangsUpAfterOpening = it)) },
                    "Off keeps the call until you end it",
                )
            }
        }
        Card {
            ToggleRow("The door has a camera", draft.hasCamera, { change(draft.copy(hasCamera = it)) }, "Shows its picture on the Doors screen")
        }
        if (isNew) {
            FilledButton("Add door", ButtonKind.LIGHT, enabled = draft.address.isNotBlank()) {
                model.save(draft)
                model.back()
            }
        } else {
            FilledButton("Remove this door", ButtonKind.DANGER) { confirmRemove = true }
        }
    }
    if (confirmRemove) {
        ConfirmDialog("Remove ${draft.title}?", "Remove", onDismiss = { confirmRemove = false }) {
            model.remove(draft)
            model.back()
        }
    }
}

@Composable
private fun DoorPicture(
    model: CallModel,
    door: Door,
) {
    val shape = RoundedCornerShape(20.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 150.dp)
            .clip(shape)
            .background(Palette.picture)
            .border(1.dp, Palette.line, shape)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(Icons.Outlined.Person, contentDescription = null, tint = Palette.pictureMark, modifier = Modifier.size(56.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            val record = model.lastRecord(door)
            Text(
                record?.let { "Last ring ${ActivityFormat().dateTime(it.startedAt)}" } ?: "No ring yet",
                style = Type.footnote,
                color = Palette.secondary,
            )
            FilledButton("Look at the door", ButtonKind.RAISED, icon = Icons.Outlined.Videocam, height = 44.dp, radius = 12.dp, expands = false) {
                model.act { look(door) }
            }
        }
    }
}
