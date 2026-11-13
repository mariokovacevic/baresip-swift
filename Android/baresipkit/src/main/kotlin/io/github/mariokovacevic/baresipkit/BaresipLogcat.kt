package io.github.mariokovacevic.baresipkit

import android.util.Log

/** Sends engine log output to Logcat. */
object BaresipLogcat {
    /**
     * A log handler for [BaresipEngine.setLogHandler] that writes each line to Logcat with the
     * tag `[tag]` plus the domain, for example `BaresipKit.sip`.
     */
    fun handler(tag: String = "BaresipKit"): BaresipLogHandler =
        BaresipLogHandler { entry ->
            val name = "$tag.${entry.domain.name.lowercase()}"
            when (entry.level) {
                BaresipLogLevel.DEBUG -> Log.d(name, entry.message)
                BaresipLogLevel.INFO -> Log.i(name, entry.message)
                BaresipLogLevel.WARNING -> Log.w(name, entry.message)
                BaresipLogLevel.ERROR -> Log.e(name, entry.message)
            }
        }
}
