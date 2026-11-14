package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.BaresipConfiguration
import io.github.mariokovacevic.baresipkit.zvono.model.AppProfile
import io.github.mariokovacevic.baresipkit.zvono.model.DefaultAppProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class AppProfileTest {
    @Test
    fun defaultProfileChangesNothing() {
        val configuration = BaresipConfiguration { userAgent = "Zvono/1.0" }
        assertSame(configuration, DefaultAppProfile.configure(configuration))
        assertNull(DefaultAppProfile.accountSection())
    }

    @Test
    fun loadsTheLocalProfileWhenOneIsCompiledIn() {
        val local = runCatching { Class.forName(AppProfile.LOCAL_CLASS) }.isSuccess
        val profile = AppProfile.load()
        assertEquals(local, profile !== DefaultAppProfile)
    }
}
