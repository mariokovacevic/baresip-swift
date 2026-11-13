package io.github.mariokovacevic.baresipkit.zvono.model

import android.content.Context
import androidx.compose.runtime.Composable
import io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration
import io.github.mariokovacevic.baresipkit.BaresipConfiguration
import io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration

interface AppProfile {
    fun configure(configuration: BaresipConfiguration): BaresipConfiguration = configuration

    fun configure(account: BaresipAccountConfiguration): BaresipAccountConfiguration = account

    fun configure(telecom: BaresipTelecomConfiguration): BaresipTelecomConfiguration = telecom

    fun pushAppId(context: Context): String = context.packageName

    fun accountSection(): (@Composable (CallModel) -> Unit)? = null

    companion object {
        const val LOCAL_CLASS = "io.github.mariokovacevic.baresipkit.zvono.local.LocalAppProfile"

        fun load(onError: (Throwable) -> Unit = {}): AppProfile {
            val type =
                try {
                    Class.forName(LOCAL_CLASS)
                } catch (_: ClassNotFoundException) {
                    return DefaultAppProfile
                }
            return try {
                type.getDeclaredConstructor().newInstance() as AppProfile
            } catch (error: Throwable) {
                onError(error)
                DefaultAppProfile
            }
        }
    }
}

object DefaultAppProfile : AppProfile
