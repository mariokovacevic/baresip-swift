package io.github.mariokovacevic.baresipkit.zvono.system

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.PowerManager

class ProximityWatcher(
    context: Context,
    private val onChange: (Boolean) -> Unit,
) : SensorEventListener {
    private val sensors = context.getSystemService(SensorManager::class.java)
    private val power = context.getSystemService(PowerManager::class.java)
    private val sensor: Sensor? = sensors?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
    private var screenOff: PowerManager.WakeLock? = null
    private var near: Boolean? = null

    val isWatching: Boolean
        get() = screenOff != null || near != null

    fun start() {
        val sensor = sensor ?: return
        if (near != null) return
        near = false
        sensors?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        if (power?.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK) == true) {
            screenOff =
                power.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "zvono:proximity").apply {
                    setReferenceCounted(false)
                    acquire(MAXIMUM_HOLD_MILLIS)
                }
        }
    }

    fun stop() {
        if (near == null) return
        sensors?.unregisterListener(this)
        screenOff?.let { lock -> if (lock.isHeld) lock.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY) }
        screenOff = null
        val wasNear = near == true
        near = null
        if (wasNear) onChange(false)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (near == null) return
        val range = sensor?.maximumRange ?: return
        val isNear = event.values.firstOrNull()?.let { it < minOf(range, NEAR_CENTIMETERS) } ?: return
        if (isNear == near) return
        near = isNear
        onChange(isNear)
    }

    override fun onAccuracyChanged(
        sensor: Sensor?,
        accuracy: Int,
    ) = Unit

    private companion object {
        const val NEAR_CENTIMETERS = 5f
        const val MAXIMUM_HOLD_MILLIS = 4L * 60 * 60 * 1000
    }
}
