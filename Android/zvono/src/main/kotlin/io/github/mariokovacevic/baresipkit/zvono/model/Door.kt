package io.github.mariokovacevic.baresipkit.zvono.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class Door(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val address: String = "",
    val code: String = "",
    val replyDigit: String = "",
    val hasCamera: Boolean = true,
    val opensFromNotification: Boolean = true,
    val asksToUnlockFirst: Boolean = false,
    val hangsUpAfterOpening: Boolean = true,
) {
    val canOpen: Boolean
        get() = code.isNotBlank()

    val title: String
        get() = name.trim().ifEmpty { SipNames.user(address) }

    val user: String
        get() = SipNames.user(address.trim())

    val openRequest: DtmfRequest
        get() = DtmfRequest(digits = code.trim(), ack = replyDigit.trim(), hangUp = hangsUpAfterOpening)

    val isEmpty: Boolean
        get() = name.isBlank() && address.isBlank()
}

fun List<Door>.matching(remote: String): Door? {
    val user = SipNames.user(remote)
    if (user.isEmpty()) return null
    return firstOrNull { it.user.isNotEmpty() && it.user == user }
}

@Serializable
data class Contact(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val address: String = "",
) {
    val title: String
        get() = name.trim().ifEmpty { SipNames.user(address.trim()) }

    val initials: String
        get() = SipNames.initials(title)
}

enum class AppTab(
    val title: String,
) {
    DOORS("Doors"),
    ACTIVITY("Activity"),
    KEYPAD("Keypad"),
    MESSAGES("Messages"),
    SETTINGS("Settings"),
}
