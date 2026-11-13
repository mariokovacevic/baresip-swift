package io.github.mariokovacevic.baresipkit.zvono

import android.content.Intent
import android.graphics.Bitmap
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.BySelector
import androidx.test.uiautomator.Direction
import androidx.test.uiautomator.StaleObjectException
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import io.github.mariokovacevic.baresipkit.zvono.model.AppTab
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.demoMessage
import io.github.mariokovacevic.baresipkit.zvono.model.demoRing
import io.github.mariokovacevic.baresipkit.zvono.model.seedDemo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class ScreenshotTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device = UiDevice.getInstance(instrumentation)
    private val application = ApplicationProvider.getApplicationContext<ZvonoApplication>()
    private val model: CallModel
        get() = application.model
    private val folder = File(application.getExternalFilesDir(null), "screenshots").apply { mkdirs() }

    @Test
    fun screens() {
        val intent =
            Intent(application, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_FRESH, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ActivityScenario.launch<MainActivity>(intent).use {
            assertNotNull(device.wait(Until.findObject(By.res("setup.title")), TIMEOUT))
            shoot("01-setup")

            onMain {
                seedDemo()
                tab = AppTab.DOORS
            }
            assertNotNull(device.wait(Until.findObject(By.textStartsWith("Reachable")), TIMEOUT))
            shoot("02-doors")

            openTab("activity")
            shoot("03-activity")

            openTab("keypad")
            for (key in listOf("1", "0", "1")) find(By.res("key.$key"))?.click()
            scrollTo(By.text("Caretaker"))
            shoot("04-keypad")

            openTab("messages")
            shoot("05-messages")
            if (open(By.res("conversation.reception"))) {
                shoot("06-conversation")
                device.pressBack()
            }

            openTab("settings")
            shoot("07-settings")
            scrollTo(By.text("Front door"))
            if (open(By.text("Front door"))) {
                shoot("08-door")
                device.pressBack()
            }
            if (open(By.res("account.link"))) {
                shoot("09-account")
                device.pressBack()
            }
            scrollTo(By.res("engine.link"))
            if (open(By.res("engine.link"))) {
                shoot("10-diagnostics")
                device.pressBack()
            }

            onMain { demoRing() }
            assertNotNull(device.wait(Until.findObject(By.res("incoming.answer")), TIMEOUT))
            shoot("11-ring")
            find(By.res("incoming.reject"))?.click()
            device.wait(Until.gone(By.res("incoming.answer")), TIMEOUT)

            openTab("doors")
            assertNotNull(find(By.res("door.look")))
            find(By.res("door.look"))?.click()
            assertNotNull(device.wait(Until.findObject(By.res("call.state")), TIMEOUT))
            shoot("12-call")
            if (open(By.res("call.more"))) {
                shoot("13-call-more")
                find(By.text("Done"))?.click()
                if (!device.wait(Until.gone(By.text("Done")), TIMEOUT)) device.pressBack()
                device.waitForIdle()
            }
            assertNotNull(find(By.res("call.state")))

            var captions = 0
            instrumentation.runOnMainSync {
                model.demoMessage("A parcel for you. I leave it at the door.")
                captions = model.captions.size
            }
            assertEquals(1, captions)
            shootNow("14-call-caption")
            if (open(By.res("call.chat"))) {
                shoot("15-call-chat")
                find(By.res("chat.done"))?.click()
                device.waitForIdle()
            }
            find(By.res("call.hangup"))?.click()
        }
    }

    private fun onMain(action: CallModel.() -> Unit) {
        instrumentation.runOnMainSync { model.action() }
        device.waitForIdle()
    }

    private fun find(selector: BySelector): UiObject2? = device.wait(Until.findObject(selector), TIMEOUT)

    private fun open(selector: BySelector): Boolean {
        val target = find(selector) ?: return false
        target.click()
        device.waitForIdle()
        Thread.sleep(SETTLE)
        return true
    }

    private fun openTab(name: String) {
        find(By.res("tab.$name"))?.click()
        device.waitForIdle()
        Thread.sleep(SETTLE)
    }

    private fun scrollTo(selector: BySelector) {
        repeat(MAXIMUM_SCROLLS) {
            if (device.hasObject(selector)) return
            val list = device.findObject(By.scrollable(true)) ?: return
            try {
                list.scroll(Direction.DOWN, 0.8f)
            } catch (_: StaleObjectException) {
                device.waitForIdle()
            }
        }
    }

    private fun shoot(name: String) {
        device.waitForIdle()
        shootNow(name)
    }

    private fun shootNow(name: String) {
        Thread.sleep(SETTLE)
        val bitmap = instrumentation.uiAutomation.takeScreenshot() ?: return
        File(folder, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private companion object {
        const val TIMEOUT = 20_000L
        const val SETTLE = 800L
        const val MAXIMUM_SCROLLS = 10
    }
}
