import XCTest
import BaresipKit
@testable import BaresipKitSystemCall

final class SystemCallBookTests: XCTestCase {
    private let now = ContinuousClock.now
    private let alice = "sip:alice@example.com"
    private let call = BaresipCallID(rawValue: 7)

    func testAPushIsAnnouncedOnceAndItsRepeatIsADuplicateWithAUUIDOfItsOwn() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let pushed = UUID()

        let first = book.announcePush(uuid: pushed, remoteURI: alice, hasVideo: false, now: now)
        let repeated = book.announcePush(uuid: pushed, remoteURI: alice, hasVideo: false, now: now)

        XCTAssertEqual(first, SystemCallBook.PushReport(reported: pushed, isDuplicate: false))
        XCTAssertTrue(repeated.isDuplicate)
        XCTAssertNotEqual(repeated.reported, pushed)
    }

    func testAPushWithoutUUIDGetsOne() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)

        let report = book.announcePush(uuid: nil, remoteURI: alice, hasVideo: false, now: now)

        XCTAssertFalse(report.isDuplicate)
        XCTAssertEqual(book.answerTarget(report.reported), .awaitsInvite)
    }

    func testAPushForACallThatAlreadyRingsIsADuplicateUnderItsOwnUUID() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        _ = book.bindUnannounced(call, remoteURI: alice, announcedUUID: nil)
        let pushed = UUID()

        let report = book.announcePush(uuid: nil, remoteURI: alice, hasVideo: false, now: now)
        let named = book.announcePush(uuid: pushed, remoteURI: alice, hasVideo: false, now: now)

        XCTAssertTrue(report.isDuplicate)
        XCTAssertTrue(named.isDuplicate)
        XCTAssertEqual(named.reported, pushed)
    }

    func testTheInviteOfAPushIsBoundToThePushedUUIDAndAnEarlyAnswerIsTakenOnce() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let pushed = UUID()
        _ = book.announcePush(uuid: pushed, remoteURI: alice, hasVideo: true, now: now)
        XCTAssertEqual(book.answerTarget(pushed), .awaitsInvite)

        let resolution = book.resolveIncoming(call, remoteURI: alice, announcedUUID: pushed, now: now)

        guard case .announced(let announcement, let confirmed) = resolution else {
            return XCTFail("the INVITE was not bound to the push")
        }
        XCTAssertEqual(announcement.uuid, pushed)
        XCTAssertTrue(confirmed)
        XCTAssertEqual(book.uuid(for: call), pushed)
        XCTAssertEqual(book.call(for: pushed), call)
        XCTAssertTrue(book.takePendingAnswer(pushed))
        XCTAssertFalse(book.takePendingAnswer(pushed))
        XCTAssertEqual(book.answerTarget(pushed), .call(call))
    }

    func testAnUnannouncedInviteKeepsItsHeaderUUIDUnlessThatUUIDIsSpent() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let header = UUID()
        XCTAssertEqual(book.bindUnannounced(call, remoteURI: alice, announcedUUID: header), header)

        let expired = UUID()
        _ = book.announcePush(uuid: expired, remoteURI: "sip:bob@example.com", hasVideo: false, now: now)
        XCTAssertTrue(book.expirePush(expired))
        XCTAssertFalse(book.expirePush(expired))
        let late = BaresipCallID(rawValue: 8)
        XCTAssertEqual(book.resolveIncoming(late, remoteURI: "sip:bob@example.com", announcedUUID: expired, now: now),
                       .unannounced)
        let uuid = book.bindUnannounced(late, remoteURI: "sip:bob@example.com", announcedUUID: expired)
        XCTAssertNotEqual(uuid, expired)
        XCTAssertEqual(book.uuid(for: late), uuid)
    }

    func testARefusedPushGivesBackTheCallItWasBoundTo() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let pushed = UUID()
        _ = book.announcePush(uuid: pushed, remoteURI: alice, hasVideo: false, now: now)

        XCTAssertNil(book.forgetRefusedPush(pushed))
        XCTAssertEqual(book.answerTarget(pushed), .unknown)
    }

    func testADeclinedPushRejectsItsInvite() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let pushed = UUID()
        _ = book.announcePush(uuid: pushed, remoteURI: alice, hasVideo: false, now: now)
        XCTAssertEqual(book.answerTarget(pushed), .awaitsInvite)

        XCTAssertNil(book.end(pushed, declineUntil: now.advanced(by: .seconds(30))))
        XCTAssertFalse(book.takePendingAnswer(pushed))
        XCTAssertEqual(book.resolveIncoming(call, remoteURI: alice, announcedUUID: pushed, now: now), .declined)
        XCTAssertNil(book.uuid(for: call))
    }

    func testAPlacedCallIsBoundAndOutgoing() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = UUID()
        book.willStart(uuid, destination: alice)

        XCTAssertEqual(book.takeStartDestination(uuid), alice)
        XCTAssertNil(book.takeStartDestination(uuid))
        XCTAssertTrue(book.placed(call, uuid: uuid))
        XCTAssertEqual(book.stateChanged(call, to: .outgoingRinging),
                       SystemCallBook.StateChange(uuid: uuid, isOutgoing: true))
        XCTAssertEqual(book.startTimedOut(uuid), call)
        XCTAssertTrue(book.abandonedStarts.isEmpty)
    }

    func testAStartThatTimedOutBeforeTheCallWasPlacedIsAbandonedOnce() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = UUID()
        book.willStart(uuid, destination: alice)

        XCTAssertNil(book.startTimedOut(uuid))
        XCTAssertNil(book.takeStartDestination(uuid))
        XCTAssertEqual(book.abandonedStarts, [uuid])
        XCTAssertFalse(book.placed(call, uuid: uuid))
        XCTAssertNil(book.uuid(for: call))
        XCTAssertTrue(book.abandonedStarts.isEmpty)
    }

    func testAFailedStartForgetsItsAbandonment() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = UUID()
        _ = book.startTimedOut(uuid)

        book.startFailed(uuid)

        XCTAssertTrue(book.abandonedStarts.isEmpty)
    }

    func testARequestedCameraIsTakenOnceAndCanBeCancelled() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = UUID()

        book.requestAnswer(uuid, sendsCamera: false)
        XCTAssertEqual(book.takeAnswerCamera(uuid), .requested(sendsCamera: false))
        XCTAssertEqual(book.takeAnswerCamera(uuid), .asConfigured)

        book.requestAnswer(uuid, sendsCamera: true)
        book.cancelAnswerRequest(uuid)
        XCTAssertEqual(book.takeAnswerCamera(uuid), .asConfigured)

        XCTAssertTrue(SystemCallBook.AnswerCamera.requested(sendsCamera: true).sendsCamera(otherwise: false))
        XCTAssertFalse(SystemCallBook.AnswerCamera.requested(sendsCamera: false).sendsCamera(otherwise: true))
        XCTAssertTrue(SystemCallBook.AnswerCamera.asConfigured.sendsCamera(otherwise: true))
    }

    func testARingingCallStopsRingingOnceItLeavesTheRingingStates() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = book.bindUnannounced(call, remoteURI: alice, announcedUUID: nil)

        XCTAssertEqual(book.stateChanged(call, to: .earlyMedia),
                       SystemCallBook.StateChange(uuid: uuid, isOutgoing: false))
        XCTAssertTrue(book.announcePush(uuid: nil, remoteURI: alice, hasVideo: false, now: now).isDuplicate)
        _ = book.stateChanged(call, to: .connected)
        XCTAssertFalse(book.announcePush(uuid: nil, remoteURI: alice, hasVideo: false, now: now).isDuplicate)
        XCTAssertNil(book.stateChanged(BaresipCallID(rawValue: 99), to: .connected))
    }

    func testUnbindAndResetForgetCalls() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = book.bindUnannounced(call, remoteURI: alice, announcedUUID: nil)
        let other = BaresipCallID(rawValue: 8)
        let otherUUID = UUID()
        book.willStart(otherUUID, destination: alice)
        XCTAssertTrue(book.placed(other, uuid: otherUUID))

        XCTAssertEqual(book.unbind(call), uuid)
        XCTAssertNil(book.unbind(call))
        XCTAssertNil(book.call(for: uuid))
        XCTAssertEqual(book.reset(), [other])
        XCTAssertNil(book.uuid(for: other))
        XCTAssertEqual(book.answerTarget(otherUUID), .unknown)
    }

    func testAReplacedCallIsParkedUntilTheIncomingCallThatReplacesItTakesItsUUID() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = book.bindUnannounced(call, remoteURI: alice, announcedUUID: nil)
        let replacing = BaresipCallID(rawValue: 8)

        XCTAssertEqual(book.callReplaced(call), .parked(uuid))
        XCTAssertNil(book.uuid(for: call))
        XCTAssertNil(book.unbind(call))
        XCTAssertEqual(book.link(replacing, replacing: call), .adopted(uuid))
        XCTAssertEqual(book.uuid(for: replacing), uuid)
        XCTAssertEqual(book.call(for: uuid), replacing)
        XCTAssertNil(book.expireParked(call))
    }

    func testATransferredCallHandsItsUUIDToTheCallThatFollowsIt() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = UUID()
        let follower = BaresipCallID(rawValue: 8)
        book.willStart(uuid, destination: alice)
        XCTAssertTrue(book.placed(call, uuid: uuid))

        XCTAssertTrue(book.needsReplacementCheck(follower))
        XCTAssertEqual(book.link(follower, replacing: call), .pending)
        XCTAssertFalse(book.needsReplacementCheck(follower))
        XCTAssertEqual(book.uuid(for: call), uuid)
        XCTAssertEqual(book.callReplaced(call), .handedOver(uuid, to: follower))
        XCTAssertEqual(book.uuid(for: follower), uuid)
        XCTAssertEqual(book.stateChanged(follower, to: .connected),
                       SystemCallBook.StateChange(uuid: uuid, isOutgoing: false))
    }

    func testAFailedTransferLeavesTheCallWhereItWas() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = book.bindUnannounced(call, remoteURI: alice, announcedUUID: nil)
        let follower = BaresipCallID(rawValue: 8)
        XCTAssertEqual(book.link(follower, replacing: call), .pending)

        XCTAssertNil(book.unbind(follower))

        XCTAssertTrue(book.needsReplacementCheck(follower))
        XCTAssertEqual(book.uuid(for: call), uuid)
        XCTAssertEqual(book.callReplaced(call), .parked(uuid))
    }

    func testCallsTheBookDoesNotKnowAreNeitherHandedOverNorLinked() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)

        XCTAssertEqual(book.callReplaced(call), .unknown)
        XCTAssertEqual(book.link(BaresipCallID(rawValue: 8), replacing: call), .unrelated)
    }

    func testAParkedCallThatNoCallReplacesExpiresOnce() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        let uuid = book.bindUnannounced(call, remoteURI: alice, announcedUUID: nil)
        _ = book.callReplaced(call)

        XCTAssertEqual(book.expireParked(call), uuid)
        XCTAssertNil(book.expireParked(call))
        XCTAssertEqual(book.link(BaresipCallID(rawValue: 8), replacing: call), .unrelated)
    }

    func testResetForgetsParkedAndLinkedCalls() {
        var book = SystemCallBook(matchesPushWithoutCaller: true)
        _ = book.bindUnannounced(call, remoteURI: alice, announcedUUID: nil)
        let other = BaresipCallID(rawValue: 8)
        _ = book.bindUnannounced(other, remoteURI: alice, announcedUUID: nil)
        XCTAssertEqual(book.link(BaresipCallID(rawValue: 9), replacing: other), .pending)
        _ = book.callReplaced(call)

        _ = book.reset()

        XCTAssertNil(book.expireParked(call))
        XCTAssertTrue(book.needsReplacementCheck(BaresipCallID(rawValue: 9)))
    }
}
