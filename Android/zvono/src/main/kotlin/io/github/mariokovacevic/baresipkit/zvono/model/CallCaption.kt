package io.github.mariokovacevic.baresipkit.zvono.model

import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

data class CallCaption(
    val id: Long,
    val sender: String,
    val text: String,
) {
    val lifetime: Duration
        get() {
            val words = text.split(' ', '\n', '\t').count { it.isNotEmpty() }
            return minOf(MAXIMUM_MILLISECONDS, BASE_MILLISECONDS + words * PER_WORD_MILLISECONDS).milliseconds
        }

    companion object {
        const val LIMIT = 3
        private const val BASE_MILLISECONDS = 4000L
        private const val PER_WORD_MILLISECONDS = 300L
        private const val MAXIMUM_MILLISECONDS = 10_000L

        fun adding(
            captions: List<CallCaption>,
            caption: CallCaption,
        ): List<CallCaption> = (captions + caption).takeLast(LIMIT)
    }
}
