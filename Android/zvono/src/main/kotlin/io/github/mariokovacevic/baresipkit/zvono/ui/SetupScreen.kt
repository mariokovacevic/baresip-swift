package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.mariokovacevic.baresipkit.BaresipTransport
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.saveAndRegister

@Composable
fun SetupScreen(model: CallModel) {
    var server by rememberSaveable { mutableStateOf("") }
    var user by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var transport by rememberSaveable { mutableStateOf(BaresipTransport.TLS) }
    var connecting by rememberSaveable { mutableStateOf(false) }
    val canConnect = server.isNotBlank() && user.isNotBlank() && password.isNotEmpty()
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        LogoMark()
        Text("Connect your intercom", style = Type.display(36.sp), color = Palette.text, modifier = Modifier.testTag("setup.title"))
        Text(
            "Zvono rings your phone when someone is at the door, shows you who it is and opens the door.",
            style = Type.body,
            color = Palette.secondary,
        )
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            StackedField("Server", server, { server = it }, "pbx.example.com", keyboardType = KeyboardType.Uri, tag = "setup.server")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StackedField("User", user, { user = it }, "100", Modifier.weight(1f), tag = "setup.user")
                StackedField("Password", password, { password = it }, "Required", Modifier.weight(1f), secure = true, tag = "setup.password")
            }
            Segments(transport, listOf(BaresipTransport.TLS, BaresipTransport.TCP, BaresipTransport.UDP), { it.name }) { transport = it }
            Row(Modifier.heightIn(min = 32.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                val tls = transport == BaresipTransport.TLS
                Icon(
                    if (tls) Icons.Outlined.Lock else Icons.Outlined.LockOpen,
                    contentDescription = null,
                    tint = if (tls) Palette.info else Palette.alert,
                    modifier = Modifier.size(20.dp),
                )
                Text(if (tls) "Encrypted connection on port 5061" else "Not encrypted, port 5060", style = Type.subheadline, color = Palette.secondary)
            }
            FilledButton(
                if (connecting) "Connecting…" else "Connect",
                ButtonKind.LIGHT,
                enabled = canConnect && !connecting,
                modifier = Modifier.testTag("setup.connect"),
            ) {
                connecting = true
                model.password = password
                model.updateSettings { it.copy(domain = server.trim(), username = user.trim(), transport = transport, port = "") }
                model.act {
                    saveAndRegister()
                    connecting = false
                }
            }
        }
        Note(
            "The password is encrypted with a key in this phone's keystore. Certificates, NAT traversal and codecs are in " +
                "Settings, Account. Next, Zvono asks for notifications, the microphone and the camera.",
        )
    }
}
