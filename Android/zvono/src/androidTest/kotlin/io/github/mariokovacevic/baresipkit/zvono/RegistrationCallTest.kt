package io.github.mariokovacevic.baresipkit.zvono

import android.Manifest
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.util.Base64
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTextReplacement
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipNatTraversal
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.zvono.model.AppTab
import io.github.mariokovacevic.baresipkit.zvono.model.CallIntegration
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.Screen
import io.github.mariokovacevic.baresipkit.zvono.model.callOnScreen
import io.github.mariokovacevic.baresipkit.zvono.model.setCa
import io.github.mariokovacevic.baresipkit.zvono.ui.back
import io.github.mariokovacevic.baresipkit.zvono.ui.open
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class RegistrationCallTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device = UiDevice.getInstance(instrumentation)
    private val application = ApplicationProvider.getApplicationContext<ZvonoApplication>()
    private val model: CallModel
        get() = application.model

    @get:Rule
    val compose = createEmptyComposeRule()

    @Test
    fun tlsRegistrationPinningAndCall() {
        val arguments = InstrumentationRegistry.getArguments()
        val host = arguments.getString("host")
        val ca = arguments.getString("caB64")
        assumeTrue("host and caB64 are not set", host != null && ca != null)
        val port = arguments.getString("port") ?: "5081"
        val peer = arguments.getString("peer") ?: "sip:bob@$host:5270"
        val turn = arguments.getString("turn") ?: "turn:$host:3478?transport=udp"

        grantPermissions()
        val launch =
            Intent(application, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_FRESH, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ActivityScenario.launch<MainActivity>(launch).use {
            waitForTag("setup.title")
            onMain {
                setCa(String(Base64.decode(ca, Base64.DEFAULT)))
                chooseCallIntegration(CallIntegration.IN_APP)
                updateSettings {
                    it.copy(
                        natMode = BaresipNatTraversal.ICE,
                        turnUri = turn,
                        turnUser = "bsk",
                        engine = it.engine.copy(iceRelayOnly = true),
                    )
                }
                turnPassword = "bsk"
            }

            openAccount()
            enter("account.domain", host!!)
            enter("account.port", port)
            enter("account.username", "alice")
            enter("account.password", "secret")
            click("account.save")
            assertTrue("not registered", waitFor { model.registration == BaresipRegistrationState.REGISTERED })
            checkDiagnosticsShow("registered")

            openAccount()
            enter("account.pins", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
            click("account.save")
            assertTrue("a wrong pin registered", waitFor { model.registration == BaresipRegistrationState.FAILED })

            openAccount()
            enter("account.pins", "")
            click("account.save")
            assertTrue("not registered again", waitFor { model.registration == BaresipRegistrationState.REGISTERED })

            click("tab.keypad")
            enter("call.destination", peer, scroll = false)
            compose.mainClock.autoAdvance = false
            try {
                tap("call.audio")
                assertTrue("call screen not shown", waitFor { model.callOnScreen != null } && waitForNode("call.state"))
                assertTrue("no media in the call", waitFor { model.callOnScreen?.state == BaresipCallState.STREAMS_RUNNING })
                Thread.sleep(SETTLE)
                tap("call.hangup")
                assertTrue("call did not end", waitFor { model.callOnScreen == null })
            } finally {
                compose.mainClock.autoAdvance = true
            }
        }
    }

    private fun grantPermissions() {
        val wanted = mutableListOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) wanted += Manifest.permission.POST_NOTIFICATIONS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) wanted += Manifest.permission.BLUETOOTH_CONNECT
        wanted.forEach { instrumentation.uiAutomation.grantRuntimePermission(application.packageName, it) }
    }

    private fun openAccount() {
        click("tab.settings")
        click("account.link", scroll = true)
        waitForTag("account.domain")
    }

    private fun checkDiagnosticsShow(text: String) {
        onMain {
            tab = AppTab.SETTINGS
            navigator.reset(AppTab.SETTINGS)
            open(Screen.Diagnostics)
        }
        val tag = "engine.registration"
        val shown = hasText(text, substring = true, ignoreCase = true) and (hasTestTag(tag) or hasAnyAncestor(hasTestTag(tag)))
        if (!waitForMatch(shown)) dump("diagnostics")
        assertTrue("$tag does not say $text", waitForMatch(shown))
        onMain { back() }
    }

    private fun enter(
        tag: String,
        text: String,
        scroll: Boolean = true,
    ) {
        waitForTag(tag)
        val node = compose.onNodeWithTag(tag)
        if (scroll) node.performScrollTo()
        node.performTextReplacement(text)
        compose.waitForIdle()
    }

    private fun click(
        tag: String,
        scroll: Boolean = false,
    ) {
        waitForTag(tag)
        val node = compose.onNodeWithTag(tag)
        if (scroll) node.performScrollTo()
        node.performSemanticsAction(SemanticsActions.OnClick)
        compose.waitForIdle()
    }

    private fun tap(tag: String) {
        compose.onNodeWithTag(tag).performSemanticsAction(SemanticsActions.OnClick)
    }

    private fun waitForNode(tag: String): Boolean {
        val end = System.currentTimeMillis() + TIMEOUT
        while (System.currentTimeMillis() < end) {
            compose.mainClock.advanceTimeBy(FRAME)
            if (compose.onAllNodes(hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()) return true
            Thread.sleep(250)
        }
        dump(tag)
        return false
    }

    private fun waitForTag(tag: String) {
        if (!waitForMatch(hasTestTag(tag))) dump(tag)
        assertTrue("$tag not shown", waitForMatch(hasTestTag(tag)))
    }

    private fun waitForMatch(matcher: SemanticsMatcher): Boolean =
        try {
            compose.waitUntil(TIMEOUT) { compose.onAllNodes(matcher, useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty() }
            true
        } catch (_: Throwable) {
            false
        }

    private fun dump(name: String) {
        val folder = File(application.getExternalFilesDir(null), "screenshots").apply { mkdirs() }
        device.dumpWindowHierarchy(File(folder, "registration-$name.xml"))
        instrumentation.uiAutomation.takeScreenshot()?.let { bitmap ->
            File(folder, "registration-$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
    }

    private fun onMain(action: CallModel.() -> Unit) {
        instrumentation.runOnMainSync { model.action() }
        compose.waitForIdle()
    }

    private fun waitFor(condition: () -> Boolean): Boolean {
        val end = System.currentTimeMillis() + WAIT
        while (System.currentTimeMillis() < end) {
            var met = false
            instrumentation.runOnMainSync { met = condition() }
            if (met) return true
            compose.mainClock.advanceTimeBy(FRAME)
            Thread.sleep(250)
        }
        return false
    }

    private companion object {
        const val TIMEOUT = 20_000L
        const val WAIT = 30_000L
        const val SETTLE = 3_000L
        const val FRAME = 16L
    }
}
