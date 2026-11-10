import XCTest
import BaresipKit
@testable import BaresipKitSwiftUI

@MainActor
final class BaresipPhoneTests: XCTestCase {
    private func makePhone() throws -> BaresipPhone {
        var configuration = BaresipConfiguration()
        configuration.modules = ["g711"]
        configuration.audio.sourceModule = "ausine"
        configuration.audio.playerModule = "aufile"
        configuration.audio.playerDevice = "/dev/null"
        configuration.extraConfiguration = "sip_listen\t\t0.0.0.0:0"
        return try BaresipPhone(engine: BaresipEngine(configuration: configuration))
    }

    func testRegistrationEventsUpdateTheAccountState() throws {
        let phone = try makePhone()
        let account = BaresipAccountID(rawValue: 7)

        phone.apply(.registration(account, .registering, expires: nil, error: nil))
        XCTAssertEqual(phone.registrations[account], .registering)

        phone.apply(.registration(account, .registered, expires: .seconds(600), error: nil))
        XCTAssertEqual(phone.registrations[account], .registered)
    }

    func testSynchronizeKeepsRegistrationsOfAStoppedEngine() async throws {
        let phone = try makePhone()
        let account = BaresipAccountID(rawValue: 7)

        phone.apply(.registration(account, .registered, expires: .seconds(600), error: nil))
        await phone.synchronize()

        XCTAssertEqual(phone.registrations[account], .registered)
    }

    func testSynchronizeReadsTheAccountsOfARunningEngine() async throws {
        let phone = try makePhone()
        try await phone.engine.start()
        let account = try await phone.engine.addAccount(
            BaresipAccountConfiguration(aor: "sip:alice@example.invalid", transport: .udp)
        )

        await phone.synchronize()
        let listed = await phone.engine.accounts()
        await phone.engine.stop()

        XCTAssertEqual(phone.registrations[account], BaresipRegistrationState.none)
        XCTAssertEqual(listed, [account: BaresipRegistrationState.none])
    }

    func testCallEventsTrackTheCallUntilReleased() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 42)

        phone.apply(.call(id, .outgoingRinging, nil))
        XCTAssertEqual(phone.calls.map(\.id), [id])
        XCTAssertEqual(phone.call(id)?.state, .outgoingRinging)

        phone.apply(.call(id, .paused, nil))
        XCTAssertEqual(phone.call(id)?.isOnHold, true)

        phone.apply(.call(id, .streamsRunning, nil))
        XCTAssertEqual(phone.call(id)?.isConnected, true)
        XCTAssertEqual(phone.call(id)?.isOnHold, false)

        phone.apply(.call(id, .released, nil))
        XCTAssertTrue(phone.calls.isEmpty)
    }

    func testAFailedCallKeepsItsError() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 9)
        let error = BaresipError(code: .network, message: "unreachable")

        phone.apply(.call(id, .failed, error))
        XCTAssertEqual(phone.call(id)?.state, .failed)
        XCTAssertEqual(phone.call(id)?.error?.code, .network)
    }

    func testEachCallIsTrackedOnce() throws {
        let phone = try makePhone()
        let first = BaresipCallID(rawValue: 1)
        let second = BaresipCallID(rawValue: 2)

        phone.apply(.call(first, .incoming, nil))
        phone.apply(.call(second, .outgoingInit, nil))
        phone.apply(.call(first, .earlyMedia, nil))

        XCTAssertEqual(phone.calls.map(\.id), [first, second])
        XCTAssertEqual(phone.incomingCall?.id, first)
    }

    func testAReleasedCallIsNotTrackedAgain() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 5)

        phone.apply(.call(id, .connected, nil))
        phone.apply(.call(id, .released, nil))
        phone.apply(.call(id, .ended, nil))

        XCTAssertTrue(phone.calls.isEmpty)
    }

    func testEarlyMediaOfUnknownDirectionIsNotIncoming() throws {
        let phone = try makePhone()

        phone.apply(.call(BaresipCallID(rawValue: 3), .earlyMedia, nil))

        XCTAssertNil(phone.incomingCall)
        XCTAssertEqual(phone.calls.first?.isDirectionKnown, false)
    }

    func testAnOutgoingCallInEarlyMediaIsNotIncoming() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 4)

        phone.apply(.call(id, .outgoingRinging, nil))
        phone.apply(.call(id, .earlyMedia, nil))

        XCTAssertNil(phone.incomingCall)
        XCTAssertEqual(phone.call(id)?.isOutgoing, true)
    }

    func testHoldStates() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 6)

        phone.apply(.call(id, .resuming, nil))
        XCTAssertEqual(phone.call(id)?.isOnHold, true)

        phone.apply(.call(id, .pausedByRemote, nil))
        XCTAssertEqual(phone.call(id)?.isOnHold, false)
        XCTAssertEqual(phone.call(id)?.isHeldByRemote, true)
    }

    func testASnapshotUpdatesACallThatIsAlreadyTracked() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 10)

        phone.apply(.call(id, .incoming, nil))
        XCTAssertEqual(phone.incomingCall?.id, id)

        let refreshed = phone.applySnapshot(of: id, state: .connected)
        XCTAssertTrue(refreshed === phone.call(id))
        XCTAssertEqual(phone.call(id)?.state, .connected)
        XCTAssertNil(phone.incomingCall)
        XCTAssertEqual(phone.calls.map(\.id), [id])
    }

    func testASnapshotAddsACallThatIsNotTrackedYet() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 11)

        XCTAssertNotNil(phone.applySnapshot(of: id, state: .streamsRunning))
        XCTAssertEqual(phone.call(id)?.isConnected, true)
    }

    func testASnapshotDoesNotBringBackAReleasedCall() throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 12)

        phone.apply(.call(id, .connected, nil))
        phone.apply(.call(id, .released, nil))

        XCTAssertNil(phone.applySnapshot(of: id, state: .connected))
        XCTAssertTrue(phone.calls.isEmpty)
    }

    func testSynchronizeRemovesCallsTheEngineNoLongerHas() async throws {
        let phone = try makePhone()
        let id = BaresipCallID(rawValue: 8)

        phone.apply(.call(id, .streamsRunning, nil))
        await phone.synchronize()
        XCTAssertTrue(phone.calls.isEmpty)

        phone.apply(.call(id, .ended, nil))
        XCTAssertTrue(phone.calls.isEmpty)
    }
}
