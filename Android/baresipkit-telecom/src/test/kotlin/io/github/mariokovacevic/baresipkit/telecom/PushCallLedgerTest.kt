package io.github.mariokovacevic.baresipkit.telecom

import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.SipIdentity
import io.github.mariokovacevic.baresipkit.telecom.PushCallLedger.Announcement
import io.github.mariokovacevic.baresipkit.telecom.PushCallLedger.Resolution
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class PushMatchTest {
    private fun match(
        push: String?,
        invite: String,
        withoutCaller: Boolean = true,
    ) = PushMatch.between(push, invite, withoutCaller)

    @Test
    fun sameUserAndHostIsTheStrongestMatch() {
        assertEquals(PushMatch.USER_AND_HOST, match("sip:100@pbx.example.com", "<sip:100@pbx.example.com:5061;transport=tls>"))
        assertEquals(PushMatch.USER_AND_HOST, match("SIP:100@PBX.example.com", "\"Bob\" <sips:100@pbx.example.com>;tag=1"))
        assertEquals(PushMatch.USER_AND_HOST, match("sip:100@[2001:db8::1]:5061", "sip:100@[2001:db8::1]"))
    }

    @Test
    fun aPushWithoutHostMatchesTheUser() {
        assertEquals(PushMatch.USER, match("100", "sip:100@pbx.example.com"))
        assertEquals(PushMatch.USER, match("sip:100", "sip:100@pbx.example.com"))
    }

    @Test
    fun aPushThatNamesACallerNeverMatchesAnotherUserOrHost() {
        assertEquals(PushMatch.MISMATCH, match("100", "sip:1001@pbx.example.com"))
        assertEquals(PushMatch.MISMATCH, match("sip:100@pbx.example.com", "sip:200@pbx.example.com"))
        assertEquals(PushMatch.MISMATCH, match("sip:100@a.example.com", "sip:100@b.example.com"))
        assertEquals(PushMatch.MISMATCH, match("sip:100@a.example.com", "tel:100"))
        assertEquals(PushMatch.MISMATCH, match("sip:100@[2001:db8::1]", "sip:100@[2001:db8::2]"))
    }

    @Test
    fun aPushWithoutCallerMatchesAnyCallerOnlyWhenAllowed() {
        assertEquals(PushMatch.ANY_CALLER, match(null, "sip:anyone@example.com"))
        assertEquals(PushMatch.ANY_CALLER, match("", "sip:anyone@example.com"))
        assertEquals(PushMatch.ANY_CALLER, match("  ", "sip:anyone@example.com"))
        assertEquals(PushMatch.MISMATCH, match(null, "sip:anyone@example.com", withoutCaller = false))
        assertEquals(PushMatch.MISMATCH, match("", "sip:anyone@example.com", withoutCaller = false))
        assertEquals(PushMatch.USER_AND_HOST, match("sip:100@example.com", "sip:100@example.com", withoutCaller = false))
    }

    @Test
    fun matchesAreOrderedByStrength() {
        assertTrue(PushMatch.MISMATCH < PushMatch.ANY_CALLER)
        assertTrue(PushMatch.ANY_CALLER < PushMatch.USER)
        assertTrue(PushMatch.USER < PushMatch.USER_AND_HOST)
    }

    @Test
    fun identityParsing() {
        assertEquals("alice", SipIdentity("<sip:Alice@Example.com:5060;transport=tcp>").user)
        assertEquals("example.com", SipIdentity("<sip:Alice@Example.com:5060;transport=tcp>").host)
        assertEquals("example.com", SipIdentity("sip:alice@example.com?subject=hello").host)
        assertEquals("", SipIdentity("alice").host)
        assertTrue(SipIdentity(" ").isEmpty)
        assertFalse(SipIdentity("sip:alice@example.com").isEmpty)
    }

    @Test
    fun onlyANumericUserIsAPhoneNumber() {
        assertEquals("100", SipIdentity("sip:100@pbx.example.com").phoneNumber)
        assertEquals("+15555550100", SipIdentity("<sip:+15555550100@pbx.example.com;user=phone>").phoneNumber)
        assertEquals("+15555550100", SipIdentity("tel:+15555550100").phoneNumber)
        assertEquals("100", SipIdentity("100").phoneNumber)
        assertNull(SipIdentity("sip:door1@pbx.example.com").phoneNumber)
        assertNull(SipIdentity("sip:+@pbx.example.com").phoneNumber)
        assertNull(SipIdentity("sip:10-0@pbx.example.com").phoneNumber)
        assertNull(SipIdentity("sip:pbx.example.com").phoneNumber)
        assertNull(SipIdentity("unknown").phoneNumber)
    }
}

class PushCallLedgerTest {
    private val start = 1_000L
    private val alice = "sip:alice@example.com"

    private fun announcement(
        remoteUri: String?,
        video: Boolean = false,
        namedByServer: Boolean = true,
    ) = Announcement(UUID.randomUUID(), remoteUri, video, namedByServer)

    private fun after(seconds: Int) = start + seconds * 1000L

    private fun announced(
        announcement: Announcement,
        confirmed: Boolean,
    ) = Resolution.Announced(announcement, confirmed)

    @Test
    fun anInviteWithoutPushIsUnannounced() {
        assertEquals(Resolution.Unannounced, PushCallLedger(true).resolve(alice, now = start))
    }

    @Test
    fun onlyAPendingPushIsAnnounced() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        val declined = announcement("sip:bob@example.com")
        ledger.add(pushed, start)
        ledger.add(declined, start)
        ledger.decline(declined.uuid, after(10))
        assertTrue(ledger.isAnnounced(pushed.uuid))
        assertFalse(ledger.isAnnounced(declined.uuid))
        assertFalse(ledger.isAnnounced(UUID.randomUUID()))
        ledger.resolve(alice, now = start)
        assertFalse(ledger.isAnnounced(pushed.uuid))
    }

    @Test
    fun theOldestMatchingPushIsTaken() {
        val ledger = PushCallLedger(true)
        val first = announcement(alice)
        val second = announcement(alice)
        ledger.add(first, start)
        ledger.add(second, start)
        assertEquals(announced(first, true), ledger.resolve(alice, now = start))
        assertEquals(announced(second, true), ledger.resolve(alice, now = start))
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, now = start))
    }

    @Test
    fun anExactMatchWinsOverOlderPartialMatches() {
        val ledger = PushCallLedger(true)
        val anyCaller = announcement(null)
        val userOnly = announcement("alice")
        val exact = announcement(alice)
        ledger.add(anyCaller, start)
        ledger.add(userOnly, start)
        ledger.add(exact, start)
        assertEquals(announced(exact, true), ledger.resolve(alice, now = start))
        assertEquals(announced(userOnly, false), ledger.resolve(alice, now = start))
        assertEquals(announced(anyCaller, false), ledger.resolve(alice, now = start))
    }

    @Test
    fun aPushForAnotherCallerStaysPending() {
        val ledger = PushCallLedger(true)
        val forBob = announcement("sip:bob@example.com")
        ledger.add(forBob, start)
        assertEquals(Resolution.Unannounced, ledger.resolve("sip:mallory@example.com", now = start))
        assertEquals(Resolution.Unannounced, ledger.resolve("sip:bob@other.example.com", now = start))
        assertEquals(announced(forBob, true), ledger.resolve("sip:bob@example.com", now = start))
    }

    @Test
    fun aPushWithoutCallerIsNeverBoundWhenWildcardsAreOff() {
        val ledger = PushCallLedger(false)
        val anyCaller = announcement(null)
        ledger.add(anyCaller, start)
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, now = start))
        assertTrue(ledger.discard(anyCaller.uuid))
    }

    @Test
    fun aDiscardedPushStaysKnownSoItsUuidIsNotReused() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        ledger.discard(pushed.uuid)
        assertTrue(ledger.knows(pushed.uuid))
        assertFalse(ledger.isAnnounced(pushed.uuid))
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, pushed.uuid, start))
    }

    @Test
    fun anExpiredDeclineStaysKnown() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        ledger.decline(pushed.uuid, after(30))
        assertEquals(Resolution.Unannounced, ledger.resolve("sip:bob@example.com", now = after(31)))
        assertTrue(ledger.knows(pushed.uuid))
    }

    @Test
    fun onlyTheLatestSpentUuidsAreKept() {
        val ledger = PushCallLedger(true)
        val pushes = (0..PushCallLedger.SPENT_LIMIT).map { announcement(alice) }
        pushes.forEach {
            ledger.add(it, start)
            ledger.discard(it.uuid)
        }
        assertFalse(ledger.knows(pushes[0].uuid))
        assertTrue(ledger.knows(pushes[1].uuid))
        assertTrue(ledger.knows(pushes[PushCallLedger.SPENT_LIMIT].uuid))
        ledger.removeAll()
        assertFalse(ledger.knows(pushes[PushCallLedger.SPENT_LIMIT].uuid))
    }

    @Test
    fun aDiscardedOrRefusedPushIsNotBound() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        assertTrue(ledger.discard(pushed.uuid))
        assertFalse(ledger.discard(pushed.uuid))
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, now = start))
    }

    @Test
    fun theInviteOfADeclinedPushIsRejectedOnce() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        assertTrue(ledger.decline(pushed.uuid, after(30)))
        assertEquals(Resolution.Declined, ledger.resolve(alice, now = after(5)))
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, now = after(6)))
    }

    @Test
    fun aDeclinedPushIsForgottenAfterTheTimeout() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        ledger.decline(pushed.uuid, after(30))
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, now = after(30)))
    }

    @Test
    fun aDeclinedPushKeepsItsPlaceBeforeANewerPush() {
        val ledger = PushCallLedger(true)
        val declined = announcement(alice)
        val pending = announcement(alice)
        ledger.add(declined, start)
        ledger.decline(declined.uuid, after(30))
        ledger.add(pending, after(2))
        assertEquals(Resolution.Declined, ledger.resolve(alice, now = after(3)))
        assertEquals(announced(pending, true), ledger.resolve(alice, now = after(4)))
    }

    @Test
    fun aDeclinedPushIsNeitherExpiredNorDeclinedAgain() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        ledger.decline(pushed.uuid, after(30))
        assertFalse(ledger.discard(pushed.uuid))
        assertFalse(ledger.decline(pushed.uuid, after(60)))
        assertFalse(ledger.decline(UUID.randomUUID(), after(30)))
    }

    @Test
    fun anInviteWithAUuidTakesThePushWithThatUuid() {
        val ledger = PushCallLedger(true)
        val older = announcement(alice)
        val pushed = announcement("sip:bob@example.com")
        ledger.add(older, start)
        ledger.add(pushed, start)
        assertEquals(announced(pushed, true), ledger.resolve(alice, pushed.uuid, start))
        assertTrue(ledger.isAnnounced(older.uuid))
        assertFalse(ledger.knows(pushed.uuid))
    }

    @Test
    fun anInviteWithAnUnknownUuidTakesNoPushThatNamedItsCall() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, UUID.randomUUID(), start))
        assertTrue(ledger.knows(pushed.uuid))
        assertEquals(announced(pushed, true), ledger.resolve(alice, now = start))
    }

    @Test
    fun anInviteWithAUuidTakesAPushThatNamedNoCall() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice, namedByServer = false)
        val named = announcement("sip:bob@example.com")
        ledger.add(named, start)
        ledger.add(pushed, start)
        assertEquals(Resolution.Unannounced, ledger.resolve("sip:bob@example.com", UUID.randomUUID(), start))
        assertEquals(announced(pushed, true), ledger.resolve(alice, UUID.randomUUID(), start))
        assertTrue(ledger.knows(named.uuid))
    }

    @Test
    fun aPushWithoutAUuidDuplicatesAnInviteThatCarriedOne() {
        val ledger = PushCallLedger(true)
        ledger.startedRinging(BaresipCallID(1), alice, UUID.randomUUID())
        assertTrue(ledger.duplicatesRingingCall(alice))
        assertFalse(ledger.duplicatesRingingCall(alice, namedByServer = true))
    }

    @Test
    fun theInviteOfADeclinedPushIsRejectedByItsUuid() {
        val ledger = PushCallLedger(true)
        val pushed = announcement(alice)
        ledger.add(pushed, start)
        ledger.decline(pushed.uuid, after(30))
        assertTrue(ledger.knows(pushed.uuid))
        assertEquals(Resolution.Declined, ledger.resolve("sip:bob@example.com", pushed.uuid, start))
        assertFalse(ledger.knows(pushed.uuid))
    }

    @Test
    fun aPushForACallThatAlreadyRingsIsADuplicate() {
        val ledger = PushCallLedger(true)
        val call = BaresipCallID(1)
        assertFalse(ledger.duplicatesRingingCall(alice))
        ledger.startedRinging(call, "<sip:alice@example.com;transport=tls>")
        assertTrue(ledger.duplicatesRingingCall(alice))
        assertTrue(ledger.duplicatesRingingCall("alice"))
        assertTrue(ledger.duplicatesRingingCall(null))
        assertFalse(ledger.duplicatesRingingCall("sip:bob@example.com"))
        assertFalse(ledger.duplicatesRingingCall("sip:alice@other.example.com"))
        ledger.stoppedRinging(call)
        assertFalse(ledger.duplicatesRingingCall(alice))
    }

    @Test
    fun aPushWithoutCallerDuplicatesNothingWhenWildcardsAreOff() {
        val ledger = PushCallLedger(false)
        ledger.startedRinging(BaresipCallID(1), alice)
        assertFalse(ledger.duplicatesRingingCall(null))
        assertTrue(ledger.duplicatesRingingCall(alice))
    }

    @Test
    fun removeAllForgetsPushesAndRingingCalls() {
        val ledger = PushCallLedger(true)
        ledger.add(announcement(alice), start)
        ledger.startedRinging(BaresipCallID(1), alice)
        ledger.removeAll()
        assertFalse(ledger.duplicatesRingingCall(alice))
        assertEquals(Resolution.Unannounced, ledger.resolve(alice, now = start))
    }

    @Test
    fun theCameraIsSentOnlyWhenPushInviteAndSettingAgree() {
        assertTrue(PushCallLedger.sendsCamera(pushHadVideo = true, inviteHasVideo = true, sendsCameraOnAnswer = true))
        assertFalse(PushCallLedger.sendsCamera(pushHadVideo = false, inviteHasVideo = true, sendsCameraOnAnswer = true))
        assertFalse(PushCallLedger.sendsCamera(pushHadVideo = true, inviteHasVideo = false, sendsCameraOnAnswer = true))
        assertFalse(PushCallLedger.sendsCamera(pushHadVideo = true, inviteHasVideo = true, sendsCameraOnAnswer = false))
    }

    @Test
    fun theCallerNameComesFromTheInviteWhenItHasOne() {
        assertEquals("Bob", PushCallLedger.callerName("sip:bob@example.com", "Bob", true))
        assertEquals("sip:bob@example.com", PushCallLedger.callerName("sip:bob@example.com", "", true))
        assertNull(PushCallLedger.callerName("sip:bob@example.com", "", false))
    }
}
