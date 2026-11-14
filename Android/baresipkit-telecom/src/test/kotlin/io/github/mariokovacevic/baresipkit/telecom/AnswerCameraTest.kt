package io.github.mariokovacevic.baresipkit.telecom

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnswerCameraTest {
    private fun sends(
        systemVideo: Boolean?,
        pushHadVideo: Boolean = true,
        inviteHasVideo: Boolean = true,
        sendsCameraOnAnswer: Boolean = true,
    ) = BaresipTelecomAdapter.answerSendsCamera(systemVideo, pushHadVideo, inviteHasVideo, sendsCameraOnAnswer)

    @Test
    fun anAudioOnlyAnswerFromTheSystemNeverSendsTheCamera() {
        assertFalse(sends(systemVideo = false))
    }

    @Test
    fun aVideoAnswerSendsTheCameraOnlyWhenPushInviteAndSettingAgree() {
        assertTrue(sends(systemVideo = true))
        assertFalse(sends(systemVideo = true, pushHadVideo = false))
        assertFalse(sends(systemVideo = true, inviteHasVideo = false))
        assertFalse(sends(systemVideo = true, sendsCameraOnAnswer = false))
    }

    @Test
    fun withoutASystemChoiceThePushAndTheSettingDecide() {
        assertTrue(sends(systemVideo = null))
        assertFalse(sends(systemVideo = null, pushHadVideo = false))
    }
}
