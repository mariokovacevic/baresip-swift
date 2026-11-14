import XCTest
@testable import BaresipKit
@testable import BaresipKitSwiftUI

/// Records the actions a phone sends to its call controller.
private final class RecordingController: BaresipCallController, @unchecked Sendable {
    // SAFETY: every stored property is read and written only while holding `lock`.
    private let lock = NSLock()
    private var controlled: Set<BaresipCallID>
    private var recorded: [String] = []
    private var observers: [@Sendable (BaresipCallID, Bool) -> Void] = []
    private let placedCall: BaresipCallID

    init(controls calls: Set<BaresipCallID>, placing placedCall: BaresipCallID = BaresipCallID(rawValue: 99)) {
        controlled = calls
        self.placedCall = placedCall
    }

    var actions: [String] {
        lock.withLock { recorded }
    }

    func controls(_ call: BaresipCallID) -> Bool {
        lock.withLock { controlled.contains(call) }
    }

    func placeCall(to destination: String, video: Bool) async throws -> BaresipCallID {
        record("place \(destination) video=\(video)")
        return placedCall
    }

    func answer(_ call: BaresipCallID, video: Bool) async throws {
        record("answer \(call.rawValue) video=\(video)")
    }

    func end(_ call: BaresipCallID) async throws {
        record("end \(call.rawValue)")
    }

    func setOnHold(_ onHold: Bool, call: BaresipCallID) async throws {
        record("hold \(call.rawValue) \(onHold)")
    }

    func setMuted(_ muted: Bool, call: BaresipCallID) async throws {
        record("mute \(call.rawValue) \(muted)")
        // Like CallKit, report the change once it was carried out.
        reportMuted(muted, call: call)
    }

    func addMuteObserver(_ observer: @escaping @Sendable (BaresipCallID, Bool) -> Void) {
        lock.withLock { observers.append(observer) }
    }

    func reportMuted(_ muted: Bool, call: BaresipCallID) {
        for observer in lock.withLock({ observers }) {
            observer(call, muted)
        }
    }

    private func record(_ action: String) {
        lock.withLock { recorded.append(action) }
    }
}

@MainActor
final class BaresipPhoneControlTests: XCTestCase {
    private func makePhone(controller: BaresipCallController? = nil) throws -> BaresipPhone {
        var configuration = BaresipConfiguration(instanceUUID: UUID())
        configuration.modules = ["g711"]
        configuration.audio.sourceModule = "ausine"
        configuration.audio.playerModule = "aufile"
        configuration.audio.playerDevice = "/dev/null"
        configuration.extraConfiguration = "sip_listen\t\t0.0.0.0:0"
        return try BaresipPhone(engine: BaresipEngine(configuration: configuration), callController: controller)
    }

    private func waitUntil(_ condition: @autoclosure () -> Bool, file: StaticString = #filePath,
                           line: UInt = #line) async {
        for _ in 0 ..< 100 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    func testTheFirstCallBecomesActive() throws {
        let phone = try makePhone()
        let first = BaresipCallID(rawValue: 1)
        let second = BaresipCallID(rawValue: 2)

        phone.apply(.call(first, .streamsRunning, nil))
        phone.apply(.call(second, .incoming, nil))

        XCTAssertEqual(phone.activeCall?.id, first)
    }

    func testWhenTheActiveCallEndsTheHeldCallIsResumed() async throws {
        let first = BaresipCallID(rawValue: 1)
        let second = BaresipCallID(rawValue: 2)
        let controller = RecordingController(controls: [first, second])
        let phone = try makePhone(controller: controller)

        phone.apply(.call(first, .paused, nil))
        phone.apply(.call(second, .incoming, nil))
        try await XCTUnwrap(phone.call(second)).answer()
        XCTAssertEqual(phone.activeCall?.id, second)
        phone.apply(.call(second, .released, nil))

        XCTAssertEqual(phone.activeCall?.id, first)
        await waitUntil(controller.actions == ["answer 2 video=false", "hold 1 false"])
    }

    func testAHeldCallStaysHeldWhenResumingIsOff() async throws {
        let first = BaresipCallID(rawValue: 1)
        let second = BaresipCallID(rawValue: 2)
        let controller = RecordingController(controls: [first, second])
        let phone = try makePhone(controller: controller)
        phone.resumesHeldCallWhenActiveCallEnds = false

        phone.apply(.call(first, .streamsRunning, nil))
        phone.apply(.call(second, .paused, nil))
        phone.apply(.call(first, .released, nil))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(phone.activeCall?.id, second)
        XCTAssertEqual(controller.actions, [])
    }

    func testActionsOfAControlledCallGoThroughTheController() async throws {
        let id = BaresipCallID(rawValue: 5)
        let controller = RecordingController(controls: [id])
        let phone = try makePhone(controller: controller)
        phone.apply(.call(id, .incoming, nil))
        let call = try XCTUnwrap(phone.call(id))

        try await call.answer(video: true)
        try await call.setMuted(true)
        try await call.setOnHold(true)
        try await call.hangUp()

        XCTAssertEqual(controller.actions, ["answer 5 video=true", "mute 5 true", "hold 5 true", "end 5"])
        await waitUntil(call.isMuted)
        XCTAssertTrue(call.isSendingVideo)
        XCTAssertEqual(phone.activeCall?.id, id)
    }

    func testActionsOfAnUncontrolledCallGoToTheEngine() async throws {
        let id = BaresipCallID(rawValue: 5)
        let controller = RecordingController(controls: [])
        let phone = try makePhone(controller: controller)
        phone.apply(.call(id, .incoming, nil))
        let call = try XCTUnwrap(phone.call(id))

        // The engine is not running and does not know the call, so it refuses.
        do {
            try await call.hangUp()
            XCTFail("the engine accepted a hang-up for an unknown call")
        } catch {}

        XCTAssertEqual(controller.actions, [])
    }

    func testAnswerWithoutAudioSkipsTheController() async throws {
        let id = BaresipCallID(rawValue: 5)
        let controller = RecordingController(controls: [id])
        let phone = try makePhone(controller: controller)
        phone.apply(.call(id, .incoming, nil))

        try? await phone.call(id)?.answer(audio: false)

        XCTAssertEqual(controller.actions, [])
    }

    func testCallsArePlacedThroughTheController() async throws {
        let placed = BaresipCallID(rawValue: 99)
        let controller = RecordingController(controls: [placed], placing: placed)
        let phone = try makePhone(controller: controller)

        let call = try await phone.makeCall(to: "sip:door@example.com", video: true)

        XCTAssertEqual(controller.actions, ["place sip:door@example.com video=true"])
        XCTAssertEqual(call.id, placed)
        XCTAssertTrue(call.isOutgoing)
        XCTAssertTrue(call.isSendingVideo)
        XCTAssertEqual(phone.activeCall?.id, placed)
    }

    func testMutingFromTheSystemScreenUpdatesTheCall() async throws {
        let id = BaresipCallID(rawValue: 3)
        let controller = RecordingController(controls: [id])
        let phone = try makePhone(controller: controller)
        phone.apply(.call(id, .streamsRunning, nil))

        controller.reportMuted(true, call: id)

        await waitUntil(phone.call(id)?.isMuted == true)
    }

    func testReceivedDTMFIsCollected() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 4)
        phone.apply(.call(id, .streamsRunning, nil))

        phone.apply(.dtmf(id, BaresipDTMFEvent(digit: "1", isEnd: false, viaSIPInfo: false)))
        phone.apply(.dtmf(id, BaresipDTMFEvent(digit: "1", isEnd: true, viaSIPInfo: false)))
        phone.apply(.dtmf(id, BaresipDTMFEvent(digit: "#", isEnd: false, viaSIPInfo: true)))

        XCTAssertEqual(phone.call(id)?.receivedDTMF, "1#")
    }

    func testADoorCodeIsConfirmedByTheExpectedDigit() async throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 4)
        phone.apply(.call(id, .streamsRunning, nil))
        let call = try XCTUnwrap(phone.call(id))
        var sent: [String] = []

        let reply = try await call.sendDTMF("1234", expectingReply: "#", timeout: .seconds(5)) { digits in
            sent.append(digits)
            // The station answers at once, before the sender returns.
            phone.apply(.dtmf(id, BaresipDTMFEvent(digit: "#", isEnd: false, viaSIPInfo: false)))
        }

        XCTAssertEqual(sent, ["1234"])
        XCTAssertEqual(reply, .confirmed)
    }

    func testAnotherDigitIsReported() async throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 4)
        phone.apply(.call(id, .streamsRunning, nil))
        let call = try XCTUnwrap(phone.call(id))

        let reply = try await call.sendDTMF("1234", expectingReply: "#", timeout: .seconds(5)) { _ in
            phone.apply(.dtmf(id, BaresipDTMFEvent(digit: "9", isEnd: false, viaSIPInfo: true)))
        }

        XCTAssertEqual(reply, .other("9"))
    }

    func testNoReplyEndsAfterTheTimeout() async throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 4)
        phone.apply(.call(id, .streamsRunning, nil))
        let call = try XCTUnwrap(phone.call(id))
        let start = ContinuousClock.now

        let reply = try await call.sendDTMF("1234", expectingReply: "#", timeout: .milliseconds(100)) { _ in }

        XCTAssertEqual(reply, .noReply)
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(2))
    }

    func testAFailedSendThrowsWithoutWaiting() async throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 4)
        phone.apply(.call(id, .streamsRunning, nil))
        let call = try XCTUnwrap(phone.call(id))

        do {
            _ = try await call.sendDTMF("1234", expectingReply: "#", timeout: .seconds(30)) { _ in
                throw BaresipError(code: .network, message: "gone")
            }
            XCTFail("a failed send returned a reply")
        } catch {}
    }

    func testTheConnectionTimeIsKeptFromTheFirstConnect() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 6)

        phone.apply(.call(id, .outgoingRinging, nil))
        XCTAssertNil(phone.call(id)?.connectedAt)

        phone.apply(.call(id, .streamsRunning, nil))
        let connected = try XCTUnwrap(phone.call(id)?.connectedAt)
        phone.apply(.call(id, .paused, nil))
        phone.apply(.call(id, .streamsRunning, nil))

        XCTAssertEqual(phone.call(id)?.connectedAt, connected)
    }

    func testUserPartOfSIPURIs() {
        XCTAssertEqual(BaresipPhoneCall.userPart(of: "sip:alice@example.com;transport=tls"), "alice")
        XCTAssertEqual(BaresipPhoneCall.userPart(of: "sips:1002@pbx"), "1002")
        XCTAssertEqual(BaresipPhoneCall.userPart(of: "tel:+385123"), "+385123")
        XCTAssertEqual(BaresipPhoneCall.userPart(of: "sip:@"), "sip:@")
    }
}

@MainActor
final class BaresipPhoneAnsweredElsewhereTests: XCTestCase {
    func testACallAnsweredOnTheSystemScreenBecomesActive() throws {
        var configuration = BaresipConfiguration(instanceUUID: UUID())
        configuration.modules = ["g711"]
        configuration.audio.sourceModule = "ausine"
        configuration.audio.playerModule = "aufile"
        configuration.audio.playerDevice = "/dev/null"
        let phone = try BaresipPhone(engine: BaresipEngine(configuration: configuration))
        let first = BaresipCallID(rawValue: 1)
        let second = BaresipCallID(rawValue: 2)

        phone.apply(.call(first, .streamsRunning, nil))
        phone.apply(.call(second, .incoming, nil))
        XCTAssertEqual(phone.activeCall?.id, first)

        phone.apply(.call(second, .connected, nil))
        XCTAssertEqual(phone.activeCall?.id, second)
    }
}
