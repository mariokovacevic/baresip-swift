package io.github.mariokovacevic.baresipkit.zvono.model

data class DoorShortcut(
    val id: String,
    val doorId: String,
    val shortLabel: String,
    val longLabel: String,
    val rank: Int,
)

object DoorShortcuts {
    const val PREFIX = "door-"
    const val LIMIT = 4
    private const val SHORT_LABEL_LENGTH = 25

    fun of(
        doors: List<Door>,
        limit: Int = LIMIT,
    ): List<DoorShortcut> =
        doors
            .filter { it.canOpen && it.title.isNotBlank() }
            .take(limit.coerceAtLeast(0))
            .mapIndexed { rank, door ->
                val label = "Open ${door.title}"
                DoorShortcut(
                    id = PREFIX + door.id,
                    doorId = door.id,
                    shortLabel = if (label.length <= SHORT_LABEL_LENGTH) label else label.take(SHORT_LABEL_LENGTH - 1) + "…",
                    longLabel = label,
                    rank = rank,
                )
            }

    fun door(
        doors: List<Door>,
        doorId: String?,
        name: String?,
    ): Door? {
        val openable = doors.filter { it.canOpen }
        doorId?.let { id -> openable.firstOrNull { it.id == id }?.let { return it } }
        val wanted =
            name
                ?.trim()
                ?.lowercase()
                ?.removePrefix("the ")
                ?.ifEmpty { null } ?: return null
        return openable.firstOrNull { it.title.lowercase() == wanted } ?: openable.firstOrNull { it.title.lowercase().contains(wanted) }
    }
}

enum class CallIntegration(
    val key: String,
    val title: String,
    val detail: String,
) {
    SYSTEM("system", "System (Telecom)", "Calls appear to the system: Bluetooth buttons, car kits, watches and other calls know about them"),
    IN_APP("app", "In app only", "Zvono handles calls on its own and takes the audio focus itself"),
    ;

    companion object {
        val default = SYSTEM

        fun of(key: String?): CallIntegration = entries.firstOrNull { it.key == key } ?: default
    }
}
