package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.zvono.R

enum class Ringtone(
    val key: String,
    val title: String,
    val sound: Int?,
) {
    PHONE("system", "Phone ringtone", null),
    CHIME("chime", "Chime", R.raw.chime),
    BELLS("bells", "Bells", R.raw.bells),
    CLASSIC("classic", "Classic", R.raw.classic),
    ;

    companion object {
        val default = CHIME

        fun of(key: String?): Ringtone = entries.firstOrNull { it.key == key } ?: default
    }
}
