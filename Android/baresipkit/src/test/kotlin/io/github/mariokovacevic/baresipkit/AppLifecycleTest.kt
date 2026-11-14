package io.github.mariokovacevic.baresipkit

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.time.Duration.Companion.milliseconds

class AppLifecycleTest {
    @Before
    fun requireHostCore() = HostCore.require()

    private suspend fun waitFor(condition: () -> Boolean) {
        repeat(200) {
            if (condition()) return
            delay(10)
        }
    }

    @Test
    fun theEngineIsSuspendedInTheBackgroundAndResumedInTheForeground() =
        runBlocking {
            BaresipEngine(HostCore.configuration()).use { engine ->
                engine.start()
                val lifecycle = BaresipAppLifecycle(engine)
                val changes = CopyOnWriteArrayList<BaresipAppLifecycle.Change>()
                lifecycle.setChangeHandler { changes += it }
                lifecycle.didEnterBackground()
                lifecycle.goAwayIfIdle()
                waitFor { lifecycle.isAway }
                assertTrue(lifecycle.isAway)
                lifecycle.didBecomeActive()
                waitFor { changes.size >= 2 }
                assertFalse(lifecycle.isAway)
                engine.stop()
                assertEquals(listOf(BaresipAppLifecycle.Change.SUSPENDED, BaresipAppLifecycle.Change.BACK_ONLINE), changes)
            }
        }

    @Test
    fun accountsGoOfflineInTheBackgroundAndRegisterAgainInTheForeground() =
        runBlocking {
            BaresipEngine(HostCore.configuration()).use { engine ->
                engine.start()
                val account = engine.addAccount(BaresipAccountConfiguration(aor = "sip:alice@127.0.0.1:9") { transport = BaresipTransport.UDP })
                engine.register(account)
                val lifecycle = BaresipAppLifecycle(engine)
                lifecycle.backgroundBehavior = BaresipAppLifecycle.BackgroundBehavior.GO_OFFLINE
                lifecycle.unregisterTimeout = 300.milliseconds
                val changes = CopyOnWriteArrayList<BaresipAppLifecycle.Change>()
                lifecycle.setChangeHandler { changes += it }
                lifecycle.didEnterBackground()
                lifecycle.goAwayIfIdle()
                waitFor { lifecycle.isAway }
                assertTrue(lifecycle.isAway)
                val offline = engine.accounts()[account]
                assertNotEquals(BaresipRegistrationState.REGISTERED, offline)
                assertNotEquals(BaresipRegistrationState.REGISTERING, offline)
                lifecycle.didBecomeActive()
                waitFor { changes.size >= 2 }
                val online = engine.accounts()[account]
                engine.stop()
                assertFalse(lifecycle.isAway)
                assertEquals(listOf(BaresipAppLifecycle.Change.WENT_OFFLINE, BaresipAppLifecycle.Change.BACK_ONLINE), changes)
                assertNotEquals(BaresipRegistrationState.NONE, online)
            }
        }

    @Test
    fun nothingIsSuspendedWhenTurnedOff() =
        runBlocking {
            BaresipEngine(HostCore.configuration()).use { engine ->
                engine.start()
                val lifecycle = BaresipAppLifecycle(engine)
                lifecycle.backgroundBehavior = BaresipAppLifecycle.BackgroundBehavior.STAY_ONLINE
                lifecycle.didEnterBackground()
                lifecycle.goAwayIfIdle()
                engine.stop()
                assertFalse(lifecycle.isAway)
            }
        }

    @Test
    fun aStoppedEngineIsNotSuspended() =
        runBlocking {
            BaresipEngine(HostCore.configuration()).use { engine ->
                val lifecycle = BaresipAppLifecycle(engine)
                lifecycle.didEnterBackground()
                lifecycle.goAwayIfIdle()
                assertFalse(lifecycle.isAway)
            }
        }
}
