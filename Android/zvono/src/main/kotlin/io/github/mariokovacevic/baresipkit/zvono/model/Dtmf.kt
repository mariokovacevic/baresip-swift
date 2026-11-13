package io.github.mariokovacevic.baresipkit.zvono.model

import kotlin.time.Duration.Companion.seconds

data class DtmfRequest(
    val digits: String,
    val ack: String,
    val hangUp: Boolean,
) {
    val replyDigit: Char?
        get() = ack.firstOrNull()

    companion object {
        val ackTimeout = 10.seconds
        val hangUpDelay = 1.seconds
        val replyChoices = listOf("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "#")
    }
}

data class DtmfState(
    val request: DtmfRequest,
    val sent: Boolean = false,
    val result: String? = null,
) {
    val opened: Boolean
        get() = sent && result?.startsWith("failed") != true
}
