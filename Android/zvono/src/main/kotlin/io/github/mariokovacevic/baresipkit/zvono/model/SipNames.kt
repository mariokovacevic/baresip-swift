package io.github.mariokovacevic.baresipkit.zvono.model

object SipNames {
    fun user(remote: String): String {
        var value = remote
        for (scheme in listOf("sips:", "sip:", "tel:")) {
            if (value.startsWith(scheme)) value = value.removePrefix(scheme)
        }
        value = value.substringBefore(';').substringBefore('@')
        return value.ifEmpty { remote }
    }

    fun initials(name: String): String {
        val words = name.split(' ', '.', '-').filter { it.isNotEmpty() }.take(2)
        val letters = words.joinToString("") { it.first().uppercase() }
        return letters.ifEmpty { name.take(2).uppercase() }
    }

    fun normalized(
        raw: String,
        domain: String,
    ): String {
        val value = raw.trim()
        if (value.isEmpty() || value.startsWith("sip:") || value.startsWith("sips:")) return value
        if (value.contains('@')) return "sip:$value"
        return "sip:$value@${domain.trim()}"
    }

    fun address(uri: String): String {
        val bare = uri.removePrefix("sips:").removePrefix("sip:")
        return bare.substringBefore(';').substringBefore('?')
    }
}
