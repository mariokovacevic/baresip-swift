package io.github.mariokovacevic.baresipkit.compose

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

internal object VideoClaims {
    data class Key(
        val engine: Any,
        val call: Any?,
        val local: Boolean,
    )

    private val next = AtomicLong()
    private val owners = ConcurrentHashMap<Key, Long>()

    fun claim(key: Key): Long = next.incrementAndGet().also { owners[key] = it }

    fun release(
        key: Key,
        claim: Long,
    ): Boolean = owners.remove(key, claim)
}
