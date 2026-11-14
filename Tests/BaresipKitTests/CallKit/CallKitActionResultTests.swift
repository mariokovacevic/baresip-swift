#if os(iOS)
    import CallKit
    import XCTest
    @testable import BaresipKit
    @testable import BaresipKitCallKit

    /// A caller of an action learns whether the adapter carried it out on the engine.
    final class CallKitActionResultTests: XCTestCase {
        private func makeAdapter(_ callKit: BaresipCallKitConfiguration = BaresipCallKitConfiguration()) throws
            -> BaresipCallKitAdapter {
            var configuration = BaresipConfiguration()
            configuration.modules = ["g711"]
            configuration.audio.sourceModule = "ausine"
            configuration.audio.playerModule = "aufile"
            configuration.audio.playerDevice = "/dev/null"
            return try BaresipCallKitAdapter(engine: BaresipEngine(configuration: configuration),
                                             configuration: callKit)
        }

        /// Waits like `requestAndWait(_:)` does, without asking the system, and lets `perform`
        /// finish the action.
        private func wait(for action: CXCallAction, on adapter: BaresipCallKitAdapter,
                          perform: () -> Void) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                adapter.lock.withLock { adapter.actionWaiters[action.uuid] = continuation }
                perform()
            }
        }

        /// CallKit drops a ringtone that is not in the main bundle, as here in the test runner, so
        /// only the rest of the provider's settings can be checked: a new ringtone keeps them.
        func testChangingTheRingtoneKeepsTheProviderSettings() throws {
            let adapter = try makeAdapter(BaresipCallKitConfiguration(supportsVideo: true, maximumCallsPerCallGroup: 2))

            adapter.setRingtoneSound("Bell.wav")
            adapter.setRingtoneSound(nil)

            XCTAssertNil(adapter.provider.configuration.ringtoneSound)
            XCTAssertTrue(adapter.provider.configuration.supportsVideo)
            XCTAssertEqual(adapter.provider.configuration.maximumCallsPerCallGroup, 2)
        }

        func testASuccessfulActionReturns() async throws {
            let adapter = try makeAdapter()
            let action = CXSetHeldCallAction(call: UUID(), onHold: true)

            try await wait(for: action, on: adapter) { adapter.complete(action, error: nil) }

            XCTAssertTrue(adapter.actionWaiters.isEmpty)
        }

        func testTheEngineErrorReachesTheCaller() async throws {
            let adapter = try makeAdapter()
            let action = CXSetMutedCallAction(call: UUID(), muted: true)
            let failure = BaresipError(code: .invalidState, message: "not established")

            do {
                try await wait(for: action, on: adapter) { adapter.complete(action, error: failure) }
                XCTFail("a failed action returned")
            } catch let error as BaresipError {
                XCTAssertEqual(error.code, .invalidState)
            }
        }

        func testAnsweringAnUnknownCallFails() async throws {
            let adapter = try makeAdapter()
            let action = CXAnswerCallAction(call: UUID())

            do {
                try await wait(for: action, on: adapter) {
                    adapter.provider(adapter.provider, perform: action)
                }
                XCTFail("answering an unknown call succeeded")
            } catch let error as CXErrorCodeRequestTransactionError {
                XCTAssertEqual(error.code, .unknownCallUUID)
            }
        }

        func testEndingAnUnknownCallSucceeds() async throws {
            let adapter = try makeAdapter()
            let action = CXEndCallAction(call: UUID())

            try await wait(for: action, on: adapter) {
                adapter.provider(adapter.provider, perform: action)
            }
        }

        func testATimedOutActionFailsItsCaller() async throws {
            let adapter = try makeAdapter()
            let action = CXSetHeldCallAction(call: UUID(), onHold: true)

            do {
                try await wait(for: action, on: adapter) {
                    adapter.provider(adapter.provider, timedOutPerforming: action)
                }
                XCTFail("a timed out action returned")
            } catch let error as BaresipCallKitError {
                XCTAssertEqual(error, .actionTimedOut)
            }
            XCTAssertTrue(adapter.actionWaiters.isEmpty)
        }

        func testATimedOutStartIsAbandoned() throws {
            let adapter = try makeAdapter()
            let uuid = UUID()
            let action = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: "sip:bob@example.com"))

            adapter.provider(adapter.provider, timedOutPerforming: action)

            XCTAssertEqual(adapter.book.abandonedStarts, [uuid])
        }

        func testCallsEndedOnAnotherDeviceAreNotMissed() {
            typealias Adapter = BaresipCallKitAdapter
            XCTAssertEqual(Adapter.endedReason(for: BaresipError(code: .ok, sipStatus: 200,
                                                                 endReason: .answeredElsewhere)),
                           .answeredElsewhere)
            XCTAssertEqual(Adapter.endedReason(for: BaresipError(code: .ok, sipStatus: 603,
                                                                 endReason: .declinedElsewhere)),
                           .declinedElsewhere)
            XCTAssertEqual(Adapter.endedReason(for: BaresipError(code: .sip, sipStatus: 486)), .unanswered)
            XCTAssertEqual(Adapter.endedReason(for: nil), .remoteEnded)
        }

        func testCallersAreSIPURIsUnlessNumbersAreAskedFor() throws {
            let plain = try makeAdapter()
            XCTAssertEqual(plain.handle(for: "sip:100@pbx.example.com").type, .generic)
            XCTAssertEqual(plain.handle(for: "sip:100@pbx.example.com").value, "sip:100@pbx.example.com")

            var configuration = BaresipCallKitConfiguration()
            configuration.handleStyle = .phoneNumberWhenNumeric
            let numbers = try makeAdapter(configuration)
            XCTAssertEqual(numbers.handle(for: "sip:100@pbx.example.com").type, .phoneNumber)
            XCTAssertEqual(numbers.handle(for: "sip:100@pbx.example.com").value, "100")
            XCTAssertEqual(numbers.handle(for: "sip:door1@pbx.example.com").type, .generic)
            XCTAssertEqual(numbers.handle(for: "sip:door1@pbx.example.com").value, "sip:door1@pbx.example.com")
        }
    }
#endif
