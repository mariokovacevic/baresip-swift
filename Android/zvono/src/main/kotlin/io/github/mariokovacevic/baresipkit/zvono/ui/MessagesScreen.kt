package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.mariokovacevic.baresipkit.zvono.model.ActivityFormat
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.ChatMessage
import io.github.mariokovacevic.baresipkit.zvono.model.ChatStatus
import io.github.mariokovacevic.baresipkit.zvono.model.Conversation
import io.github.mariokovacevic.baresipkit.zvono.model.Screen
import io.github.mariokovacevic.baresipkit.zvono.model.SipNames
import io.github.mariokovacevic.baresipkit.zvono.model.call
import io.github.mariokovacevic.baresipkit.zvono.model.conversations
import io.github.mariokovacevic.baresipkit.zvono.model.doorFor
import io.github.mariokovacevic.baresipkit.zvono.model.markRead
import io.github.mariokovacevic.baresipkit.zvono.model.messagesWith
import io.github.mariokovacevic.baresipkit.zvono.model.normalizedDestination
import io.github.mariokovacevic.baresipkit.zvono.model.resend
import io.github.mariokovacevic.baresipkit.zvono.model.send

@Composable
fun MessagesScreen(model: CallModel) {
    var askPeer by remember { mutableStateOf(false) }
    var newPeer by rememberSaveable { mutableStateOf("") }
    val format = remember { ActivityFormat() }
    Page(actions = { RoundIcon(Icons.Outlined.Edit, "New message", size = 40.dp) { askPeer = true } }) {
        ScreenTitle("Messages")
        val conversations = model.conversations
        Card {
            if (conversations.isEmpty()) {
                Text(
                    "No messages yet. Write to a person or a desk on your intercom server.",
                    style = Type.subheadline,
                    color = Palette.secondary,
                    modifier = Modifier.padding(16.dp),
                )
            }
            conversations.forEachIndexed { index, conversation ->
                if (index > 0) RowDivider()
                ConversationRow(model, conversation, format)
            }
        }
        Note("Messages go through your intercom server, to people and desks on it. They arrive while Zvono is open or reachable.")
    }
    if (askPeer) {
        AlertDialog(
            onDismissRequest = { askPeer = false },
            containerColor = Palette.raised,
            title = { Text("New message", style = Type.title, color = Palette.text) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("Whom do you want to write to?", style = Type.subheadline, color = Palette.secondary)
                    StackedField("Number or address", newPeer, { newPeer = it }, "100 or desk@pbx.example.com", keyboardType = KeyboardType.Email)
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    askPeer = false
                    if (newPeer.isNotBlank()) model.open(Screen.Thread(newPeer.trim()))
                    newPeer = ""
                }) { Text("Write", color = Palette.info) }
            },
            dismissButton = { TextButton(onClick = { askPeer = false }) { Text("Cancel", color = Palette.info) } },
        )
    }
}

@Composable
private fun ConversationRow(
    model: CallModel,
    conversation: Conversation,
    format: ActivityFormat,
) {
    val last = conversation.last
    val title = model.doorFor(last.peer)?.title ?: conversation.peer
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { model.open(Screen.Thread(last.peer)) }
            .padding(horizontal = 14.dp, vertical = 12.dp)
            .testTag("conversation.${conversation.peer}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Avatar(SipNames.initials(title))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, style = Type.bodyStrong, color = Palette.text, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                Text(format.time(last.date), style = Type.footnote, color = Palette.secondary)
            }
            val preview = if (last.outgoing) "You: ${last.text}" + if (last.isFailed) " Not delivered" else "" else last.text
            Text(preview, style = Type.subheadline, color = if (last.isFailed) Palette.alert else Palette.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
fun ThreadScreen(
    model: CallModel,
    peer: String,
    overCall: Boolean,
    onDone: () -> Unit,
) {
    val user = SipNames.user(peer)
    val title = model.doorFor(peer)?.title ?: user
    val address = SipNames.address(model.normalizedDestination(peer))
    val thread = model.messagesWith(peer)
    var draft by rememberSaveable { mutableStateOf("") }
    val list = rememberLazyListState()
    val format = remember { ActivityFormat() }
    DisposableEffect(user) {
        model.openChatPeer = user
        onDispose { if (model.openChatPeer == user) model.openChatPeer = null }
    }
    LaunchedEffect(thread.size) {
        model.markRead(peer)
        if (thread.isNotEmpty()) list.animateScrollToItem(thread.size)
    }
    Column(Modifier.fillMaxSize().background(Palette.background)) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(Palette.bar)
                .heightIn(min = 60.dp)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (!overCall) BackBarButton(onDone)
            Column(Modifier.weight(1f).padding(start = if (overCall) 8.dp else 0.dp)) {
                Text(title, style = Type.display(20.sp), color = Palette.text, maxLines = 1)
                Text(if (overCall) "$address, in call" else address, style = Type.caption, color = Palette.secondary, maxLines = 1)
            }
            if (overCall) {
                TextAction("Done", modifier = Modifier.testTag("chat.done"), onClick = onDone)
            } else {
                RoundIcon(Icons.Filled.Call, "Call $title", size = 38.dp) {
                    model.destination = peer
                    model.act { call(video = false) }
                }
                RoundIcon(Icons.Outlined.Videocam, "Video call $title", size = 38.dp) {
                    model.destination = peer
                    model.act { call(video = true) }
                }
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.barLine))
        LazyColumn(
            Modifier.weight(1f).fillMaxWidth(),
            state = list,
            contentPadding =
                androidx.compose.foundation.layout
                    .PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                thread.firstOrNull()?.let {
                    Text(
                        format.date(it.date),
                        style = Type.caption.copy(fontSize = 12.sp),
                        color = Palette.secondary,
                        modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                }
            }
            items(thread, key = { it.id }) { Bubble(model, it, format) }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.barLine))
        Row(
            Modifier.fillMaxWidth().background(Palette.bar).padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            val shape = RoundedCornerShape(24.dp)
            Box(
                Modifier
                    .weight(1f)
                    .clip(shape)
                    .background(Palette.surface)
                    .border(1.dp, Palette.field, shape)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                PlainTextField(draft, { draft = it }, "Message", Modifier.fillMaxWidth(), singleLine = false, tag = "chat.text")
            }
            val canSend = draft.isNotBlank()
            Box(
                Modifier
                    .size(48.dp)
                    .alpha(if (canSend) 1f else 0.45f)
                    .clip(CircleShape)
                    .background(Palette.text)
                    .clickable(enabled = canSend, role = Role.Button) {
                        val text = draft.trim()
                        draft = ""
                        model.act { send(text, peer) }
                    }.semantics { contentDescription = "Send" },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.ArrowUpward, contentDescription = null, tint = Palette.background)
            }
        }
    }
}

@Composable
private fun BackBarButton(onBack: () -> Unit) {
    Box(
        Modifier
            .size(44.dp)
            .clip(CircleShape)
            .clickable(role = Role.Button, onClick = onBack)
            .semantics { contentDescription = "Back" },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, tint = Palette.info)
    }
}

@Composable
private fun Bubble(
    model: CallModel,
    message: ChatMessage,
    format: ActivityFormat,
) {
    val outgoing = message.outgoing
    val failed = message.isFailed
    val shape =
        if (outgoing) {
            RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomStart = 18.dp, bottomEnd = 6.dp)
        } else {
            RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomStart = 6.dp, bottomEnd = 18.dp)
        }
    val background =
        when {
            failed -> Palette.failed
            outgoing -> Palette.text
            else -> Palette.surface
        }
    val border =
        when {
            failed -> Palette.failedLine
            outgoing -> Color.Transparent
            else -> Palette.line
        }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = if (outgoing) Alignment.End else Alignment.Start) {
        Text(
            message.text,
            style = Type.body,
            color = if (outgoing && !failed) Palette.background else Palette.text,
            modifier =
                Modifier
                    .widthIn(max = 280.dp)
                    .clip(shape)
                    .background(background)
                    .border(1.dp, border, shape)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
        )
        Spacer(Modifier.height(4.dp))
        if (failed) {
            TextAction("Not delivered. Send again", color = Palette.alert) { model.act { resend(message) } }
        } else {
            val time = format.time(message.date)
            val status =
                when (message.status) {
                    ChatStatus.Sending -> "Sending"
                    ChatStatus.Delivered -> "$time, delivered"
                    else -> time
                }
            Text(status, style = Type.caption, color = Palette.secondary, modifier = Modifier.padding(horizontal = 6.dp))
        }
    }
}
