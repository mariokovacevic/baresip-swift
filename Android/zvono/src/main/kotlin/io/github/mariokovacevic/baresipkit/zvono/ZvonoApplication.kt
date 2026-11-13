package io.github.mariokovacevic.baresipkit.zvono

import android.app.Application
import android.os.Build
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipFileLog
import io.github.mariokovacevic.baresipkit.video.BaresipCamera
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.PushReceiver
import io.github.mariokovacevic.baresipkit.zvono.model.SettingsStore
import io.github.mariokovacevic.baresipkit.zvono.model.movedToBackground
import io.github.mariokovacevic.baresipkit.zvono.model.movedToForeground
import io.github.mariokovacevic.baresipkit.zvono.system.AndroidCallSystem
import io.github.mariokovacevic.baresipkit.zvono.system.KeystoreSecretStore
import io.github.mariokovacevic.baresipkit.zvono.system.PreferencesStore
import java.io.File

class ZvonoApplication : Application() {
    lateinit var model: CallModel
        private set

    val push: PushReceiver
        get() = model

    override fun onCreate() {
        super.onCreate()
        BaresipCamera.install(this)
        val log = BaresipFileLog(File(filesDir, "Logs"))
        val store =
            SettingsStore(
                PreferencesStore(getSharedPreferences("zvono", MODE_PRIVATE)),
                KeystoreSecretStore(getSharedPreferences("zvono.secrets", MODE_PRIVATE)),
                logsSipMessagesByDefault = BuildConfig.DEBUG,
            )
        model = CallModel(this, store, log, AndroidCallSystem(this), BuildConfig.DEBUG)
        log.write(
            "launched $packageName ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE}) on Android ${Build.VERSION.RELEASE}, " +
                "BaresipKit core ${runCatching { BaresipEngine.coreVersion }.getOrDefault("unknown")}",
        )
        ProcessLifecycleOwner.get().lifecycle.addObserver(
            object : DefaultLifecycleObserver {
                override fun onStart(owner: LifecycleOwner) = model.movedToForeground()

                override fun onStop(owner: LifecycleOwner) = model.movedToBackground()
            },
        )
    }
}
