package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import io.github.mariokovacevic.baresipkit.BaresipCertificates
import io.github.mariokovacevic.baresipkit.BaresipDtmfMode
import io.github.mariokovacevic.baresipkit.BaresipMediaEncryption
import io.github.mariokovacevic.baresipkit.BaresipNatTraversal
import io.github.mariokovacevic.baresipkit.BaresipTransport
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.EngineOptions
import io.github.mariokovacevic.baresipkit.zvono.model.SipSettings
import io.github.mariokovacevic.baresipkit.zvono.model.importCa
import io.github.mariokovacevic.baresipkit.zvono.model.importClientIdentity
import io.github.mariokovacevic.baresipkit.zvono.model.saveAndRegister
import io.github.mariokovacevic.baresipkit.zvono.model.setCa
import io.github.mariokovacevic.baresipkit.zvono.model.setClientIdentity

private enum class CertificateTarget { CA, CLIENT }

@Composable
fun AccountScreen(model: CallModel) {
    val settings = model.settings
    val canSave = settings.isComplete && model.password.isNotEmpty()

    fun edit(change: (SipSettings) -> SipSettings) = model.updateSettings(change)
    val save = {
        model.act {
            saveAndRegister()
            back()
        }
    }
    Page(onBack = { model.back() }, actions = { TextAction("Save", enabled = canSave, modifier = Modifier.testTag("account.save"), onClick = save) }) {
        ScreenTitle("Account")
        model.profile.accountSection()?.invoke(model)
        TitledSection("Server", note = "Registrar: ${settings.registrar}") {
            Card {
                FieldRow("Domain", settings.domain, { value -> edit { it.copy(domain = value) } }, "pbx.example.com", KeyboardType.Uri, tag = "account.domain")
                RowDivider()
                SegmentRow("Transport", settings.transport, listOf(BaresipTransport.TLS, BaresipTransport.TCP, BaresipTransport.UDP), { it.name }) { value ->
                    edit { it.copy(transport = value) }
                }
                RowDivider()
                FieldRow(
                    "Port",
                    settings.port,
                    { value -> edit { it.copy(port = value.filter(Char::isDigit)) } },
                    if (settings.transport == BaresipTransport.TLS) "5061" else "5060",
                    KeyboardType.Number,
                    tag = "account.port",
                )
                RowDivider()
                FieldRow("Outbound proxy", settings.outboundProxy, { value -> edit { it.copy(outboundProxy = value) } }, "None", KeyboardType.Uri)
            }
        }
        TitledSection("Credentials", note = "The passwords are encrypted with a key kept in this phone's keystore.") {
            Card {
                FieldRow("Username", settings.username, { value -> edit { it.copy(username = value) } }, "100", tag = "account.username")
                RowDivider()
                FieldRow("Password", model.password, { model.password = it }, "Required", secure = true, tag = "account.password")
                RowDivider()
                FieldRow("Auth user", settings.authUser, { value -> edit { it.copy(authUser = value) } }, "Same as username")
                RowDivider()
                FieldRow("Display name", settings.displayName, { value -> edit { it.copy(displayName = value) } }, "None")
            }
        }
        CertificateSections(model)
        TitledSection(
            "Incoming calls",
            note =
                "Every incoming call is previewed with 183 Session Progress: the caller's media is received before answering, " +
                    "for example from a door station, while your microphone and camera stay off. Off receives only the picture " +
                    "when the caller offers video. Reachable keeps the registration on the server, so a push can announce a " +
                    "call while the app is closed.",
        ) {
            Card {
                ToggleRow("Stay reachable by push", settings.reachableInBackground, { value -> edit { it.copy(reachableInBackground = value) } })
                RowDivider()
                ToggleRow("Audio in the preview", settings.previewAudio, { value -> edit { it.copy(previewAudio = value) } })
                RowDivider()
                ToggleRow("Accept transfers", settings.acceptTransfers, { value -> edit { it.copy(acceptTransfers = value) } })
            }
        }
        TitledSection("Media", note = "Picture updates also ask for a new video picture with SIP INFO, for door stations that ignore RTCP.") {
            Card {
                MenuRow(
                    "Encryption",
                    settings.mediaEncryption,
                    listOf(BaresipMediaEncryption.SRTP_OPTIONAL, BaresipMediaEncryption.SRTP_MANDATORY, BaresipMediaEncryption.DTLS_SRTP, BaresipMediaEncryption.NONE),
                    {
                        when (it) {
                            BaresipMediaEncryption.SRTP_OPTIONAL -> "SRTP optional"
                            BaresipMediaEncryption.SRTP_MANDATORY -> "SRTP required"
                            BaresipMediaEncryption.DTLS_SRTP -> "DTLS-SRTP"
                            BaresipMediaEncryption.NONE -> "None"
                        }
                    },
                ) { value -> edit { it.copy(mediaEncryption = value) } }
                RowDivider()
                ToggleRow("Picture updates over SIP INFO", settings.pictureUpdateOverInfo, { value -> edit { it.copy(pictureUpdateOverInfo = value) } })
            }
        }
        NatSection(model)
        TitledSection(
            "SIP",
            note =
                "SIP Outbound keeps the registration flow open through NAT. Door stations take door-opening codes as SIP INFO; " +
                    "Automatic sends RFC 4733 events when the peer supports them and SIP INFO otherwise.",
        ) {
            Card {
                ToggleRow("SIP Outbound (RFC 5626)", settings.sipOutbound, { value -> edit { it.copy(sipOutbound = value) } })
                RowDivider()
                MenuRow(
                    "Registration lasts",
                    settings.registerExpiresSeconds,
                    (SipSettings.registrationTimes + settings.registerExpiresSeconds).distinct().sorted(),
                    SipSettings::durationText,
                ) { value -> edit { it.copy(registerExpiresSeconds = value) } }
                RowDivider()
                MenuRow(
                    "DTMF",
                    settings.dtmfMode,
                    BaresipDtmfMode.entries,
                    {
                        when (it) {
                            BaresipDtmfMode.AUTO -> "Automatic"
                            BaresipDtmfMode.RTP_EVENT -> "RFC 4733"
                            BaresipDtmfMode.SIP_INFO -> "SIP INFO"
                        }
                    },
                ) { value -> edit { it.copy(dtmfMode = value) } }
            }
        }
        CodecSection(model)
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            FilledButton("Save and register", ButtonKind.LIGHT, enabled = canSave, onClick = save)
            Note(
                "Everything you enter is saved right away: the passwords and the client key encrypted with the keystore, the rest " +
                    "in the app's private storage, which is left out of backups. It takes effect when you tap Save and register; " +
                    "changing certificates or engine settings restarts the SIP engine.",
            )
        }
    }
}

@Composable
private fun CertificateSections(model: CallModel) {
    val context = LocalContext.current
    var target by remember { mutableStateOf(CertificateTarget.CA) }
    var pasting by remember { mutableStateOf<CertificateTarget?>(null) }
    val importer =
        rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            val data = uri?.let { runCatching { context.contentResolver.openInputStream(it)?.use { stream -> stream.readBytes() } }.getOrNull() }
            if (data != null) {
                if (target == CertificateTarget.CA) model.importCa(data) else model.importClientIdentity(data)
            }
        }
    val settings = model.settings
    TitledSection(
        "Server certificate",
        note = "A private CA for a self-signed server, as PEM or DER. Pins are base64 SHA-256 hashes of the server's public key; with pins only those keys are accepted.",
    ) {
        Card {
            val summaries = model.caSummaries
            ValueRow("Trusted CA", if (summaries.isEmpty()) "System" else summaries.joinToString("\n"))
            RowDivider()
            CardButton("Import a CA file") {
                target = CertificateTarget.CA
                importer.launch(arrayOf("*/*"))
            }
            RowDivider()
            CardButton("Paste a CA as PEM") { pasting = CertificateTarget.CA }
            if (summaries.isNotEmpty()) {
                RowDivider()
                CardButton("Remove the CA", destructive = true) { model.setCa("") }
            }
            RowDivider()
            Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("SPKI pins", style = Type.subheadline, color = Palette.text)
                PlainTextField(
                    settings.pins,
                    { value -> model.updateSettings { it.copy(pins = value) } },
                    "None",
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 24.dp)
                        .testTag("account.pins"),
                    style = Type.footnote,
                    singleLine = false,
                )
            }
        }
    }
    TitledSection("Client certificate", note = "For servers that ask for one: a certificate with its private key, as one PEM file or pasted.") {
        Card {
            val summaries = model.clientSummaries
            ValueRow("Certificate", summaries.firstOrNull() ?: "None")
            RowDivider()
            CardButton("Import a certificate and key") {
                target = CertificateTarget.CLIENT
                importer.launch(arrayOf("*/*"))
            }
            RowDivider()
            CardButton("Paste as PEM") { pasting = CertificateTarget.CLIENT }
            if (summaries.isNotEmpty()) {
                RowDivider()
                CardButton("Remove the client certificate", destructive = true) { model.setClientIdentity("", "") }
            }
        }
    }
    pasting?.let { kind -> PemDialog(model, kind) { pasting = null } }
}

@Composable
private fun PemDialog(
    model: CallModel,
    kind: CertificateTarget,
    onDismiss: () -> Unit,
) {
    var certificate by remember { mutableStateOf(if (kind == CertificateTarget.CLIENT) BaresipCertificates.split(model.clientIdentity).first else "") }
    var key by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Palette.raised,
        title = { Text(if (kind == CertificateTarget.CA) "CA certificates" else "Client certificate", style = Type.title, color = Palette.text) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                StackedField("Certificate (PEM)", certificate, { certificate = it }, "-----BEGIN CERTIFICATE-----")
                if (kind == CertificateTarget.CLIENT) StackedField("Private key (PEM)", key, { key = it }, "-----BEGIN PRIVATE KEY-----", secure = true)
                error?.let { Text(it, style = Type.footnote, color = Palette.alert) }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                runCatching { if (kind == CertificateTarget.CA) model.setCa(certificate) else model.setClientIdentity(certificate, key) }
                    .onSuccess { onDismiss() }
                    .onFailure { error = it.message ?: it.toString() }
            }) { Text("Use", color = Palette.info) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Palette.info) } },
    )
}

@Composable
private fun NatSection(model: CallModel) {
    val settings = model.settings

    fun edit(change: (SipSettings) -> SipSettings) = model.updateSettings(change)
    TitledSection(
        "NAT",
        note =
            "STUN only learns the public address; ICE also checks paths and can use a TURN relay. Relay only forces media " +
                "through TURN. The pinhole sends empty RTP packets during a preview, so media relays forward the caller's media " +
                "even without ICE. A call without RTP for the timeout ends. Relay only and IPv6 restart the engine.",
    ) {
        Card {
            SegmentRow("Traversal", settings.natMode, BaresipNatTraversal.entries, { if (it == BaresipNatTraversal.NONE) "None" else it.name }) { value ->
                edit { it.copy(natMode = value) }
            }
            if (settings.natMode != BaresipNatTraversal.NONE) {
                RowDivider()
                FieldRow("STUN server", settings.stunUri, { value -> edit { it.copy(stunUri = value) } }, "stun:stun.example.com", KeyboardType.Uri)
            }
            if (settings.natMode == BaresipNatTraversal.ICE) {
                RowDivider()
                FieldRow("TURN server", settings.turnUri, { value -> edit { it.copy(turnUri = value) } }, "turns:turn.example.com:5349", KeyboardType.Uri)
                RowDivider()
                FieldRow("TURN user", settings.turnUser, { value -> edit { it.copy(turnUser = value) } }, "None")
                RowDivider()
                FieldRow("TURN password", model.turnPassword, { model.turnPassword = it }, "None", secure = true)
                RowDivider()
                ToggleRow("Relay only (TURN)", settings.engine.iceRelayOnly, { value -> edit { it.copy(engine = it.engine.copy(iceRelayOnly = value)) } })
            }
            RowDivider()
            ToggleRow("RTCP on the RTP port", settings.rtcpMux, { value -> edit { it.copy(rtcpMux = value) } })
            RowDivider()
            ToggleRow("NAT pinhole while previewing", settings.pinhole, { value -> edit { it.copy(pinhole = value) } })
            RowDivider()
            StepperRow(
                "RTP timeout",
                if (settings.rtpTimeoutSeconds == 0) "Off" else "${settings.rtpTimeoutSeconds} s",
                { edit { it.copy(rtpTimeoutSeconds = (it.rtpTimeoutSeconds - 10).coerceAtLeast(0)) } },
                { edit { it.copy(rtpTimeoutSeconds = (it.rtpTimeoutSeconds + 10).coerceAtMost(300)) } },
            )
            RowDivider()
            ToggleRow("IPv6", settings.engine.ipv6, { value -> edit { it.copy(engine = it.engine.copy(ipv6 = value)) } })
        }
    }
}

@Composable
private fun CodecSection(model: CallModel) {
    val settings = model.settings

    fun edit(change: (SipSettings) -> SipSettings) = model.updateSettings(change)
    TitledSection(
        "Codecs and video",
        note =
            "Codecs in order of preference, separated by commas, for example \"opus, G722, PCMA\" or \"H264\". Empty offers " +
                "every codec. Video size, frame rate, bitrate and adaptive bitrate restart the engine.",
    ) {
        Card {
            FieldRow("Audio codecs", settings.audioCodecs, { value -> edit { it.copy(audioCodecs = value) } }, "Default")
            RowDivider()
            FieldRow("Video codecs", settings.videoCodecs, { value -> edit { it.copy(videoCodecs = value) } }, "Default")
            RowDivider()
            MenuRow("Video size", settings.engine.videoHeight, EngineOptions.videoHeights, { if (it == 0) "Default" else "${EngineOptions.width(it)} x $it" }) { value ->
                edit { it.copy(engine = it.engine.copy(videoHeight = value)) }
            }
            RowDivider()
            MenuRow("Frame rate", settings.engine.videoFramesPerSecond, EngineOptions.videoFrameRates, { if (it == 0) "Default" else "$it per second" }) { value ->
                edit { it.copy(engine = it.engine.copy(videoFramesPerSecond = value)) }
            }
            RowDivider()
            MenuRow("Video bitrate", settings.engine.videoBitrateKbps, EngineOptions.videoBitrates, { if (it == 0) "Default" else "$it kbit/s" }) { value ->
                edit { it.copy(engine = it.engine.copy(videoBitrateKbps = value)) }
            }
            RowDivider()
            ToggleRow("Adaptive video bitrate", settings.engine.adaptiveBitrate, { value -> edit { it.copy(engine = it.engine.copy(adaptiveBitrate = value)) } })
        }
    }
}
