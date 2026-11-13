package io.github.mariokovacevic.baresipkit.telecom

import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.SipIdentity
import java.util.UUID

internal enum class PushMatch {
    MISMATCH,
    ANY_CALLER,
    USER,
    USER_AND_HOST,
    ;

    companion object {
        fun between(
            push: String?,
            invite: String,
            matchesPushWithoutCaller: Boolean,
        ): PushMatch {
            val pushed = SipIdentity(push.orEmpty())
            if (pushed.isEmpty) return if (matchesPushWithoutCaller) ANY_CALLER else MISMATCH
            val caller = SipIdentity(invite)
            if (pushed.user != caller.user) return MISMATCH
            if (pushed.host.isEmpty()) return USER
            return if (pushed.host == caller.host) USER_AND_HOST else MISMATCH
        }
    }
}

internal class PushCallLedger(
    val matchesPushWithoutCaller: Boolean,
) {
    data class Announcement(
        val uuid: UUID,
        val remoteUri: String?,
        val hasVideo: Boolean,
        val namedByServer: Boolean = true,
    )

    sealed interface Resolution {
        data object Unannounced : Resolution

        data class Announced(
            val announcement: Announcement,
            val callerConfirmed: Boolean,
        ) : Resolution

        data object Declined : Resolution
    }

    private class Entry(
        val announcement: Announcement,
        var declinedUntil: Long? = null,
    )

    private data class Ringing(
        val remoteUri: String,
        val uuid: UUID?,
    )

    private val entries = mutableListOf<Entry>()
    private val ringing = mutableMapOf<BaresipCallID, Ringing>()
    private val spent = ArrayDeque<UUID>()

    fun duplicatesRingingCall(
        remoteUri: String?,
        namedByServer: Boolean = false,
    ): Boolean =
        ringing.values.any { call ->
            (!namedByServer || call.uuid == null) && strength(remoteUri, call.remoteUri) != PushMatch.MISMATCH
        }

    fun isAnnounced(uuid: UUID): Boolean = pendingIndex(uuid) != null

    fun knows(uuid: UUID): Boolean = entries.any { it.announcement.uuid == uuid } || uuid in spent

    fun add(
        announcement: Announcement,
        now: Long,
    ) {
        forgetExpiredDeclines(now)
        entries += Entry(announcement)
    }

    fun discard(uuid: UUID): Boolean {
        val index = pendingIndex(uuid) ?: return false
        entries.removeAt(index)
        markSpent(uuid)
        return true
    }

    fun decline(
        uuid: UUID,
        until: Long,
    ): Boolean {
        val index = pendingIndex(uuid) ?: return false
        entries[index].declinedUntil = until
        return true
    }

    fun resolve(
        invite: String,
        uuid: UUID? = null,
        now: Long,
    ): Resolution {
        forgetExpiredDeclines(now)
        if (uuid != null && entries.any { it.announcement.uuid == uuid }) return resolve(uuid)
        var bestIndex = -1
        var bestMatch = PushMatch.MISMATCH
        entries.forEachIndexed { index, entry ->
            if (uuid != null && entry.announcement.namedByServer) return@forEachIndexed
            val candidate = strength(entry.announcement.remoteUri, invite)
            if (candidate > bestMatch) {
                bestIndex = index
                bestMatch = candidate
            }
        }
        if (bestIndex < 0) return Resolution.Unannounced
        val entry = entries.removeAt(bestIndex)
        if (entry.declinedUntil != null) return Resolution.Declined
        return Resolution.Announced(entry.announcement, bestMatch == PushMatch.USER_AND_HOST)
    }

    private fun resolve(uuid: UUID): Resolution {
        val index = entries.indexOfFirst { it.announcement.uuid == uuid }
        if (index < 0) return Resolution.Unannounced
        val entry = entries.removeAt(index)
        if (entry.declinedUntil != null) return Resolution.Declined
        return Resolution.Announced(entry.announcement, true)
    }

    fun startedRinging(
        call: BaresipCallID,
        remoteUri: String,
        uuid: UUID? = null,
    ) {
        ringing[call] = Ringing(remoteUri, uuid)
    }

    fun stoppedRinging(call: BaresipCallID) {
        ringing.remove(call)
    }

    fun removeAll() {
        entries.clear()
        ringing.clear()
        spent.clear()
    }

    private fun pendingIndex(uuid: UUID): Int? = entries.indexOfFirst { it.announcement.uuid == uuid && it.declinedUntil == null }.takeIf { it >= 0 }

    private fun forgetExpiredDeclines(now: Long) {
        val expired = entries.filter { entry -> entry.declinedUntil?.let { it <= now } ?: false }
        entries -= expired
        expired.forEach { markSpent(it.announcement.uuid) }
    }

    private fun markSpent(uuid: UUID) {
        spent.addLast(uuid)
        while (spent.size > SPENT_LIMIT) spent.removeFirst()
    }

    private fun strength(
        push: String?,
        invite: String,
    ): PushMatch = PushMatch.between(push, invite, matchesPushWithoutCaller)

    companion object {
        const val SPENT_LIMIT = 64

        fun sendsCamera(
            pushHadVideo: Boolean,
            inviteHasVideo: Boolean,
            sendsCameraOnAnswer: Boolean,
        ): Boolean = pushHadVideo && inviteHasVideo && sendsCameraOnAnswer

        fun callerName(
            inviteUri: String,
            inviteDisplayName: String,
            replacingAnnouncedName: Boolean,
        ): String? {
            if (inviteDisplayName.isNotEmpty()) return inviteDisplayName
            return if (replacingAnnouncedName) inviteUri else null
        }
    }
}
