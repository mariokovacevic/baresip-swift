#if os(iOS)
    import CallKit
    import XCTest
    @testable import BaresipKit
    @testable import BaresipKitCallKit

    /// A caller of an action learns whether the adapter carried it out on the engine.
    final class CallKitActionResultTests: XCTestCase {
        private func makeAdapter() throws -> BaresipCallKitAdapter {
            var configuration = BaresipConfiguration()
            configuration.modules = ["g711"]
            configuration.audio.sourceModule = "ausine"
            configuration.audio.playerModule = "aufile"
            configuration.audio.playerDevice = "/dev/null"
            return try BaresipCallKitAdapter(engine: BaresipEngine(configuration: configuration),
                                             configuration: BaresipCallKitConfiguration())
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
    }
#endif
