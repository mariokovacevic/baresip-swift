package io.github.mariokovacevic.baresipkit.compose

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VideoClaimsTest {
    private val engine = Any()

    @Test
    fun theOnlyClaimReleasesTheVideo() {
        val key = VideoClaims.Key(engine, 1, local = true)
        val claim = VideoClaims.claim(key)
        assertTrue(VideoClaims.release(key, claim))
        assertFalse(VideoClaims.release(key, claim))
    }

    @Test
    fun anOlderClaimDoesNotStopTheVideoOfANewerOne() {
        val key = VideoClaims.Key(engine, null, local = true)
        val old = VideoClaims.claim(key)
        val new = VideoClaims.claim(key)
        assertFalse(VideoClaims.release(key, old))
        assertTrue(VideoClaims.release(key, new))
    }

    @Test
    fun claimsOfOtherCallsAndSourcesAreIndependent() {
        val local = VideoClaims.Key(engine, 1, local = true)
        val remote = VideoClaims.Key(engine, 1, local = false)
        val other = VideoClaims.Key(engine, 2, local = true)
        val a = VideoClaims.claim(local)
        val b = VideoClaims.claim(remote)
        val c = VideoClaims.claim(other)
        assertTrue(VideoClaims.release(remote, b))
        assertTrue(VideoClaims.release(local, a))
        assertTrue(VideoClaims.release(other, c))
    }
}
