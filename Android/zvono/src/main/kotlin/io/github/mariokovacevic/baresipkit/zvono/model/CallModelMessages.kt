package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.BaresipMessage
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

fun CallModel.receive(message: BaresipMessage) {
    val text = message.text ?: "<${message.contentType}, ${message.body.size} bytes>"
    val inOpenChat = openChatPeer == SipNames.user(message.from)
    messages += ChatMessage(peer = message.from, text = text, outgoing = false, status = ChatStatus.Received, read = inOpenChat)
    append("message from ${message.from}")
    if (!system.isInForeground) {
        system.showMessage(senderName(message.from), text)
        return
    }
    if (inOpenChat || callMinimized || incomingRow != null) return
    val call = activeCall ?: return
    if (phone?.call(withPeer = message.from) !== call || callOnScreen == null) return
    showCaption(senderName(message.from), text)
}

fun CallModel.showCaption(
    sender: String,
    text: String,
) {
    val caption = CallCaption(nextCaptionId++, sender, text)
    captions = CallCaption.adding(captions, caption)
    scope.launch {
        delay(caption.lifetime)
        captions = captions.filterNot { it.id == caption.id }
    }
}

fun CallModel.unreadCount(peer: String? = null): Int = Conversations.unread(messages, peer)

fun CallModel.markRead(peer: String) {
    val user = SipNames.user(peer)
    for (index in messages.indices) {
        val message = messages[index]
        if (!message.read && message.user == user) messages[index] = message.copy(read = true)
    }
}

fun CallModel.openCallChat() {
    val call = callOnScreen ?: return
    captions = emptyList()
    showCallChat = call.remoteUri
}

val CallModel.conversations: List<Conversation>
    get() = Conversations.of(messages)

fun CallModel.messagesWith(peer: String): List<ChatMessage> {
    val user = SipNames.user(peer)
    return messages.filter { it.user == user }
}

suspend fun CallModel.send(
    text: String,
    peer: String,
) {
    val to = normalizedDestination(peer)
    if (to.isEmpty() || text.isBlank()) return
    if (demoMode) {
        messages += ChatMessage(peer = to, text = text, outgoing = true, status = ChatStatus.Delivered)
        return
    }
    val engine = engine
    if (engine == null) {
        messages += ChatMessage(peer = to, text = text, outgoing = true, status = ChatStatus.Failed("The engine is not running"))
        return
    }
    try {
        val id = engine.sendMessage(to, text, accountId)
        val status = earlyStatuses.remove(id) ?: ChatStatus.Sending
        messages += ChatMessage(messageId = id, peer = to, text = text, outgoing = true, status = status)
    } catch (error: Throwable) {
        messages += ChatMessage(peer = to, text = text, outgoing = true, status = ChatStatus.Failed(error.message ?: error.toString()))
    }
}

suspend fun CallModel.resend(message: ChatMessage) {
    messages.removeAll { it.id == message.id }
    send(message.text, message.peer)
}

fun CallModel.senderName(from: String): String {
    val call = phone?.call(withPeer = from)
    if (call != null) {
        doorFor(call.remoteUri)?.let { return it.title }
        if (call.remoteDisplayName.isNotEmpty()) return call.remoteDisplayName
    }
    return doorFor(from)?.title ?: SipNames.user(from)
}
