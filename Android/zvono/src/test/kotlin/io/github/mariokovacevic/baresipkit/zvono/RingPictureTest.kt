package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.BaresipPixelFormat
import io.github.mariokovacevic.baresipkit.zvono.model.FramePictures
import io.github.mariokovacevic.baresipkit.zvono.model.FramePlanes
import io.github.mariokovacevic.baresipkit.zvono.model.PictureThrottle
import io.github.mariokovacevic.baresipkit.zvono.model.PreviewPlan
import io.github.mariokovacevic.baresipkit.zvono.model.RingNotice
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RingPictureTest {
    @Test
    fun picturesAreTakenAboutFourTimesASecondAndNeverWhileOneIsSaved() {
        val throttle = PictureThrottle()
        assertTrue(throttle.take(1000))
        assertFalse(throttle.take(1300))
        throttle.finished()
        assertFalse(throttle.take(1200))
        assertTrue(throttle.take(1250))
        throttle.finished()
        var taken = 0
        for (now in 2000L until 3000L step 10) {
            if (throttle.take(now)) {
                taken++
                throttle.finished()
            }
        }
        assertEquals(4, taken)
    }

    @Test
    fun theNotificationFollowsThePicturesAtMostOnceASecond() {
        val notice = RingNotice()
        assertFalse(notice.hasPicture)
        assertTrue(notice.pictureArrived(0, shows = true))
        assertFalse(notice.pictureArrived(250, shows = true))
        assertFalse(notice.pictureArrived(750, shows = true))
        assertTrue(notice.pictureArrived(1000, shows = true))
        assertFalse(notice.pictureArrived(5000, shows = false))
        assertEquals(5, notice.pictures)
        notice.reset()
        assertFalse(notice.hasPicture)
        notice.shownWithoutGap(10_000)
        assertFalse(notice.pictureArrived(10_500, shows = true))
    }

    @Test
    fun picturesAreShownOnlyInTheBackgroundWhileRingingAndWhenSwitchedOn() {
        assertTrue(RingNotice.showsPicture(ringPicture = true, inForeground = false, ringing = true))
        assertFalse(RingNotice.showsPicture(ringPicture = false, inForeground = false, ringing = true))
        assertFalse(RingNotice.showsPicture(ringPicture = true, inForeground = true, ringing = true))
        assertFalse(RingNotice.showsPicture(ringPicture = true, inForeground = false, ringing = false))
    }

    @Test
    fun onlyAnUnansweredRingLeavesAMissedRing() {
        fun missed(
            answered: Boolean = false,
            declined: Boolean = false,
            elsewhere: Boolean = false,
            foreground: Boolean = false,
            picture: Boolean = true,
            setting: Boolean = true,
        ) = RingNotice.leavesMissedRing(setting, picture, foreground, answered, declined, elsewhere)
        assertTrue(missed())
        assertFalse(missed(answered = true))
        assertFalse(missed(declined = true))
        assertFalse(missed(elsewhere = true))
        assertFalse(missed(foreground = true))
        assertFalse(missed(picture = false))
        assertFalse(missed(setting = false))
    }

    @Test
    fun thePreviewReceivesVideoOnlyWhenTheAccountTakesNoAudio() {
        assertEquals(PreviewPlan(accountAnswersEarlyMedia = true, video = true, audio = true), PreviewPlan.of(previewAudio = true, earlyVideo = true))
        assertEquals(PreviewPlan(accountAnswersEarlyMedia = false, video = true, audio = false), PreviewPlan.of(previewAudio = false, earlyVideo = true))
        assertEquals(PreviewPlan(accountAnswersEarlyMedia = false, video = false, audio = true), PreviewPlan.of(previewAudio = false, earlyVideo = false))
    }

    @Test
    fun framesAreConvertedAndScaledDown() {
        assertEquals(1, FramePictures.step(320, 480))
        assertEquals(2, FramePictures.step(640, 480))
        assertEquals(3, FramePictures.step(1280, 480))
        assertEquals(0xFF000000.toInt(), FramePictures.yuvToArgb(16, 128, 128))
        assertEquals(0xFFFFFFFF.toInt(), FramePictures.yuvToArgb(235, 128, 128))
        val width = 4
        val height = 2
        val luma = ByteArray(width * height) { if (it % width < 2) 16 else 235.toByte() }
        val planes =
            FramePlanes(
                BaresipPixelFormat.I420,
                width,
                height,
                rotationDegrees = 0,
                step = 2,
                luma = luma,
                chroma = ByteArray(2) { 128.toByte() },
                chromaSecond = ByteArray(2) { 128.toByte() },
            )
        assertEquals(2, planes.pictureWidth)
        assertEquals(1, planes.pictureHeight)
        assertEquals(listOf(0xFF000000.toInt(), 0xFFFFFFFF.toInt()), planes.argb().toList())
        val bgra = FramePlanes(BaresipPixelFormat.BGRA, 1, 1, 0, 1, byteArrayOf(1, 2, 3, -1), ByteArray(0), null)
        assertEquals(0xFF030201.toInt(), bgra.argb().single())
    }
}
