package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dialpad
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import io.github.mariokovacevic.baresipkit.zvono.model.AppTab
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.Screen
import io.github.mariokovacevic.baresipkit.zvono.model.callOnScreen
import io.github.mariokovacevic.baresipkit.zvono.model.incomingRow
import io.github.mariokovacevic.baresipkit.zvono.model.unreadCount
import kotlinx.coroutines.launch

fun CallModel.act(action: suspend CallModel.() -> Unit) {
    scope.launch { action() }
}

fun CallModel.open(screen: Screen) = navigator.push(tab, screen)

fun CallModel.back() = navigator.pop(tab)

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun ZvonoApp(model: CallModel) {
    Box(Modifier.fillMaxSize().background(Palette.background).semantics { testTagsAsResourceId = true }) {
        Scaffold(containerColor = Palette.background, bottomBar = { TabBar(model) }) { padding ->
            Box(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .consumeWindowInsets(padding)
                    .imePadding(),
            ) {
                TabContent(model)
            }
        }
        BackHandler(enabled = model.navigator.stack(model.tab).isNotEmpty()) { model.back() }
        val incoming = model.incomingRow
        val onScreen = model.callOnScreen
        when {
            incoming != null -> IncomingCallScreen(model, incoming)
            onScreen != null && !model.callMinimized -> InCallScreen(model, onScreen)
        }
    }
}

@Composable
private fun TabContent(model: CallModel) {
    val tab = model.tab
    val screen = model.navigator.top(tab)
    key(tab, screen) {
        when (screen) {
            null ->
                when (tab) {
                    AppTab.DOORS -> if (model.settings.isComplete) DoorsScreen(model) else SetupScreen(model)
                    AppTab.ACTIVITY -> ActivityScreen(model)
                    AppTab.KEYPAD -> KeypadScreen(model)
                    AppTab.MESSAGES -> MessagesScreen(model)
                    AppTab.SETTINGS -> SettingsScreen(model)
                }
            is Screen.DoorEditor -> DoorScreen(model, screen.doorId)
            is Screen.ContactEditor -> ContactScreen(model, screen.contactId)
            is Screen.Thread -> ThreadScreen(model, screen.peer, overCall = false, onDone = { model.back() })
            Screen.Account -> AccountScreen(model)
            Screen.Ringtone -> RingtoneScreen(model)
            Screen.Diagnostics -> DiagnosticsScreen(model)
            Screen.Calls -> CallsScreen(model)
            Screen.CallIntegration -> CallIntegrationScreen(model)
        }
    }
}

@Composable
private fun TabBar(model: CallModel) {
    NavigationBar(containerColor = Palette.bar, tonalElevation = 0.dp) {
        for (tab in AppTab.entries) {
            val selected = model.tab == tab
            NavigationBarItem(
                selected = selected,
                onClick = {
                    if (selected) model.navigator.reset(tab) else model.tab = tab
                },
                icon = {
                    val unread = if (tab == AppTab.MESSAGES) model.unreadCount() else 0
                    if (unread > 0) {
                        BadgedBox(badge = { Badge(containerColor = Palette.brass, contentColor = Palette.onBrass) { Text("$unread") } }) {
                            Icon(tab.icon, contentDescription = null)
                        }
                    } else {
                        Icon(tab.icon, contentDescription = null)
                    }
                },
                label = { Text(tab.title, style = Type.small) },
                modifier = Modifier.testTag("tab.${tab.name.lowercase()}"),
                colors =
                    NavigationBarItemDefaults.colors(
                        selectedIconColor = Palette.brass,
                        selectedTextColor = Palette.brass,
                        indicatorColor = Palette.brassSoft,
                        unselectedIconColor = Palette.secondary,
                        unselectedTextColor = Palette.secondary,
                    ),
            )
        }
    }
}

private val AppTab.icon: ImageVector
    get() =
        when (this) {
            AppTab.DOORS -> Icons.Outlined.Home
            AppTab.ACTIVITY -> Icons.Outlined.Schedule
            AppTab.KEYPAD -> Icons.Filled.Dialpad
            AppTab.MESSAGES -> Icons.Outlined.ChatBubbleOutline
            AppTab.SETTINGS -> Icons.Outlined.Tune
        }

@Composable
fun Page(
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        if (onBack != null) {
            BackBar(onBack, actions)
        } else {
            Row(
                Modifier.fillMaxWidth().height(52.dp).padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
                verticalAlignment = Alignment.CenterVertically,
                content = actions,
            )
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            content = content,
        )
    }
}
