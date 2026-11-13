package io.github.mariokovacevic.baresipkit.zvono.model

import androidx.compose.runtime.mutableStateMapOf

sealed interface Screen {
    data class DoorEditor(
        val doorId: String?,
    ) : Screen

    data class ContactEditor(
        val contactId: String?,
    ) : Screen

    data class Thread(
        val peer: String,
    ) : Screen

    data object Account : Screen

    data object Ringtone : Screen

    data object Diagnostics : Screen

    data object Calls : Screen

    data object CallIntegration : Screen
}

class Navigator {
    private val stacks = mutableStateMapOf<AppTab, List<Screen>>()

    fun stack(tab: AppTab): List<Screen> = stacks[tab].orEmpty()

    fun top(tab: AppTab): Screen? = stacks[tab]?.lastOrNull()

    fun push(
        tab: AppTab,
        screen: Screen,
    ) {
        stacks[tab] = stack(tab) + screen
    }

    fun pop(tab: AppTab): Boolean {
        val stack = stack(tab)
        if (stack.isEmpty()) return false
        stacks[tab] = stack.dropLast(1)
        return true
    }

    fun reset(tab: AppTab) {
        stacks[tab] = emptyList()
    }
}
