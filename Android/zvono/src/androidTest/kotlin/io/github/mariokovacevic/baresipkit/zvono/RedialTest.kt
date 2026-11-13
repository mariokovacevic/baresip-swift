package io.github.mariokovacevic.baresipkit.zvono

import android.content.Intent
import android.net.Uri
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.DEMO_HOST
import io.github.mariokovacevic.baresipkit.zvono.model.seedDemo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RedialTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device = UiDevice.getInstance(instrumentation)
    private val application = ApplicationProvider.getApplicationContext<ZvonoApplication>()
    private val model: CallModel
        get() = application.model

    @Test
    fun onlyTrustedCallIntentsPlaceTheCall() {
        val launch =
            Intent(application, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_FRESH, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ActivityScenario.launch<MainActivity>(launch).use {
            assertNotNull(device.wait(Until.findObject(By.res("setup.title")), TIMEOUT))
            val door = "sip:frontdoor@$DEMO_HOST"

            send(Intent.ACTION_CALL, door, VideoProfile.STATE_AUDIO_ONLY, MainActivity.CALL_ALIAS)
            assertTrue(waitFor { model.pendingRedial != null })
            assertEquals(BaresipRedialRequest(door, false, callsNow = true), model.pendingRedial)

            instrumentation.runOnMainSync {
                model.seedDemo()
                model.destination = ""
            }
            send(Intent.ACTION_VIEW, door, VideoProfile.STATE_BIDIRECTIONAL, null)
            assertTrue(waitFor { model.destination == door })
            assertNull(model.demoCall)

            send(Intent.ACTION_CALL, door, VideoProfile.STATE_BIDIRECTIONAL, MainActivity::class.java.name)
            Thread.sleep(SETTLE)
            assertNull(model.demoCall)

            send(Intent.ACTION_CALL, door, VideoProfile.STATE_BIDIRECTIONAL, MainActivity.CALL_ALIAS)
            assertNotNull(device.wait(Until.findObject(By.res("call.state")), TIMEOUT))
            assertNull(model.pendingRedial)
            assertEquals(door, model.demoCall?.remoteUri)
            assertEquals(true, model.demoCall?.sendingVideo)
            device.wait(Until.findObject(By.res("call.hangup")), TIMEOUT)?.click()
        }
    }

    private fun send(
        action: String,
        uri: String,
        videoState: Int,
        component: String?,
    ) {
        val intent =
            Intent(action, Uri.parse(uri))
                .putExtra(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, videoState)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (component == null) intent.setPackage(application.packageName) else intent.setClassName(application.packageName, component)
        application.startActivity(intent)
        device.waitForIdle()
    }

    private fun waitFor(condition: () -> Boolean): Boolean {
        val end = System.currentTimeMillis() + TIMEOUT
        while (System.currentTimeMillis() < end) {
            var met = false
            instrumentation.runOnMainSync { met = condition() }
            if (met) return true
            Thread.sleep(100)
        }
        return false
    }

    private companion object {
        const val TIMEOUT = 20_000L
        const val SETTLE = 1_500L
    }
}
