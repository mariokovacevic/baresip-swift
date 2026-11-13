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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Backspace
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.Contact
import io.github.mariokovacevic.baresipkit.zvono.model.DtmfRequest
import io.github.mariokovacevic.baresipkit.zvono.model.Screen
import io.github.mariokovacevic.baresipkit.zvono.model.activeRow
import io.github.mariokovacevic.baresipkit.zvono.model.call
import io.github.mariokovacevic.baresipkit.zvono.model.remove
import io.github.mariokovacevic.baresipkit.zvono.model.save
import io.github.mariokovacevic.baresipkit.zvono.model.sendDtmfRequest

@Composable
fun KeypadScreen(model: CallModel) {
    var showDtmf by remember { mutableStateOf(false) }
    val domain =
        model.settings.domain
            .trim()
            .ifEmpty { "your server" }
    val hasDestination = model.destination.isNotBlank()
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Keypad", style = Type.bodyStrong, color = Palette.text)
        DestinationEntry(model)
        Note("A number calls through $domain. A full address, such as office@example.com, works too.", Modifier.fillMaxWidth())
        DialPad { model.destination += it }
        Row(Modifier.alpha(if (hasDestination) 1f else 0.45f), horizontalArrangement = Arrangement.spacedBy(30.dp), verticalAlignment = Alignment.Top) {
            KeypadAction("Message", Icons.Outlined.ChatBubbleOutline, 56.dp, false, hasDestination, "call.message") {
                model.open(Screen.Thread(model.destination.trim()))
            }
            KeypadAction("Call", Icons.Filled.Call, 72.dp, true, hasDestination, "call.audio") { model.act { call(video = false) } }
            KeypadAction("Video", Icons.Outlined.Videocam, 56.dp, false, hasDestination, "call.video") { model.act { call(video = true) } }
        }
        Row(
            Modifier
                .clip(CircleShape)
                .background(Palette.surface)
                .border(1.dp, Palette.field, CircleShape)
                .clickable(role = Role.Button) { showDtmf = true }
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .testTag("call.dtmf"),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Filled.Key, contentDescription = null, tint = Palette.text, modifier = Modifier.size(18.dp))
            Text("Call, send a code, hang up", style = Type.subheadlineMedium, color = Palette.text)
        }
        model.pendingDtmf?.let { pending ->
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Key, contentDescription = null, tint = Palette.brass, modifier = Modifier.size(18.dp))
                Text("Sends ${pending.digits} when the call connects", style = Type.footnote, color = Palette.secondary, modifier = Modifier.weight(1f))
                TextAction("Clear") { model.pendingDtmf = null }
            }
        }
        ContactsSection(model)
    }
    if (showDtmf) DtmfSheet(model) { showDtmf = false }
}

@Composable
private fun DestinationEntry(model: CallModel) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clip(shape)
            .background(Palette.surface)
            .border(1.dp, Palette.line, shape)
            .padding(start = 18.dp, end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PlainTextField(
            model.destination,
            { model.destination = it },
            "Number or address",
            Modifier.weight(1f),
            style = Type.displayMedium(28.sp),
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Go,
            onDone = { model.act { call(video = false) } },
            tag = "call.destination",
        )
        if (model.destination.isNotEmpty()) {
            Box(
                Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .clickable(role = Role.Button) { model.destination = model.destination.dropLast(1) }
                    .semantics { contentDescription = "Delete the last character" },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.AutoMirrored.Outlined.Backspace, contentDescription = null, tint = Palette.secondary)
            }
        }
    }
}

@Composable
private fun KeypadAction(
    title: String,
    icon: ImageVector,
    size: Dp,
    light: Boolean,
    enabled: Boolean,
    tag: String,
    onClick: () -> Unit,
) {
    Column(
        Modifier
            .width(72.dp)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .testTag(tag)
            .semantics { contentDescription = title },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            Modifier
                .size(size)
                .clip(CircleShape)
                .background(if (light) Palette.text else Palette.raised)
                .border(1.dp, if (light) Color.Transparent else Palette.field, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = if (light) Palette.background else Palette.text, modifier = Modifier.size(size * 0.38f))
        }
        Text(title, style = if (light) Type.footnoteStrong else Type.footnoteMedium, color = Palette.text)
    }
}

private val keys = listOf("1" to "", "2" to "ABC", "3" to "DEF", "4" to "GHI", "5" to "JKL", "6" to "MNO", "7" to "PQRS", "8" to "TUV", "9" to "WXYZ", "*" to "", "0" to "+", "#" to "")

@Composable
fun DialPad(
    keySize: Dp = 74.dp,
    showsLetters: Boolean = true,
    press: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(keySize * 0.16f), horizontalAlignment = Alignment.CenterHorizontally) {
        for (row in keys.chunked(3)) {
            Row(horizontalArrangement = Arrangement.spacedBy(keySize * 0.35f)) {
                for ((digit, letters) in row) {
                    Column(
                        Modifier
                            .size(keySize)
                            .clip(CircleShape)
                            .background(Palette.surface)
                            .border(1.dp, Palette.line, CircleShape)
                            .clickable(role = Role.Button) { press(digit) }
                            .semantics { contentDescription = digit }
                            .testTag("key.$digit"),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(digit, style = Type.displayMedium((keySize.value * 0.4f).sp), color = Palette.text)
                        if (showsLetters) Text(letters, style = Type.small.copy(letterSpacing = 1.4.sp, fontSize = 10.sp), color = Palette.secondary)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DtmfSheet(
    model: CallModel,
    onDismiss: () -> Unit,
) {
    var digits by rememberSaveable { mutableStateOf("") }
    var ack by rememberSaveable { mutableStateOf("") }
    var hangUp by rememberSaveable { mutableStateOf(true) }
    val row = model.activeRow
    val canSend = digits.isNotEmpty() && (row != null || model.destination.isNotBlank())
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Palette.background) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                TextAction("Cancel", onClick = onDismiss)
                Spacer(Modifier.weight(1f))
                Text("Send a code", style = Type.bodyStrong, color = Palette.text)
                Spacer(Modifier.weight(1f))
                TextAction("Send", enabled = canSend, modifier = Modifier.testTag("dtmf.send")) {
                    val request = DtmfRequest(digits, ack, hangUp)
                    onDismiss()
                    model.act { sendDtmfRequest(request) }
                }
            }
            val shape = RoundedCornerShape(18.dp)
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 64.dp)
                    .clip(shape)
                    .background(Palette.surface)
                    .border(1.dp, Palette.line, shape)
                    .padding(start = 18.dp, end = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    digits.ifEmpty { "Code" },
                    style = Type.displayMedium(34.sp).copy(letterSpacing = 2.sp),
                    color = if (digits.isEmpty()) Palette.secondary else Palette.text,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f).testTag("dtmf.digits"),
                )
                Box(
                    Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .clickable(enabled = digits.isNotEmpty()) { digits = digits.dropLast(1) }
                        .semantics { contentDescription = "Delete" },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.AutoMirrored.Outlined.Backspace, contentDescription = null, tint = Palette.secondary)
                }
            }
            DialPad(keySize = 64.dp, showsLetters = false) { digits += it }
            Card {
                MenuRow("Expected reply", ack, listOf("") + DtmfRequest.replyChoices, { it.ifEmpty { "None" } }) { ack = it }
                RowDivider()
                ToggleRow("Hang up when done", hangUp, { hangUp = it })
            }
            val reply = if (ack.isEmpty()) "" else " Waits up to ${DtmfRequest.ackTimeout.inWholeSeconds} s for $ack from the station."
            val target =
                when {
                    row != null -> "Sends on the current call with ${row.title}.$reply"
                    model.destination.isBlank() -> "Enter an address on the keypad first."
                    else -> "Calls ${model.destination.trim()} and sends once it is connected.$reply"
                }
            Text(target, style = Type.footnote, color = Palette.secondary, textAlign = TextAlign.Center)
            Spacer(Modifier.size(16.dp))
        }
    }
}

@Composable
private fun ContactsSection(model: CallModel) {
    TitledSection("Contacts") {
        Card {
            model.contacts.forEachIndexed { index, contact ->
                if (index > 0) RowDivider()
                ContactRow(model, contact)
            }
            if (model.contacts.isNotEmpty()) RowDivider()
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 52.dp)
                    .clickable { model.open(Screen.ContactEditor(null)) }
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(Icons.Filled.Add, contentDescription = null, tint = Palette.info)
                Text("Add a contact", style = Type.bodyStrong.copy(fontSize = 16.sp), color = Palette.info)
            }
        }
    }
}

@Composable
private fun ContactRow(
    model: CallModel,
    contact: Contact,
) {
    Row(
        Modifier.fillMaxWidth().padding(start = 14.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            Modifier.weight(1f).clickable { model.open(Screen.ContactEditor(contact.id)) },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Avatar(contact.initials, size = 40.dp)
            Column {
                Text(contact.title, style = Type.bodyStrong, color = Palette.text, maxLines = 1)
                Text(contact.address, style = Type.footnote, color = Palette.secondary, maxLines = 1)
            }
        }
        RoundIcon(Icons.Outlined.ChatBubbleOutline, "Write to ${contact.title}", size = 38.dp) {
            model.destination = contact.address.trim()
            model.open(Screen.Thread(contact.address.trim()))
        }
        RoundIcon(Icons.Outlined.Videocam, "Video call ${contact.title}", size = 38.dp) {
            model.destination = contact.address.trim()
            model.act { call(video = true) }
        }
        RoundIcon(Icons.Filled.Call, "Call ${contact.title}", size = 38.dp) {
            model.destination = contact.address.trim()
            model.act { call(video = false) }
        }
    }
}

@Composable
fun ContactScreen(
    model: CallModel,
    contactId: String?,
) {
    val existing = model.contacts.firstOrNull { it.id == contactId }
    val isNew = existing == null
    var draft by remember(contactId) { mutableStateOf(existing ?: Contact()) }
    var confirmRemove by remember { mutableStateOf(false) }

    fun change(updated: Contact) {
        draft = updated
        if (!isNew) model.save(updated)
    }
    Page(onBack = { model.back() }) {
        ScreenTitle(if (isNew) "New contact" else draft.title)
        StackedField("Name", draft.name, { change(draft.copy(name = it)) }, "Reception")
        StackedField("Number or address", draft.address, { change(draft.copy(address = it)) }, "100 or desk@pbx.example.com", keyboardType = KeyboardType.Email)
        if (isNew) {
            FilledButton("Add contact", ButtonKind.LIGHT, enabled = draft.address.isNotBlank()) {
                model.save(draft)
                model.back()
            }
        } else {
            FilledButton("Remove this contact", ButtonKind.DANGER) { confirmRemove = true }
        }
    }
    if (confirmRemove) {
        ConfirmDialog("Remove ${draft.title}?", "Remove", onDismiss = { confirmRemove = false }) {
            model.remove(draft)
            model.back()
        }
    }
}
