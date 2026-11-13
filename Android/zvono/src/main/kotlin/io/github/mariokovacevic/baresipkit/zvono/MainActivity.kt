package io.github.mariokovacevic.baresipkit.zvono

import android.Manifest
import android.app.KeyguardManager
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.lifecycleScope
import io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest
import io.github.mariokovacevic.baresipkit.zvono.model.AppTab
import io.github.mariokovacevic.baresipkit.zvono.model.OwnerCheck
import io.github.mariokovacevic.baresipkit.zvono.model.answer
import io.github.mariokovacevic.baresipkit.zvono.model.callOnScreen
import io.github.mariokovacevic.baresipkit.zvono.model.incomingRow
import io.github.mariokovacevic.baresipkit.zvono.model.openFromShortcut
import io.github.mariokovacevic.baresipkit.zvono.model.openRingingDoor
import io.github.mariokovacevic.baresipkit.zvono.model.redial
import io.github.mariokovacevic.baresipkit.zvono.ui.ZvonoApp
import io.github.mariokovacevic.baresipkit.zvono.ui.ZvonoTheme
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

class MainActivity :
    ComponentActivity(),
    OwnerCheck {
    private val model get() = (application as ZvonoApplication).model

    private val permissions =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            model.append("permissions: ${result.entries.joinToString { "${it.key.substringAfterLast('.')}=${it.value}" }}")
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT), navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        model.ownerCheck = this
        val demo = intent.getBooleanExtra(EXTRA_DEMO, false)
        val fresh = intent.getBooleanExtra(EXTRA_FRESH, false)
        lifecycleScope.launch { model.start(demo = demo, fresh = fresh) }
        setContent {
            ZvonoTheme {
                ZvonoApp(model)
                val complete = model.settings.isComplete
                LaunchedEffect(complete) { if (complete && !model.demoMode) askForPermissions() }
                val ringingOrInCall = model.incomingRow != null || model.callOnScreen != null
                LaunchedEffect(ringingOrInCall) { if (!ringingOrInCall) showOverLockScreen(false) }
            }
        }
        val fromHistory = intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (savedInstanceState == null && !fromHistory) handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    override fun onDestroy() {
        if (model.ownerCheck === this) model.ownerCheck = null
        super.onDestroy()
    }

    private fun handle(intent: Intent?) {
        when (intent?.action) {
            ACTION_SHOW_INCOMING -> showOverLockScreen(true)
            ACTION_ANSWER -> {
                showOverLockScreen(true)
                lifecycleScope.launch { model.answer() }
            }
            ACTION_OPEN_DOOR -> {
                showOverLockScreen(true)
                lifecycleScope.launch { model.openRingingDoor() }
            }
            ACTION_SHOW_CALL -> model.callMinimized = false
            ACTION_SHOW_ACTIVITY -> model.tab = AppTab.ACTIVITY
            ACTION_OPEN_DOOR_SHORTCUT, ACTION_OPEN_DOOR_NAMED -> {
                val doorId = intent.getStringExtra(EXTRA_DOOR_ID)
                val name = intent.getStringExtra(EXTRA_FEATURE)
                lifecycleScope.launch { model.openFromShortcut(doorId, name) }
            }
            ACTION_SHOW_MESSAGES -> model.tab = AppTab.MESSAGES
            else -> {
                val request = BaresipRedialRequest.from(intent) ?: return
                val trusted = intent?.component?.className == CALL_ALIAS
                model.tab = AppTab.KEYPAD
                lifecycleScope.launch { model.redial(if (trusted) request else request.copy(callsNow = false)) }
            }
        }
    }

    private fun showOverLockScreen(shown: Boolean) {
        setShowWhenLocked(shown)
        setTurnScreenOn(shown)
    }

    private fun askForPermissions() {
        val wanted = mutableListOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) wanted += Manifest.permission.POST_NOTIFICATIONS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) wanted += Manifest.permission.BLUETOOTH_CONNECT
        val missing = wanted.filter { checkSelfPermission(it) != android.content.pm.PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) permissions.launch(missing.toTypedArray())
    }

    override suspend fun confirm(reason: String): Boolean {
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (!keyguard.isDeviceSecure) return true
        return suspendCancellableCoroutine { continuation ->
            val builder = BiometricPrompt.Builder(this).setTitle(reason).setSubtitle("Confirm that it is you")
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                    builder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> allowDeviceCredential(builder)
                else -> builder.setNegativeButton("Cancel", mainExecutor) { _, _ -> if (continuation.isActive) continuation.resume(false) }
            }
            val signal = CancellationSignal()
            continuation.invokeOnCancellation { signal.cancel() }
            builder.build().authenticate(
                signal,
                mainExecutor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        if (continuation.isActive) continuation.resume(true)
                    }

                    override fun onAuthenticationError(
                        errorCode: Int,
                        errString: CharSequence,
                    ) {
                        val unavailable =
                            errorCode == BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT ||
                                errorCode == BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE ||
                                errorCode == BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS
                        if (unavailable) model.append("no biometric unlock on this phone: opening without it")
                        if (continuation.isActive) continuation.resume(unavailable)
                    }
                },
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun allowDeviceCredential(builder: BiometricPrompt.Builder) {
        builder.setDeviceCredentialAllowed(true)
    }

    companion object {
        const val ACTION_SHOW_INCOMING = "io.github.mariokovacevic.baresipkit.zvono.SHOW_INCOMING"
        const val ACTION_ANSWER = "io.github.mariokovacevic.baresipkit.zvono.ANSWER"
        const val ACTION_OPEN_DOOR = "io.github.mariokovacevic.baresipkit.zvono.OPEN_DOOR"
        const val ACTION_SHOW_CALL = "io.github.mariokovacevic.baresipkit.zvono.SHOW_CALL"
        const val ACTION_SHOW_MESSAGES = "io.github.mariokovacevic.baresipkit.zvono.SHOW_MESSAGES"
        const val ACTION_SHOW_ACTIVITY = "io.github.mariokovacevic.baresipkit.zvono.SHOW_ACTIVITY"
        const val ACTION_OPEN_DOOR_SHORTCUT = "io.github.mariokovacevic.baresipkit.zvono.OPEN_DOOR_SHORTCUT"
        const val ACTION_OPEN_DOOR_NAMED = "io.github.mariokovacevic.baresipkit.zvono.OPEN_DOOR_NAMED"
        const val EXTRA_DOOR_ID = "doorId"
        const val EXTRA_FEATURE = "door"
        const val EXTRA_DEMO = "zvono.demo"
        const val EXTRA_FRESH = "zvono.fresh"
        const val CALL_ALIAS = "io.github.mariokovacevic.baresipkit.zvono.CallAlias"
    }
}
