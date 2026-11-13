package io.github.mariokovacevic.baresipkit.zvono.system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.github.mariokovacevic.baresipkit.zvono.ZvonoApplication
import io.github.mariokovacevic.baresipkit.zvono.model.hangup
import io.github.mariokovacevic.baresipkit.zvono.model.reject
import kotlinx.coroutines.launch

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val model = (context.applicationContext as ZvonoApplication).model
        when (intent.action) {
            ACTION_DECLINE -> model.scope.launch { model.reject() }
            ACTION_HANG_UP -> model.scope.launch { model.hangup() }
        }
    }

    companion object {
        const val ACTION_DECLINE = "io.github.mariokovacevic.baresipkit.zvono.DECLINE"
        const val ACTION_HANG_UP = "io.github.mariokovacevic.baresipkit.zvono.HANG_UP"
    }
}
