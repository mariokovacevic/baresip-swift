package io.github.mariokovacevic.baresipkit.zvono.model

class PictureThrottle(
    private val intervalMillis: Long = PICTURE_INTERVAL_MILLIS,
) {
    private var lastTaken: Long? = null
    private var busy = false

    @Synchronized
    fun take(nowMillis: Long): Boolean {
        if (busy) return false
        val last = lastTaken
        if (last != null && nowMillis - last < intervalMillis) return false
        busy = true
        lastTaken = nowMillis
        return true
    }

    @Synchronized
    fun finished() {
        busy = false
    }

    companion object {
        const val PICTURE_INTERVAL_MILLIS = 250L
    }
}

class RingNotice(
    private val gapMillis: Long = NOTIFICATION_GAP_MILLIS,
) {
    var shownAt: Long? = null
        private set
    var pictures = 0
        private set

    val hasPicture: Boolean
        get() = pictures > 0

    fun pictureArrived(
        nowMillis: Long,
        shows: Boolean,
    ): Boolean {
        pictures++
        if (!shows) return false
        val last = shownAt
        if (last != null && nowMillis - last < gapMillis) return false
        shownAt = nowMillis
        return true
    }

    fun shownWithoutGap(nowMillis: Long) {
        shownAt = nowMillis
    }

    fun reset() {
        shownAt = null
        pictures = 0
    }

    companion object {
        const val NOTIFICATION_GAP_MILLIS = 1000L

        fun showsPicture(
            ringPicture: Boolean,
            inForeground: Boolean,
            ringing: Boolean,
        ): Boolean = ringPicture && !inForeground && ringing

        fun leavesMissedRing(
            ringPicture: Boolean,
            hasPicture: Boolean,
            inForeground: Boolean,
            answered: Boolean,
            declinedHere: Boolean,
            endedElsewhere: Boolean,
        ): Boolean = ringPicture && hasPicture && !inForeground && !answered && !declinedHere && !endedElsewhere
    }
}

data class PreviewPlan(
    val accountAnswersEarlyMedia: Boolean,
    val video: Boolean,
    val audio: Boolean,
) {
    companion object {
        fun of(
            previewAudio: Boolean,
            earlyVideo: Boolean,
        ): PreviewPlan =
            if (previewAudio) {
                PreviewPlan(accountAnswersEarlyMedia = true, video = earlyVideo, audio = true)
            } else {
                PreviewPlan(accountAnswersEarlyMedia = false, video = earlyVideo, audio = !earlyVideo)
            }
    }
}
