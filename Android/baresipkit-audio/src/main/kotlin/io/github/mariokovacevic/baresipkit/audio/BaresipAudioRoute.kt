package io.github.mariokovacevic.baresipkit.audio

import android.media.AudioDeviceInfo

/** Where call audio is played. */
sealed interface BaresipAudioRoute {
    /** The receiver at the top of the phone. */
    data object Earpiece : BaresipAudioRoute

    /** The built-in loudspeaker. */
    data object Speaker : BaresipAudioRoute

    /** A Bluetooth headset or car kit. */
    data object Bluetooth : BaresipAudioRoute

    /** Wired or USB headphones. */
    data object WiredHeadset : BaresipAudioRoute

    /**
     * Another output, with its `AudioDeviceInfo` type.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Other(
        val type: Int,
    ) : BaresipAudioRoute
}

internal fun audioRouteOf(type: Int): BaresipAudioRoute =
    when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> BaresipAudioRoute.Earpiece
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE -> BaresipAudioRoute.Speaker
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLE_SPEAKER,
        AudioDeviceInfo.TYPE_HEARING_AID,
        -> BaresipAudioRoute.Bluetooth
        AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_DEVICE,
        -> BaresipAudioRoute.WiredHeadset
        else -> BaresipAudioRoute.Other(type)
    }

/**
 * An output the user can choose for call audio.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipAudioOutput(
    /** A stable identifier: the device id, or a fixed value for the earpiece and loudspeaker. */
    val id: String,
    /** A name to show, such as "Speaker" or the Bluetooth device's name. */
    val name: String,
    /** The kind of output. */
    val route: BaresipAudioRoute,
) {
    companion object {
        /** The receiver at the top of the phone. */
        val EARPIECE = BaresipAudioOutput("bsk.earpiece", "Phone", BaresipAudioRoute.Earpiece)

        /** The built-in loudspeaker. */
        val SPEAKER = BaresipAudioOutput("bsk.speaker", "Speaker", BaresipAudioRoute.Speaker)
    }
}

internal data class AudioDevice(
    val id: Int,
    val type: Int,
    val name: String,
)

internal object AudioOutputs {
    fun available(devices: List<AudioDevice>): List<BaresipAudioOutput> {
        val wired = devices.any { audioRouteOf(it.type) == BaresipAudioRoute.WiredHeadset }
        val outputs = mutableListOf<BaresipAudioOutput>()
        if (!wired && devices.any { it.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE }) outputs += BaresipAudioOutput.EARPIECE
        outputs += BaresipAudioOutput.SPEAKER
        for (device in devices) {
            val route = audioRouteOf(device.type)
            if (route == BaresipAudioRoute.Earpiece || route == BaresipAudioRoute.Speaker) continue
            if (outputs.any { it.name == name(device) && it.route == route }) continue
            outputs += BaresipAudioOutput(device.id.toString(), name(device), route)
        }
        return outputs
    }

    fun current(
        device: AudioDevice?,
        available: List<BaresipAudioOutput>,
    ): BaresipAudioOutput? =
        when (device?.let { audioRouteOf(it.type) }) {
            null -> null
            BaresipAudioRoute.Earpiece -> available.firstOrNull { it.id == BaresipAudioOutput.EARPIECE.id }
            BaresipAudioRoute.Speaker -> available.firstOrNull { it.id == BaresipAudioOutput.SPEAKER.id }
            else -> available.firstOrNull { it.id == device.id.toString() || it.name == name(device) }
        }

    fun name(device: AudioDevice): String =
        when (audioRouteOf(device.type)) {
            BaresipAudioRoute.WiredHeadset -> "Headphones"
            else -> device.name.ifBlank { "Audio device" }
        }
}
