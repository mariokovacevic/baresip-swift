package io.github.mariokovacevic.baresipkit

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkMonitorTest {
    private val wifi = BaresipNetworkPath("wifi 192.0.2.7", true)
    private val cellular = BaresipNetworkPath("cellular 198.51.100.4", true)
    private val lost = BaresipNetworkPath("", false)

    @Test
    fun theFirstNetworkIsNotReported() {
        assertFalse(BaresipNetworkMonitor.shouldNotifyEngine(wifi, null))
    }

    @Test
    fun aChangedNetworkIsReported() {
        assertTrue(BaresipNetworkMonitor.shouldNotifyEngine(cellular, wifi))
        assertTrue(BaresipNetworkMonitor.shouldNotifyEngine(wifi, lost))
    }

    @Test
    fun aLostOrRepeatedNetworkIsNotReported() {
        assertFalse(BaresipNetworkMonitor.shouldNotifyEngine(lost, wifi))
        assertFalse(BaresipNetworkMonitor.shouldNotifyEngine(wifi, wifi))
    }
}
