package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.BaresipMessageID
import java.util.UUID

sealed interface ChatStatus {
    data object Sending : ChatStatus

    data object Delivered : ChatStatus

    data class Failed(
        val reason: String,
    ) : ChatStatus

    data object Received : ChatStatus
}

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val messageId: BaresipMessageID? = null,
    val peer: String,
    val text: String,
    val outgoing: Boolean,
    val status: ChatStatus,
    val date: Long = System.currentTimeMillis(),
    val read: Boolean = true,
) {
    val isFailed: Boolean
        get() = status is ChatStatus.Failed

    val user: String
        get() = SipNames.user(peer)
}

data class Conversation(
    val peer: String,
    val last: ChatMessage,
)

object Conversations {
    fun of(messages: List<ChatMessage>): List<Conversation> {
        val latest = LinkedHashMap<String, Pair<Int, ChatMessage>>()
        messages.forEachIndexed { position, message -> latest[message.user] = position to message }
        return latest.entries.sortedByDescending { it.value.first }.map { Conversation(it.key, it.value.second) }
    }

    fun unread(
        messages: List<ChatMessage>,
        peer: String? = null,
    ): Int =
        messages.count { message ->
            !message.outgoing && !message.read && (peer == null || message.user == SipNames.user(peer))
        }
}
