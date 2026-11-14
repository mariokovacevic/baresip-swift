package io.github.mariokovacevic.baresipkit.audio

import android.media.AudioDeviceInfo
import android.media.AudioManager
import io.github.mariokovacevic.baresipkit.audio.BaresipAudioController.Activation
import io.github.mariokovacevic.baresipkit.audio.BaresipAudioController.FocusResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AudioControllerTest {
    private val earpiece = AudioDevice(1, AudioDeviceInfo.TYPE_BUILTIN_EARPIECE, "Phone")
    private val speaker = AudioDevice(2, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, "Phone")
    private val car = AudioDevice(7, AudioDeviceInfo.TYPE_BLUETOOTH_SCO, "Car kit")
    private val wired = AudioDevice(9, AudioDeviceInfo.TYPE_WIRED_HEADSET, "USB-C")

    @Test
    fun routesFollowTheDeviceType() {
        assertEquals(BaresipAudioRoute.Earpiece, audioRouteOf(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE))
        assertEquals(BaresipAudioRoute.Speaker, audioRouteOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER))
        assertEquals(BaresipAudioRoute.Bluetooth, audioRouteOf(AudioDeviceInfo.TYPE_BLE_HEADSET))
        assertEquals(BaresipAudioRoute.WiredHeadset, audioRouteOf(AudioDeviceInfo.TYPE_USB_HEADSET))
        assertEquals(BaresipAudioRoute.Other(AudioDeviceInfo.TYPE_HDMI), audioRouteOf(AudioDeviceInfo.TYPE_HDMI))
    }

    @Test
    fun outputsListTheEarpieceSpeakerAndHeadsets() {
        val outputs = AudioOutputs.available(listOf(earpiece, speaker, car))
        assertEquals(listOf(BaresipAudioOutput.EARPIECE, BaresipAudioOutput.SPEAKER, BaresipAudioOutput("7", "Car kit", BaresipAudioRoute.Bluetooth)), outputs)
    }

    @Test
    fun wiredHeadphonesReplaceTheEarpiece() {
        val outputs = AudioOutputs.available(listOf(earpiece, speaker, wired))
        assertFalse(outputs.contains(BaresipAudioOutput.EARPIECE))
        assertTrue(outputs.contains(BaresipAudioOutput("9", "Headphones", BaresipAudioRoute.WiredHeadset)))
    }

    @Test
    fun aTabletWithoutAnEarpieceOffersTheSpeaker() {
        assertEquals(listOf(BaresipAudioOutput.SPEAKER), AudioOutputs.available(listOf(speaker)))
    }

    @Test
    fun theCurrentOutputIsFoundByRouteOrDevice() {
        val outputs = AudioOutputs.available(listOf(earpiece, speaker, car))
        assertEquals(BaresipAudioOutput.SPEAKER, AudioOutputs.current(speaker, outputs))
        assertEquals(BaresipAudioOutput.EARPIECE, AudioOutputs.current(earpiece, outputs))
        assertEquals("7", AudioOutputs.current(car, outputs)?.id)
        assertEquals(null, AudioOutputs.current(null, outputs))
    }

    @Test
    fun losingFocusPausesAndRegainingItResumesOnlyWhatTheControllerActivated() {
        assertEquals(FocusResponse.PAUSE_ENGINE, BaresipAudioController.focusResponse(AudioManager.AUDIOFOCUS_LOSS_TRANSIENT, Activation.CONTROLLER))
        assertEquals(FocusResponse.PAUSE_ENGINE, BaresipAudioController.focusResponse(AudioManager.AUDIOFOCUS_LOSS, Activation.TELECOM))
        assertEquals(FocusResponse.RESUME_ENGINE, BaresipAudioController.focusResponse(AudioManager.AUDIOFOCUS_GAIN, Activation.CONTROLLER))
        assertEquals(FocusResponse.STAY, BaresipAudioController.focusResponse(AudioManager.AUDIOFOCUS_GAIN, Activation.TELECOM))
        assertEquals(FocusResponse.STAY, BaresipAudioController.focusResponse(AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK, Activation.CONTROLLER))
    }

    @Test
    fun onlyHeadsetsComingOrGoingRestartTheAudio() {
        assertTrue(BaresipAudioController.restartsAudio(listOf(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)))
        assertTrue(BaresipAudioController.restartsAudio(listOf(AudioDeviceInfo.TYPE_WIRED_HEADPHONES)))
        assertFalse(BaresipAudioController.restartsAudio(listOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)))
        assertFalse(BaresipAudioController.restartsAudio(listOf(AudioDeviceInfo.TYPE_HDMI)))
    }
}
