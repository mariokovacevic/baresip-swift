package io.github.mariokovacevic.baresipkit.zvono.ui

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall
import io.github.mariokovacevic.baresipkit.zvono.model.CallIntegration
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.Ringtone
import io.github.mariokovacevic.baresipkit.zvono.model.Screen
import io.github.mariokovacevic.baresipkit.zvono.model.activeCall
import io.github.mariokovacevic.baresipkit.zvono.model.register
import io.github.mariokovacevic.baresipkit.zvono.model.saveAndRegister
import io.github.mariokovacevic.baresipkit.zvono.model.unregister
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(model: CallModel) {
    Page {
        ScreenTitle("Settings")
        TitledSection("Account") {
            Card {
                LinkRow(
                    if (model.settings.isComplete) "${model.settings.username.trim()} at ${model.settings.domain.trim()}" else "Set up account",
                    modifier = Modifier.testTag("account.link"),
                ) { model.open(Screen.Account) }
                Row(
                    Modifier.padding(start = 16.dp, end = 16.dp, bottom = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    StatusDot(registrationColor(model.registration))
                    Text(registrationText(model), style = Type.footnote, color = Palette.secondary, modifier = Modifier.testTag("registration.state"))
                }
            }
        }
        TitledSection("When a door rings") {
            Card {
                ToggleRow(
                    "Reachable when Zvono is closed",
                    model.settings.reachableInBackground,
                    { value -> model.updateSettings { it.copy(reachableInBackground = value) } },
                    "Stays registered, so a push wakes the app for a ring",
                )
                RowDivider()
                ToggleRow(
                    "Hear the door before answering",
                    model.settings.previewAudio,
                    { value ->
                        model.updateSettings { it.copy(previewAudio = value) }
                        if (model.settings.isComplete) model.act { saveAndRegister() }
                    },
                    "The visitor cannot hear you until you answer",
                )
                RowDivider()
                ToggleRow(
                    "Picture in the notification",
                    model.settings.ringPicture,
                    { value -> model.updateSettings { it.copy(ringPicture = value) } },
                    "Shown while the phone rings, kept when you miss it",
                    Modifier.testTag("settings.ringPicture"),
                )
                RowDivider()
                LinkRow("Ringtone", model.ringtone.title, modifier = Modifier.testTag("settings.ringtone")) { model.open(Screen.Ringtone) }
                RowDivider()
                LinkRow("Call integration", model.callIntegration.title, modifier = Modifier.testTag("settings.callIntegration")) {
                    model.open(Screen.CallIntegration)
                }
            }
        }
        TitledSection("Doors") {
            Card {
                for (door in model.doors) {
                    LinkRow(door.title, if (door.canOpen) "Code set" else "No code", modifier = Modifier.testTag("settings.door")) {
                        model.open(Screen.DoorEditor(door.id))
                    }
                    RowDivider()
                }
                AddRow("Add a door") { model.open(Screen.DoorEditor(null)) }
            }
        }
        TitledSection("Contacts", note = "Call and write to them from the keypad.") {
            Card {
                for (contact in model.contacts) {
                    LinkRow(contact.title, contact.address) { model.open(Screen.ContactEditor(contact.id)) }
                    RowDivider()
                }
                AddRow("Add a contact") { model.open(Screen.ContactEditor(null)) }
            }
        }
        TitledSection("Support") {
            Card {
                LinkRow("Diagnostics and log", modifier = Modifier.testTag("engine.link")) { model.open(Screen.Diagnostics) }
                RowDivider()
                ValueRow("Recorded calls", "In the app's Recordings folder")
            }
        }
    }
}

@Composable
private fun AddRow(
    title: String,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Filled.Add, contentDescription = null, tint = Palette.info)
        Text(title, style = Type.bodyStrong, color = Palette.info)
    }
}

fun registrationColor(state: BaresipRegistrationState) =
    when (state) {
        BaresipRegistrationState.REGISTERED -> Palette.info
        BaresipRegistrationState.FAILED -> Palette.alert
        BaresipRegistrationState.REGISTERING, BaresipRegistrationState.UNREGISTERING -> Palette.brass
        BaresipRegistrationState.NONE -> Palette.secondary
    }

private fun registrationText(model: CallModel): String =
    when (model.registration) {
        BaresipRegistrationState.REGISTERED -> {
            val ca = if (model.caSummaries.isEmpty()) "system CA" else "private CA"
            val pins = model.settings.pinList.size
            val pinText = if (pins == 0) "" else ", $pins pin${if (pins == 1) "" else "s"}"
            "Registered over ${model.settings.transportName.uppercase()}, $ca$pinText"
        }
        BaresipRegistrationState.REGISTERING -> "Registering…"
        BaresipRegistrationState.UNREGISTERING -> "Signing out…"
        BaresipRegistrationState.FAILED -> "Registration failed${model.registrationError?.let { ": $it" }.orEmpty()}"
        BaresipRegistrationState.NONE -> model.registrationError ?: "Offline"
    }

@Composable
fun RingtoneScreen(model: CallModel) {
    DisposableEffect(Unit) { onDispose { model.system.stopPlaying() } }
    Page(onBack = { model.back() }) {
        ScreenTitle("Ringtone")
        Card {
            Ringtone.entries.forEachIndexed { index, ringtone ->
                if (index > 0) RowDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 54.dp)
                        .clickable(role = Role.RadioButton) {
                            model.ringtone = ringtone
                            if (model.activeCall == null) model.system.playOnce(ringtone)
                        }.padding(horizontal = 16.dp)
                        .testTag("ringtone.${ringtone.key}"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(ringtone.title, style = Type.body, color = Palette.text, modifier = Modifier.weight(1f))
                    if (model.ringtone == ringtone) Icon(Icons.Filled.Check, contentDescription = "Selected", tint = Palette.brass)
                }
            }
        }
        Note(
            if (model.ringtone == Ringtone.PHONE) {
                "Calls ring with the ringtone set in the phone's sound settings."
            } else {
                "Calls ring with this sound while Zvono shows the ringing door. It plays once when you pick it."
            },
        )
    }
}

@Composable
fun DiagnosticsScreen(model: CallModel) {
    val context = LocalContext.current
    var confirmClear by remember { mutableStateOf(false) }
    val phone = model.phone
    Page(onBack = { model.back() }) {
        ScreenTitle("Diagnostics")
        TitledSection("Right now") {
            Card {
                val registrations =
                    phone
                        ?.registrations
                        .orEmpty()
                        .entries
                        .sortedBy { it.key.rawValue }
                if (registrations.isEmpty()) ValueRow("Registration", "No account reported yet")
                for ((account, state) in registrations) {
                    ValueRow("Account ${account.rawValue}", state.name.lowercase(), Modifier.testTag("engine.registration"))
                    RowDivider()
                }
                ValueRow("Network", model.lastNetworkPath ?: "Unknown")
                RowDivider()
                ValueRow("Push", if (model.pushToken == null) "No Firebase token (see README)" else "Token sent with the registration")
                RowDivider()
                Row {
                    CardButton("Register", Modifier.weight(1f), enabled = model.settings.isComplete) { model.act { register() } }
                    CardButton("Unregister", Modifier.weight(1f), enabled = model.settings.isComplete) { model.act { unregister() } }
                }
            }
        }
        TitledSection("Calls in the engine") {
            Card {
                val calls = phone?.calls.orEmpty()
                if (calls.isEmpty()) ValueRow("Calls", "None")
                calls.forEachIndexed { index, call ->
                    if (index > 0) RowDivider()
                    EngineCallRow(model, call)
                }
            }
        }
        TitledSection("Log") {
            Card {
                ToggleRow(
                    "Log SIP messages",
                    model.logsSipMessages,
                    { model.logsSipMessages = it },
                    "They hold numbers, addresses and door codes. Applies after the engine restarts.",
                    Modifier.testTag("log.sipMessages"),
                )
            }
            val shape = RoundedCornerShape(16.dp)
            Text(
                model.log
                    .takeLast(60)
                    .reversed()
                    .joinToString("\n"),
                style = Type.caption.copy(fontFamily = FontFamily.Monospace),
                color = Palette.secondary,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 120.dp)
                        .clip(shape)
                        .background(Palette.callBackground)
                        .border(1.dp, Palette.line, shape)
                        .padding(14.dp),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilledButton("Share the log", ButtonKind.RAISED, Modifier.weight(1f).testTag("log.share"), height = 48.dp) {
                    val authority = "${context.packageName}.files"
                    val uris = ArrayList(model.fileLog.files().map { FileProvider.getUriForFile(context, authority, it) })
                    val send =
                        Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                            type = "text/plain"
                            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    context.startActivity(Intent.createChooser(send, "Share the log").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                FilledButton("Clear", ButtonKind.RAISED, Modifier.weight(1f), height = 48.dp, enabled = model.log.isNotEmpty()) { confirmClear = true }
            }
        }
    }
    if (confirmClear) {
        ConfirmDialog(
            "Clear the log on screen?",
            "Clear",
            message = "The log files you can share are kept for seven days.",
            onDismiss = { confirmClear = false },
        ) { model.log.clear() }
    }
}

@Composable
private fun EngineCallRow(
    model: CallModel,
    call: BaresipPhoneCall,
) {
    Row(
        Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(call.displayName, style = Type.subheadlineStrong, color = Palette.text, maxLines = 1)
            val parts = mutableListOf(call.state.name.lowercase())
            if (call.isHeldByRemote) parts += "held by the other side"
            if (call.audioCodec.isNotEmpty()) parts += call.audioCodec
            if (call.videoCodec.isNotEmpty()) parts += call.videoCodec
            Text(parts.joinToString(", "), style = Type.footnote, color = Palette.secondary, modifier = Modifier.testTag("engine.call.state"))
        }
        SquareIcon(if (call.isMuted) Icons.Filled.MicOff else Icons.Filled.Mic, if (call.isMuted) "Unmute" else "Mute", call.isConnected) {
            model.scope.launch { runCatching { call.setMuted(!call.isMuted) } }
        }
        SquareIcon(Icons.Filled.Pause, if (call.isOnHold) "Resume" else "Hold", call.isConnected || call.isOnHold) {
            model.scope.launch { runCatching { call.setOnHold(!call.isOnHold) } }
        }
        Box(
            Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(22.dp))
                .background(Palette.hangUp)
                .clickable(role = Role.Button) {
                    model.scope.launch { runCatching { call.hangUp() } }
                }.semantics { contentDescription = "Hang up" },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Close, contentDescription = null, tint = Palette.alert)
        }
    }
}

@Composable
private fun SquareIcon(
    icon: ImageVector,
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        Modifier
            .size(44.dp)
            .clip(shape)
            .background(Palette.raised)
            .border(1.dp, Palette.field, shape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = if (enabled) Palette.text else Palette.secondary, modifier = Modifier.size(20.dp))
    }
}

@Composable
fun CallIntegrationScreen(model: CallModel) {
    Page(onBack = { model.back() }) {
        ScreenTitle("Call integration")
        Card {
            CallIntegration.entries.forEachIndexed { index, choice ->
                if (index > 0) RowDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 64.dp)
                        .clickable(role = Role.RadioButton) { model.chooseCallIntegration(choice) }
                        .padding(horizontal = 16.dp, vertical = 10.dp)
                        .testTag("callIntegration.${choice.key}"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(choice.title, style = Type.body, color = Palette.text)
                        Text(choice.detail, style = Type.footnote, color = Palette.secondary)
                    }
                    if (model.callIntegration == choice) Icon(Icons.Filled.Check, contentDescription = "Selected", tint = Palette.brass)
                }
            }
        }
        Note(
            "System hands calls to Android's Telecom, which routes audio, mutes for other calls and shows them to Bluetooth " +
                "devices and cars. In app only keeps calls inside Zvono, which then requests the audio focus and picks the " +
                "output itself. The SIP engine restarts with the choice once no call runs.",
        )
    }
}
