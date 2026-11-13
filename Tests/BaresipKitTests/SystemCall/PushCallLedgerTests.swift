import XCTest
import BaresipKit
@testable import BaresipKitSystemCall

final class PushCallLedgerTests: XCTestCase {
    private typealias Announcement = PushCallLedger.Announcement

    private let start = ContinuousClock.now
    private let alice = "sip:alice@example.com"

    private func announcement(_ remoteURI: String?, video: Bool = false) -> Announcement {
        Announcement(uuid: UUID(), remoteURI: remoteURI, hasVideo: video)
    }

    private func after(_ duration: Duration) -> ContinuousClock.Instant {
        start.advanced(by: duration)
    }

    func testAnInviteWithoutPushIsUnannounced() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)

        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .unannounced)
    }

    func testOnlyAPendingPushIsAnnounced() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        let declined = announcement("sip:bob@example.com")
        ledger.add(pushed, now: start)
        ledger.add(declined, now: start)
        ledger.decline(declined.uuid, until: after(.seconds(10)))

        XCTAssertTrue(ledger.isAnnounced(pushed.uuid))
        XCTAssertFalse(ledger.isAnnounced(declined.uuid))
        XCTAssertFalse(ledger.isAnnounced(UUID()))

        _ = ledger.resolve(invite: alice, now: start)
        XCTAssertFalse(ledger.isAnnounced(pushed.uuid))
    }

    func testTheOldestMatchingPushIsTaken() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let first = announcement(alice)
        let second = announcement(alice)
        ledger.add(first, now: start)
        ledger.add(second, now: start)

        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .announced(first, callerConfirmed: true))
        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .announced(second, callerConfirmed: true))
        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .unannounced)
    }

    func testAnExactMatchWinsOverOlderPartialMatches() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let anyCaller = announcement(nil)
        let userOnly = announcement("alice")
        let exact = announcement(alice)
        ledger.add(anyCaller, now: start)
        ledger.add(userOnly, now: start)
        ledger.add(exact, now: start)

        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .announced(exact, callerConfirmed: true))
        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .announced(userOnly, callerConfirmed: false))
        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .announced(anyCaller, callerConfirmed: false))
    }

    func testAPushForAnotherCallerStaysPending() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let forBob = announcement("sip:bob@example.com")
        ledger.add(forBob, now: start)

        XCTAssertEqual(ledger.resolve(invite: "sip:mallory@example.com", now: start), .unannounced)
        XCTAssertEqual(ledger.resolve(invite: "sip:bob@other.example.com", now: start), .unannounced)
        XCTAssertEqual(ledger.resolve(invite: "sip:bob@example.com", now: start),
                       .announced(forBob, callerConfirmed: true))
    }

    func testAPushWithoutCallerIsNeverBoundWhenWildcardsAreOff() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: false)
        let anyCaller = announcement(nil)
        ledger.add(anyCaller, now: start)

        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .unannounced)
        XCTAssertTrue(ledger.discard(anyCaller.uuid))
    }

    func testADiscardedPushIsNotBound() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)

        XCTAssertTrue(ledger.discard(pushed.uuid))
        XCTAssertFalse(ledger.discard(pushed.uuid))
        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .unannounced)
    }

    func testADiscardedPushStaysKnownSoItsUUIDIsNotReused() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)
        ledger.discard(pushed.uuid)

        XCTAssertTrue(ledger.knows(pushed.uuid))
        XCTAssertFalse(ledger.isAnnounced(pushed.uuid))
        XCTAssertEqual(ledger.resolve(invite: alice, uuid: pushed.uuid, now: start), .unannounced)
    }

    func testAnExpiredDeclineStaysKnown() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)
        ledger.decline(pushed.uuid, until: after(.seconds(30)))

        XCTAssertEqual(ledger.resolve(invite: "sip:bob@example.com", now: after(.seconds(31))), .unannounced)
        XCTAssertTrue(ledger.knows(pushed.uuid))
    }

    func testOnlyTheLatestSpentUUIDsAreKept() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushes = (0 ... PushCallLedger.spentLimit).map { _ in announcement(alice) }
        for pushed in pushes {
            ledger.add(pushed, now: start)
            ledger.discard(pushed.uuid)
        }

        XCTAssertFalse(ledger.knows(pushes[0].uuid))
        XCTAssertTrue(ledger.knows(pushes[1].uuid))
        XCTAssertTrue(ledger.knows(pushes[PushCallLedger.spentLimit].uuid))
        ledger.removeAll()
        XCTAssertFalse(ledger.knows(pushes[PushCallLedger.spentLimit].uuid))
    }

    func testAPushCallKitRefusedDoesNotCaptureALaterInvite() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let refused = announcement(nil)
        ledger.add(refused, now: start)
        ledger.discard(refused.uuid)

        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .unannounced)
    }

    func testTheInviteOfADeclinedPushIsRejectedOnce() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)

        XCTAssertTrue(ledger.decline(pushed.uuid, until: after(.seconds(30))))
        XCTAssertEqual(ledger.resolve(invite: alice, now: after(.seconds(5))), .declined)
        XCTAssertEqual(ledger.resolve(invite: alice, now: after(.seconds(6))), .unannounced)
    }

    func testADeclinedPushIsForgottenAfterTheTimeout() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)
        ledger.decline(pushed.uuid, until: after(.seconds(30)))

        XCTAssertEqual(ledger.resolve(invite: alice, now: after(.seconds(30))), .unannounced)
    }

    func testADeclinedPushKeepsItsPlaceBeforeANewerPush() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let declined = announcement(alice)
        let pending = announcement(alice)
        ledger.add(declined, now: start)
        ledger.decline(declined.uuid, until: after(.seconds(30)))
        ledger.add(pending, now: after(.seconds(2)))

        XCTAssertEqual(ledger.resolve(invite: alice, now: after(.seconds(3))), .declined)
        XCTAssertEqual(ledger.resolve(invite: alice, now: after(.seconds(4))),
                       .announced(pending, callerConfirmed: true))
    }

    func testADeclinedPushIsNeitherExpiredNorDeclinedAgain() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)
        ledger.decline(pushed.uuid, until: after(.seconds(30)))

        XCTAssertFalse(ledger.discard(pushed.uuid))
        XCTAssertFalse(ledger.decline(pushed.uuid, until: after(.seconds(60))))
        XCTAssertFalse(ledger.decline(UUID(), until: after(.seconds(30))))
    }

    func testAnInviteWithAUUIDTakesThePushWithThatUUID() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let older = announcement(alice)
        let pushed = announcement("sip:bob@example.com")
        ledger.add(older, now: start)
        ledger.add(pushed, now: start)

        XCTAssertEqual(ledger.resolve(invite: alice, uuid: pushed.uuid, now: start),
                       .announced(pushed, callerConfirmed: true))
        XCTAssertTrue(ledger.isAnnounced(older.uuid))
        XCTAssertFalse(ledger.knows(pushed.uuid))
    }

    func testAnInviteWithAnUnknownUUIDTakesNoPush() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)

        XCTAssertEqual(ledger.resolve(invite: alice, uuid: UUID(), now: start), .unannounced)
        XCTAssertTrue(ledger.knows(pushed.uuid))
        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .announced(pushed, callerConfirmed: true))
    }

    func testAnInviteWithAUUIDTakesAPushThatNamedNoCall() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        var pushed = announcement(alice)
        pushed.namedByServer = false
        let named = announcement("sip:bob@example.com")
        ledger.add(named, now: start)
        ledger.add(pushed, now: start)

        XCTAssertEqual(ledger.resolve(invite: "sip:bob@example.com", uuid: UUID(), now: start), .unannounced)
        XCTAssertEqual(ledger.resolve(invite: alice, uuid: UUID(), now: start),
                       .announced(pushed, callerConfirmed: true))
        XCTAssertTrue(ledger.knows(named.uuid))
    }

    func testAPushWithoutAUUIDDuplicatesAnInviteThatCarriedOne() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        ledger.startedRinging(BaresipCallID(rawValue: 1), remoteURI: alice, uuid: UUID())

        XCTAssertTrue(ledger.duplicatesRingingCall(remoteURI: alice))
        XCTAssertFalse(ledger.duplicatesRingingCall(remoteURI: alice, namedByServer: true))
    }

    func testTheInviteOfADeclinedPushIsRejectedByItsUUID() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let pushed = announcement(alice)
        ledger.add(pushed, now: start)
        ledger.decline(pushed.uuid, until: after(.seconds(30)))

        XCTAssertTrue(ledger.knows(pushed.uuid))
        XCTAssertEqual(ledger.resolve(invite: "sip:bob@example.com", uuid: pushed.uuid, now: start), .declined)
        XCTAssertFalse(ledger.knows(pushed.uuid))
    }

    func testAPushForACallThatAlreadyRingsIsADuplicate() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        let call = BaresipCallID(rawValue: 1)
        XCTAssertFalse(ledger.duplicatesRingingCall(remoteURI: alice))

        ledger.startedRinging(call, remoteURI: "<sip:alice@example.com;transport=tls>")
        XCTAssertTrue(ledger.duplicatesRingingCall(remoteURI: alice))
        XCTAssertTrue(ledger.duplicatesRingingCall(remoteURI: "alice"))
        XCTAssertTrue(ledger.duplicatesRingingCall(remoteURI: nil))
        XCTAssertFalse(ledger.duplicatesRingingCall(remoteURI: "sip:bob@example.com"))
        XCTAssertFalse(ledger.duplicatesRingingCall(remoteURI: "sip:alice@other.example.com"))

        ledger.stoppedRinging(call)
        XCTAssertFalse(ledger.duplicatesRingingCall(remoteURI: alice))
    }

    func testAPushWithoutCallerDuplicatesNothingWhenWildcardsAreOff() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: false)
        ledger.startedRinging(BaresipCallID(rawValue: 1), remoteURI: alice)

        XCTAssertFalse(ledger.duplicatesRingingCall(remoteURI: nil))
        XCTAssertTrue(ledger.duplicatesRingingCall(remoteURI: alice))
    }

    func testRemoveAllForgetsPushesAndRingingCalls() {
        var ledger = PushCallLedger(matchesPushWithoutCaller: true)
        ledger.add(announcement(alice), now: start)
        ledger.startedRinging(BaresipCallID(rawValue: 1), remoteURI: alice)
        ledger.removeAll()

        XCTAssertFalse(ledger.duplicatesRingingCall(remoteURI: alice))
        XCTAssertEqual(ledger.resolve(invite: alice, now: start), .unannounced)
    }

    func testTheCameraIsSentOnlyWhenPushInviteAndSettingAgree() {
        XCTAssertTrue(PushCallLedger.sendsCamera(pushHadVideo: true, inviteHasVideo: true, sendsCameraOnAnswer: true))
        XCTAssertFalse(PushCallLedger.sendsCamera(pushHadVideo: false, inviteHasVideo: true,
                                                  sendsCameraOnAnswer: true))
        XCTAssertFalse(PushCallLedger.sendsCamera(pushHadVideo: true, inviteHasVideo: false,
                                                  sendsCameraOnAnswer: true))
        XCTAssertFalse(PushCallLedger.sendsCamera(pushHadVideo: true, inviteHasVideo: true,
                                                  sendsCameraOnAnswer: false))
    }

    func testTheShownNameComesFromTheInvite() {
        XCTAssertEqual(PushCallLedger.callerName(inviteURI: "sip:bob@example.com", inviteDisplayName: "Bob",
                                                 replacingAnnouncedName: true), "Bob")
        XCTAssertEqual(PushCallLedger.callerName(inviteURI: "sip:bob@example.com", inviteDisplayName: "",
                                                 replacingAnnouncedName: true), "sip:bob@example.com")
        XCTAssertNil(PushCallLedger.callerName(inviteURI: "sip:bob@example.com", inviteDisplayName: "",
                                               replacingAnnouncedName: false))
    }
}
