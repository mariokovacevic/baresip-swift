package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Bluetooth
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Dialpad
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Speaker
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.filled.VideocamOff
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.mariokovacevic.baresipkit.BaresipCallStatistics
import io.github.mariokovacevic.baresipkit.BaresipCandidateType
import io.github.mariokovacevic.baresipkit.compose.BaresipCallVideo
import io.github.mariokovacevic.baresipkit.compose.BaresipSelfView
import io.github.mariokovacevic.baresipkit.zvono.model.AppTab
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.CallRow
import io.github.mariokovacevic.baresipkit.zvono.model.CallText
import io.github.mariokovacevic.baresipkit.zvono.model.OutputChoice
import io.github.mariokovacevic.baresipkit.zvono.model.OutputKind
import io.github.mariokovacevic.baresipkit.zvono.model.activeCall
import io.github.mariokovacevic.baresipkit.zvono.model.blindTransfer
import io.github.mariokovacevic.baresipkit.zvono.model.callOnScreen
import io.github.mariokovacevic.baresipkit.zvono.model.calls
import io.github.mariokovacevic.baresipkit.zvono.model.completeTransfer
import io.github.mariokovacevic.baresipkit.zvono.model.consult
import io.github.mariokovacevic.baresipkit.zvono.model.controllerChoices
import io.github.mariokovacevic.baresipkit.zvono.model.currentDoor
import io.github.mariokovacevic.baresipkit.zvono.model.currentDoorOpened
import io.github.mariokovacevic.baresipkit.zvono.model.doorFor
import io.github.mariokovacevic.baresipkit.zvono.model.endConsultation
import io.github.mariokovacevic.baresipkit.zvono.model.endpointChoices
import io.github.mariokovacevic.baresipkit.zvono.model.hangUp
import io.github.mariokovacevic.baresipkit.zvono.model.heldRow
import io.github.mariokovacevic.baresipkit.zvono.model.openCallChat
import io.github.mariokovacevic.baresipkit.zvono.model.openCurrentDoor
import io.github.mariokovacevic.baresipkit.zvono.model.phoneCall
import io.github.mariokovacevic.baresipkit.zvono.model.refreshStatistics
import io.github.mariokovacevic.baresipkit.zvono.model.restartIce
import io.github.mariokovacevic.baresipkit.zvono.model.selectOutput
import io.github.mariokovacevic.baresipkit.zvono.model.sendDtmf
import io.github.mariokovacevic.baresipkit.zvono.model.switchCamera
import io.github.mariokovacevic.baresipkit.zvono.model.switchTo
import io.github.mariokovacevic.baresipkit.zvono.model.telecomCall
import io.github.mariokovacevic.baresipkit.zvono.model.toggleHold
import io.github.mariokovacevic.baresipkit.zvono.model.toggleMute
import io.github.mariokovacevic.baresipkit.zvono.model.toggleRecording
import io.github.mariokovacevic.baresipkit.zvono.model.toggleVideo
import io.github.mariokovacevic.baresipkit.zvono.model.unreadCount
import kotlinx.coroutines.delay

@Composable
fun InCallScreen(
    model: CallModel,
    row: CallRow,
) {
    var showMore by remember { mutableStateOf(false) }
    var showOutputs by remember { mutableStateOf(false) }
    BackHandler { minimize(model) }
    rememberTick()
    val door = model.doorFor(row.remoteUri)
    val call = model.phoneCall(row.id)
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.callBackground)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .testTag("call"),
    ) {
        Box(Modifier.weight(1f).fillMaxWidth().background(Palette.picture)) {
            when {
                row.receivingVideo && call != null ->
                    BaresipCallVideo(call, Modifier.fillMaxSize().semantics { contentDescription = "Remote video" }) { view ->
                        model.snapshots.register(view, call.id)
                    }
                row.receivingVideo && model.demoMode -> DemoDoorView(Modifier.fillMaxSize())
                door != null ->
                    Column(Modifier.fillMaxWidth().padding(top = 150.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Outlined.Person, contentDescription = null, tint = Palette.pictureMark, modifier = Modifier.size(130.dp))
                        Text("Waiting for the door camera", style = Type.footnote, color = Palette.secondary, modifier = Modifier.alpha(if (model.captions.isEmpty()) 1f else 0f))
                    }
                else -> Box(Modifier.fillMaxWidth().padding(top = 150.dp), contentAlignment = Alignment.TopCenter) { Avatar(row.initials, size = 120.dp) }
            }
            Column(Modifier.fillMaxSize()) {
                CallHeader(model, row, door?.title ?: row.title)
                if (call != null) {
                    Box(Modifier.fillMaxWidth().padding(top = 16.dp, end = 16.dp), contentAlignment = Alignment.TopEnd) {
                        BaresipSelfView(call, Modifier.testTag("call.selfView"), size = DpSize(88.dp, 118.dp))
                    }
                }
                Spacer(Modifier.weight(1f))
                CallNotes(model, row)
            }
        }
        InCallControls(model, row, onMore = { showMore = true }, onOutputs = { showOutputs = true })
    }
    if (showMore) MoreSheet(model, row) { showMore = false }
    if (showOutputs) OutputsSheet(model) { showOutputs = false }
    model.showCallChat?.let { peer -> ChatSheet(model, peer) }
}

private fun minimize(model: CallModel) {
    model.callMinimized = true
    model.tab = AppTab.DOORS
}

@Composable
private fun CallHeader(
    model: CallModel,
    row: CallRow,
    title: String,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Palette.overlay)
            .statusBarsPadding()
            .padding(start = 8.dp, end = 16.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier
                .size(44.dp)
                .clip(CircleShape)
                .clickable(role = Role.Button) { minimize(model) }
                .semantics { contentDescription = "Back to the app, the call goes on" },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.KeyboardArrowDown, contentDescription = null, tint = Palette.text, modifier = Modifier.size(30.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = Type.display(32.sp), color = Palette.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val color = if (row.isOnHold) Palette.brass else Palette.info
                StatusDot(color)
                Text(
                    CallText.status(row).uppercase(),
                    style = Type.footnoteStrong.copy(letterSpacing = 0.8.sp),
                    color = color,
                    modifier = Modifier.testTag("call.state").semantics { stateDescription = row.state.name },
                )
            }
        }
        ChatButton(model, row)
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            val encrypted = model.stats?.audio?.isSecure == true || row.id?.let { model.encryptedCalls.containsKey(it) } == true || model.demoMode
            if (encrypted) Chip("Encrypted", Icons.Outlined.Lock)
            val count = model.calls.size
            if (count > 1) Chip("$count calls", Icons.Outlined.Phone)
        }
    }
}

@Composable
private fun ChatButton(
    model: CallModel,
    row: CallRow,
) {
    val unread = model.unreadCount(row.remoteUri)
    Box(Modifier.testTag("call.chat").semantics { contentDescription = if (unread > 0) "Messages, $unread unread" else "Messages" }) {
        RoundIcon(Icons.Outlined.ChatBubbleOutline, if (unread > 0) "Messages, $unread unread" else "Messages") { model.openCallChat() }
        if (unread > 0) {
            Text(
                "$unread",
                style = Type.small.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Bold),
                color = Palette.onBrass,
                modifier =
                    Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = 6.dp, y = (-6).dp)
                        .clip(CircleShape)
                        .background(Palette.brass)
                        .widthIn(min = 20.dp)
                        .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    }
}

@Composable
private fun Chip(
    text: String,
    icon: ImageVector,
) {
    Row(
        Modifier
            .height(28.dp)
            .clip(CircleShape)
            .background(Palette.surface)
            .border(1.dp, Palette.field, CircleShape)
            .padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(icon, contentDescription = null, tint = Palette.text, modifier = Modifier.size(14.dp))
        Text(text, style = Type.caption.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Medium), color = Palette.text)
    }
}

@Composable
private fun CallNotes(
    model: CallModel,
    row: CallRow,
) {
    Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        val captions = model.captions
        for (caption in captions) {
            val appearing = remember(caption.id) { MutableTransitionState(false).apply { targetState = true } }
            AnimatedVisibility(visibleState = appearing, enter = slideInVertically { it } + fadeIn(), exit = fadeOut()) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .alpha(if (caption.id == captions.last().id) 1f else 0.6f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(Palette.caption)
                        .clickable { model.openCallChat() }
                        .padding(horizontal = 14.dp, vertical = 10.dp)
                        .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite }
                        .testTag("call.caption"),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(caption.sender, style = Type.captionStrong, color = Palette.brass)
                    Text(caption.text, style = Type.body.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Medium), color = Palette.text, maxLines = 3)
                }
            }
        }
        if (model.currentDoorOpened) {
            Row(
                Modifier.clip(RoundedCornerShape(12.dp)).background(Palette.brass).padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Filled.Check, contentDescription = null, tint = Palette.onBrass, modifier = Modifier.size(18.dp))
                Text("Door opened", style = Type.subheadlineStrong, color = Palette.onBrass)
            }
        }
        Text(
            if (row.sendingVideo) "The other side sees you." else "Your camera is off. The other side hears you only.",
            style = Type.footnote,
            color = Palette.text,
            modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(Palette.overlay).padding(horizontal = 12.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun InCallControls(
    model: CallModel,
    row: CallRow,
    onMore: () -> Unit,
    onOutputs: () -> Unit,
) {
    var showKeypad by remember { mutableStateOf(false) }
    var digits by remember { mutableStateOf("") }
    val choices = outputChoices(model, row)
    val current = choices.firstOrNull { it.selected }
    Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.barLine))
    Column(
        Modifier
            .fillMaxWidth()
            .background(Palette.bar)
            .navigationBarsPadding()
            .padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (showKeypad) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    digits.ifEmpty { "Tones go to the other side" },
                    style = if (digits.isEmpty()) Type.subheadline else Type.displayMedium(26.sp).copy(letterSpacing = 2.sp),
                    color = if (digits.isEmpty()) Palette.secondary else Palette.text,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
                FilledButton("Hide keypad", ButtonKind.RAISED, height = 44.dp, radius = 22.dp, expands = false) {
                    showKeypad = false
                    digits = ""
                }
            }
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                DialPad(keySize = 52.dp, showsLetters = false) { digit ->
                    digits += digit
                    model.act { sendDtmf(digit) }
                }
            }
        } else {
            Row(Modifier.fillMaxWidth()) {
                CallControl(if (row.muted) "Muted" else "Mute", if (row.muted) Icons.Filled.MicOff else Icons.Filled.Mic, Modifier.weight(1f), active = row.muted) {
                    model.act { toggleMute() }
                }
                CallControl(
                    current?.takeIf { it.kind != OutputKind.PHONE }?.name ?: "Speaker",
                    outputIcon(current?.kind),
                    Modifier.weight(1f).testTag("call.audioOutput"),
                    active = current != null && current.kind != OutputKind.PHONE,
                    onClick = onOutputs,
                )
                CallControl("My camera", if (row.sendingVideo) Icons.Filled.Videocam else Icons.Filled.VideocamOff, Modifier.weight(1f), active = row.sendingVideo) {
                    model.act { toggleVideo() }
                }
            }
            Row(Modifier.fillMaxWidth()) {
                CallControl("Keypad", Icons.Filled.Dialpad, Modifier.weight(1f)) { showKeypad = true }
                CallControl(if (row.isOnHold) "Resume" else "Hold", Icons.Filled.Pause, Modifier.weight(1f), active = row.isOnHold) { model.act { toggleHold() } }
                CallControl("More", Icons.Filled.MoreHoriz, Modifier.weight(1f).testTag("call.more"), onClick = onMore)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            if (model.currentDoor != null) {
                val opened = model.currentDoorOpened
                FilledButton(
                    if (opened) "Open again" else "Open door",
                    if (opened) ButtonKind.SOFT_BRASS else ButtonKind.BRASS,
                    Modifier.weight(1f).testTag("call.openDoor"),
                    icon = Icons.Filled.Key,
                    height = 64.dp,
                    radius = 18.dp,
                    textStyle = Type.title,
                ) { model.act { openCurrentDoor() } }
                Box(
                    Modifier
                        .size(64.dp)
                        .clip(CircleShape)
                        .background(Palette.hangUp)
                        .clickable(role = Role.Button) { model.act { hangUp() } }
                        .semantics { contentDescription = "Hang up" }
                        .testTag("call.hangup"),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Close, contentDescription = null, tint = Palette.alert, modifier = Modifier.size(28.dp))
                }
            } else {
                FilledButton(
                    "End call",
                    ButtonKind.DANGER,
                    Modifier.testTag("call.hangup"),
                    icon = Icons.Filled.CallEnd,
                    height = 64.dp,
                    radius = 18.dp,
                    textStyle = Type.title,
                ) { model.act { hangUp() } }
            }
        }
    }
}

fun outputIcon(kind: OutputKind?): ImageVector =
    when (kind) {
        OutputKind.SPEAKER -> Icons.AutoMirrored.Filled.VolumeUp
        OutputKind.BLUETOOTH -> Icons.Filled.Bluetooth
        OutputKind.HEADSET -> Icons.Filled.Headphones
        OutputKind.OTHER -> Icons.Filled.Speaker
        OutputKind.PHONE, null -> Icons.Filled.PhoneAndroid
    }

@Composable
private fun outputChoices(
    model: CallModel,
    row: CallRow,
): List<OutputChoice> {
    if (model.demoMode) {
        return listOf(
            OutputChoice("phone", "Phone", OutputKind.PHONE, false),
            OutputChoice("speaker", "Speaker", OutputKind.SPEAKER, true),
        )
    }
    val telecomCall = model.telecomCall(row.id)
    if (telecomCall != null) {
        val available by telecomCall.availableEndpoints.collectAsState()
        val current by telecomCall.currentEndpoint.collectAsState()
        return endpointChoices(available, current)
    }
    model.audioRouteChanges
    return model.controllerChoices()
}

@Composable
private fun AudioOutputList(
    model: CallModel,
    row: CallRow,
    onSelect: () -> Unit = {},
) {
    val choices = outputChoices(model, row)
    Card {
        choices.forEachIndexed { index, choice ->
            if (index > 0) RowDivider()
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 50.dp)
                    .clickable {
                        model.selectOutput(choice)
                        onSelect()
                    }.padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(outputIcon(choice.kind), contentDescription = null, tint = Palette.secondary, modifier = Modifier.size(22.dp))
                Text(choice.name, style = Type.body, color = Palette.text, modifier = Modifier.weight(1f))
                if (choice.selected) Icon(Icons.Filled.Check, contentDescription = "Selected", tint = Palette.info)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OutputsSheet(
    model: CallModel,
    onDismiss: () -> Unit,
) {
    val row = model.callOnScreen ?: return
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Palette.bar) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Sound comes from", style = Type.bodyStrong, color = Palette.text, modifier = Modifier.padding(bottom = 8.dp))
            AudioOutputList(model, row, onDismiss)
            Note("Bluetooth devices appear here once they are connected to the phone.")
            Spacer(Modifier.height(16.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MoreSheet(
    model: CallModel,
    row: CallRow,
    onDismiss: () -> Unit,
) {
    var transferring by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        while (true) {
            model.refreshStatistics()
            delay(2000)
        }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Palette.bar) {
        Column(
            Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(horizontal = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (transferring) TextAction("Back") { transferring = false }
                Text(
                    if (transferring) "Transfer the call" else model.currentDoor?.title ?: row.title,
                    style = Type.bodyStrong,
                    color = Palette.text,
                    modifier = Modifier.weight(1f).padding(start = 4.dp),
                )
                TextAction("Done", onClick = onDismiss)
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                if (transferring) {
                    TransferContent(model, row, onDone = onDismiss)
                } else {
                    Card {
                        LinkRow("Transfer the call", icon = Icons.Outlined.Phone) { transferring = true }
                        RowDivider()
                        val recording = model.recordingCall != null && model.recordingCall == model.activeCall?.id
                        ToggleRow(
                            if (recording) "Recording this call" else "Record this call",
                            recording,
                            { model.act { toggleRecording() } },
                            if (recording) "Saved as a stereo WAV in the app's Recordings folder" else null,
                            Modifier.testTag("call.record"),
                        )
                        if (row.sendingVideo) {
                            RowDivider()
                            CardButton("Switch between front and back camera") { model.act { switchCamera() } }
                        }
                        if (model.settings.useIce) {
                            RowDivider()
                            CardButton("Reconnect the call after a network change") { model.act { restartIce() } }
                        }
                    }
                    TitledSection("Sound comes from") { AudioOutputList(model, row) }
                    val stats = model.stats
                    if (stats != null) {
                        TitledSection("Call quality") { CallQuality(stats, row.codec, model.settings.useIce, row.receivingVideo || row.sendingVideo) }
                    } else if (model.demoMode) {
                        TitledSection("Call quality") { DemoQuality() }
                    }
                }
                Spacer(Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun QualityTiles(tiles: List<Pair<String, String>>) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for ((value, title) in tiles) {
            val shape = RoundedCornerShape(14.dp)
            Column(
                Modifier
                    .weight(1f)
                    .heightIn(min = 64.dp)
                    .clip(shape)
                    .background(Palette.surface)
                    .border(1.dp, Palette.line, shape)
                    .padding(vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
            ) {
                Text(value, style = Type.display(20.sp), color = Palette.text, maxLines = 1)
                Text(title, style = Type.small, color = Palette.secondary)
            }
        }
    }
}

@Composable
private fun CallQuality(
    stats: BaresipCallStatistics,
    codec: String,
    useIce: Boolean,
    showsVideo: Boolean,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        QualityTiles(
            listOf(
                "%.1f".format(stats.mosEstimate) to "MOS",
                "%.1f %%".format(stats.audio.receivedFractionLostPermille / 10.0) to "Loss",
                "${stats.audio.receivedJitter.inWholeMilliseconds} ms" to "Jitter",
                "${stats.audio.roundTripTime.inWholeMilliseconds} ms" to "Round trip",
            ),
        )
        Card(radius = 16.dp) {
            ValueRow("Encryption", if (stats.audio.isSecure) "SRTP" else "Not encrypted")
            if (codec.isNotEmpty()) {
                RowDivider()
                ValueRow("Audio codec", codec)
            }
            if (showsVideo) {
                RowDivider()
                ValueRow("Video", "${stats.videoTargetBitrate / 1000} kbit/s")
            }
            if (useIce) {
                RowDivider()
                ValueRow("Path", if (stats.localCandidate == BaresipCandidateType.RELAY) "Through a relay" else "Direct")
            }
        }
    }
}

@Composable
private fun DemoQuality() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        QualityTiles(listOf("4.3" to "MOS", "0.0 %" to "Loss", "4 ms" to "Jitter", "38 ms" to "Round trip"))
        Card(radius = 16.dp) {
            ValueRow("Encryption", "SRTP")
            RowDivider()
            ValueRow("Audio codec", "opus/48000/2")
            RowDivider()
            ValueRow("Video", "800 kbit/s")
        }
    }
}

@Composable
private fun TransferContent(
    model: CallModel,
    row: CallRow,
    onDone: () -> Unit,
) {
    val held = model.heldRow
    if (held != null) {
        Note("You are asking ${row.title}. ${held.title} hears nothing.")
        Party(row, Palette.info, true)
        Party(held, Palette.secondary, false)
        FilledButton("Hand ${held.title} to ${row.title}", ButtonKind.LIGHT, height = 56.dp) {
            model.act {
                completeTransfer()
                onDone()
            }
        }
        FilledButton("End this and return to ${held.title}", ButtonKind.RAISED) {
            model.act {
                endConsultation()
                onDone()
            }
        }
        return
    }
    val target = model.transferTarget.trim()
    val name =
        if (target.isEmpty()) {
            "them"
        } else {
            io.github.mariokovacevic.baresipkit.zvono.model.SipNames
                .user(target)
        }
    Note("${row.title} waits on hold while you ask.")
    StackedField("Transfer to", model.transferTarget, { model.transferTarget = it }, "Number or address", tag = "transfer.target")
    val recent =
        model.history
            .filter { it.uri.isNotEmpty() && it.uri != row.remoteUri }
            .distinctBy { it.uri }
            .take(4)
    if (recent.isNotEmpty()) {
        TitledSection("Recent") {
            Card {
                recent.forEachIndexed { index, record ->
                    if (index > 0) RowDivider()
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .heightIn(min = 52.dp)
                            .clickable { model.transferTarget = record.uri }
                            .padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(record.name, style = Type.body, color = Palette.text, modifier = Modifier.weight(1f))
                        Text(record.user, style = Type.subheadline, color = Palette.secondary)
                        if (model.transferTarget == record.uri) Icon(Icons.Filled.Check, contentDescription = "Chosen", tint = Palette.info)
                    }
                }
            }
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        FilledButton("Ask $name first", ButtonKind.LIGHT, height = 56.dp, enabled = target.isNotEmpty()) { model.act { consult() } }
        Note("You talk to $name, then hand the call over or come back.")
    }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        FilledButton("Transfer now", ButtonKind.RAISED, enabled = target.isNotEmpty()) {
            model.act {
                blindTransfer()
                onDone()
            }
        }
        Note("The call rings $name and you leave it at once.")
    }
}

@Composable
private fun Party(
    row: CallRow,
    status: androidx.compose.ui.graphics.Color,
    highlighted: Boolean,
) {
    Card(highlighted = highlighted) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Avatar(row.initials, size = 48.dp)
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(row.title, style = Type.display(22.sp), color = Palette.text)
                Text(CallText.status(row).uppercase(), style = Type.footnoteStrong, color = status)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChatSheet(
    model: CallModel,
    peer: String,
) {
    ModalBottomSheet(
        onDismissRequest = { model.showCallChat = null },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Palette.background,
        dragHandle = null,
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.7f)
                .navigationBarsPadding()
                .imePadding(),
        ) {
            ThreadScreen(model, peer, overCall = true, onDone = { model.showCallChat = null })
        }
    }
}

@Composable
fun CallsScreen(model: CallModel) {
    rememberTick()
    Page(onBack = { model.back() }) {
        ScreenTitle("Calls")
        val calls = model.calls
        val active = model.activeCall?.id
        Card {
            calls.forEachIndexed { index, row ->
                if (index > 0) RowDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable {
                            val id = row.id ?: return@clickable
                            model.act {
                                switchTo(id)
                                callMinimized = false
                                back()
                            }
                        }.padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Avatar(row.initials, size = 44.dp)
                    Column(Modifier.weight(1f)) {
                        Text(model.doorFor(row.remoteUri)?.title ?: row.title, style = Type.bodyStrong, color = Palette.text)
                        Text(CallText.status(row), style = Type.footnote, color = if (row.id == active) Palette.info else Palette.secondary)
                    }
                    val id = row.id
                    if (id != null) {
                        RoundIcon(Icons.Filled.Pause, if (row.isOnHold) "Resume" else "Hold", size = 40.dp) { model.act { toggleHold(id) } }
                        RoundIcon(Icons.Filled.CallEnd, "Hang up", size = 40.dp) { model.act { hangUp(id) } }
                    }
                }
            }
        }
        if (model.heldRow != null) {
            FilledButton("Connect the two and leave", ButtonKind.LIGHT) { model.act { completeTransfer() } }
        }
        Note("Tap a call to switch to it; the other one waits on hold.")
    }
}
