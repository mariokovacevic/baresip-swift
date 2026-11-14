package io.github.mariokovacevic.baresipkit.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.github.mariokovacevic.baresipkit.BaresipEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Puts the device's audio in communication mode for calls and keeps the engine informed about
 * it, the counterpart of the iOS audio session controller.
 *
 * With a self-managed `ConnectionService`, Telecom owns audio focus; forward its callbacks with
 * [didActivateFromTelecom] and [didDeactivateFromTelecom]. Without Telecom, or to hear an early
 * media preview before answering, call [activate] yourself: it requests audio focus for voice
 * communication and sets `MODE_IN_COMMUNICATION`.
 *
 * Losing audio focus, for example to a cellular call, pauses the engine's audio. When focus comes
 * back the engine resumes if [activate] had activated it; with Telecom the audio resumes with
 * the next [didActivateFromTelecom]. A headset or Bluetooth device that connects or disconnects
 * restarts the engine's audio streams.
 *
 * ```kotlin
 * val audio = BaresipAudioController(context, engine)
 * audio.activate()
 * audio.selectOutput(BaresipAudioOutput.SPEAKER)
 * ```
 *
 * @param onRouteChange Called on the main thread with the new route after each change.
 */
class BaresipAudioController(
    context: Context,
    private val engine: BaresipEngine,
    private val onRouteChange: ((BaresipAudioRoute) -> Unit)? = null,
) {
    internal enum class Activation { INACTIVE, CONTROLLER, TELECOM }

    internal enum class FocusResponse { PAUSE_ENGINE, RESUME_ENGINE, STAY }

    private val audioManager = context.getSystemService(AudioManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    @Volatile private var activation = Activation.INACTIVE
    private var focusRequest: AudioFocusRequest? = null
    private var defaultToSpeaker = false

    private val focusListener =
        AudioManager.OnAudioFocusChangeListener { change ->
            when (focusResponse(change, activation)) {
                FocusResponse.PAUSE_ENGINE -> scope.launch { engine.audioInterruption(began = true) }
                FocusResponse.RESUME_ENGINE -> scope.launch { engine.audioInterruption(began = false) }
                FocusResponse.STAY -> Unit
            }
        }

    private val deviceCallback =
        object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) = devicesChanged(addedDevices)

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) = devicesChanged(removedDevices)
        }

    private val communicationDeviceListener: Any? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            AudioManager.OnCommunicationDeviceChangedListener { device ->
                onRouteChange?.invoke(device?.let { audioRouteOf(it.type) } ?: BaresipAudioRoute.Other(0))
            }
        } else {
            null
        }

    init {
        audioManager.registerAudioDeviceCallback(deviceCallback, handler)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.addOnCommunicationDeviceChangedListener(
                context.mainExecutor,
                communicationDeviceListener as AudioManager.OnCommunicationDeviceChangedListener,
            )
        }
    }

    /**
     * Sets whether calls start on the loudspeaker, for example for a door intercom. The setting
     * applies with the next [activate].
     */
    fun configureForVoip(defaultToSpeaker: Boolean = false) {
        this.defaultToSpeaker = defaultToSpeaker
    }

    /**
     * Requests audio focus for voice communication, sets `MODE_IN_COMMUNICATION` and tells the
     * engine. Use this without Telecom.
     *
     * @return `false` when the system refused audio focus, for example during a cellular call.
     */
    suspend fun activate(): Boolean {
        val request =
            AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes
                        .Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                ).setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener(focusListener, handler)
                .build()
        if (audioManager.requestAudioFocus(request) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return false
        focusRequest = request
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        if (defaultToSpeaker) selectOutput(BaresipAudioOutput.SPEAKER)
        activation = Activation.CONTROLLER
        engine.audioSessionDidActivate()
        return true
    }

    /** Tells the engine, leaves communication mode and gives up audio focus. */
    suspend fun deactivate() {
        activation = Activation.INACTIVE
        engine.audioSessionDidDeactivate()
        clearCommunicationDevice()
        audioManager.mode = AudioManager.MODE_NORMAL
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        focusRequest = null
    }

    /** Forwards the activation of a Telecom connection's audio, for example `onCallAudioStateChanged`, to the engine. */
    suspend fun didActivateFromTelecom() {
        activation = Activation.TELECOM
        engine.audioSessionDidActivate()
    }

    /** Forwards the end of a Telecom connection's audio to the engine. */
    suspend fun didDeactivateFromTelecom() {
        activation = Activation.INACTIVE
        engine.audioSessionDidDeactivate()
    }

    /** Stops observing devices and gives up audio focus. */
    fun release() {
        audioManager.unregisterAudioDeviceCallback(deviceCallback)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.removeOnCommunicationDeviceChangedListener(
                communicationDeviceListener as AudioManager.OnCommunicationDeviceChangedListener,
            )
        }
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        focusRequest = null
    }

    /** Routes audio to the loudspeaker or back to the default route. */
    fun setSpeakerEnabled(enabled: Boolean) {
        if (enabled) selectOutput(BaresipAudioOutput.SPEAKER) else clearCommunicationDevice()
    }

    /** The current output route. */
    val currentRoute: BaresipAudioRoute
        get() = currentDevice()?.let { audioRouteOf(it.type) } ?: BaresipAudioRoute.Other(0)

    /**
     * The outputs the user can pick for call audio right now: the earpiece (unless headphones are
     * plugged in, which replace it), the loudspeaker, and each headset or car kit.
     */
    val availableOutputs: List<BaresipAudioOutput>
        get() = AudioOutputs.available(communicationDevices().map(::snapshot))

    /** The output call audio is playing on, as listed by [availableOutputs]. */
    val currentOutput: BaresipAudioOutput?
        get() = AudioOutputs.current(currentDevice()?.let(::snapshot), availableOutputs)

    /** Plays call audio on the given output, one of [availableOutputs]. */
    fun selectOutput(output: BaresipAudioOutput) {
        val devices = communicationDevices()
        val device =
            when (output.id) {
                BaresipAudioOutput.SPEAKER.id -> devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                BaresipAudioOutput.EARPIECE.id -> devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE }
                else -> devices.firstOrNull { it.id.toString() == output.id }
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (device != null) audioManager.setCommunicationDevice(device) else audioManager.clearCommunicationDevice()
            return
        }
        @Suppress("DEPRECATION")
        when (output.route) {
            BaresipAudioRoute.Speaker -> {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                audioManager.isSpeakerphoneOn = true
            }
            BaresipAudioRoute.Bluetooth -> {
                audioManager.isSpeakerphoneOn = false
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
            }
            else -> {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                audioManager.isSpeakerphoneOn = false
            }
        }
    }

    private fun clearCommunicationDevice() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        } else {
            @Suppress("DEPRECATION")
            audioManager.isSpeakerphoneOn = false
        }
    }

    private fun communicationDevices(): List<AudioDeviceInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices
        } else {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
        }

    @Suppress("DEPRECATION")
    private fun currentDevice(): AudioDeviceInfo? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.communicationDevice
        } else {
            val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val wanted =
                when {
                    audioManager.isBluetoothScoOn -> AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                    audioManager.isSpeakerphoneOn -> AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    outputs.any { audioRouteOf(it.type) == BaresipAudioRoute.WiredHeadset } ->
                        outputs.first { audioRouteOf(it.type) == BaresipAudioRoute.WiredHeadset }.type
                    else -> AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                }
            outputs.firstOrNull { it.type == wanted }
        }

    private fun snapshot(device: AudioDeviceInfo) = AudioDevice(device.id, device.type, device.productName?.toString().orEmpty())

    private fun devicesChanged(devices: Array<out AudioDeviceInfo>) {
        if (!restartsAudio(devices.map { it.type })) return
        scope.launch { engine.audioRouteDidChange() }
        onRouteChange?.invoke(currentRoute)
    }

    internal companion object {
        fun focusResponse(
            change: Int,
            activation: Activation,
        ): FocusResponse =
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> FocusResponse.PAUSE_ENGINE
                AudioManager.AUDIOFOCUS_GAIN ->
                    if (activation == Activation.CONTROLLER) FocusResponse.RESUME_ENGINE else FocusResponse.STAY
                else -> FocusResponse.STAY
            }

        fun restartsAudio(types: List<Int>): Boolean =
            types.any {
                val route = audioRouteOf(it)
                route == BaresipAudioRoute.Bluetooth || route == BaresipAudioRoute.WiredHeadset
            }
    }
}
