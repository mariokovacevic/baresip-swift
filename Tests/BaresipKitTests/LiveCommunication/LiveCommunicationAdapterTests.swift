#if os(iOS)
    import LiveCommunicationKit
    import XCTest
    @testable import BaresipKit
    @testable import BaresipKitLiveCommunication

    /// The LiveCommunicationKit adapter carries out actions and reports calls as the CallKit one.
    @available(iOS 17.4, *)
    final class LiveCommunicationAdapterTests: XCTestCase {
        private func makeAdapter(
            _ settings: BaresipLiveCommunicationConfiguration = BaresipLiveCommunicationConfiguration()
        ) throws -> BaresipLiveCommunicationAdapter {
            var configuration = BaresipConfiguration()
            configuration.modules = ["g711"]
            configuration.audio.sourceModule = "ausine"
            configuration.audio.playerModule = "aufile"
            configuration.audio.playerDevice = "/dev/null"
            let adapter = try BaresipLiveCommunicationAdapter(engine: BaresipEngine(configuration: configuration),
                                                              configuration: settings)
            adapter.manager.delegate = nil
            return adapter
        }

        /// Waits like `requestAndWait(_:)` does, without asking the system, and lets `perform`
        /// finish the action.
        private func wait(for action: ConversationAction, on adapter: BaresipLiveCommunicationAdapter,
                          perform: () -> Void) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                adapter.lock.withLock { adapter.actionWaiters[action.uuid] = continuation }
                perform()
            }
        }

        func testTheManagerTakesTheSettings() throws {
            var settings = BaresipLiveCommunicationConfiguration(supportsVideo: false,
                                                                 maximumConversationsPerConversationGroup: 2)
            settings.includesCallsInRecents = false
            let adapter = try makeAdapter(settings)

            XCTAssertFalse(adapter.manager.configuration.supportsVideo)
            XCTAssertEqual(adapter.manager.configuration.maximumConversationsPerConversationGroup, 2)
            XCTAssertFalse(adapter.manager.configuration.includesConversationInRecents)
            XCTAssertEqual(adapter.manager.configuration.supportedHandleTypes, [.generic, .phoneNumber])
        }

        func testASuccessfulActionReturns() async throws {
            let adapter = try makeAdapter()
            let action = PauseConversationAction(conversationUUID: UUID(), isPaused: true)

            try await wait(for: action, on: adapter) { adapter.complete(action, error: nil) }

            XCTAssertTrue(adapter.actionWaiters.isEmpty)
        }

        func testTheEngineErrorReachesTheCaller() async throws {
            let adapter = try makeAdapter()
            let action = MuteConversationAction(conversationUUID: UUID(), isMuted: true)
            let failure = BaresipError(code: .invalidState, message: "not established")

            do {
                try await wait(for: action, on: adapter) { adapter.complete(action, error: failure) }
                XCTFail("a failed action returned")
            } catch let error as BaresipError {
                XCTAssertEqual(error, failure)
            }
            XCTAssertTrue(adapter.actionWaiters.isEmpty)
        }

        func testActionsOfUnknownCallsFail() async throws {
            let adapter = try makeAdapter()
            let action = PlayToneAction(conversationUUID: UUID(), digits: "1", tone: .single)

            do {
                try await wait(for: action, on: adapter) {
                    adapter.conversationManager(adapter.manager, perform: action)
                }
                XCTFail("an action of an unknown call returned")
            } catch let error as BaresipLiveCommunicationError {
                XCTAssertEqual(error, .unknownCall)
            }
        }

        func testATimedOutStartIsAbandoned() throws {
            let adapter = try makeAdapter()
            let uuid = UUID()
            let action = StartConversationAction(conversationUUID: uuid,
                                                 handles: [Handle(type: .generic, value: "sip:bob@example.com")],
                                                 isVideo: false)

            adapter.conversationManager(adapter.manager, timedOutPerforming: action)

            XCTAssertEqual(adapter.book.abandonedStarts, [uuid])
        }

        func testCallersAreSIPURIsUnlessNumbersAreAskedFor() throws {
            let plain = try makeAdapter()
            XCTAssertEqual(plain.handle(for: "sip:100@pbx.example.com").type, .generic)
            XCTAssertEqual(plain.handle(for: "sip:100@pbx.example.com").value, "sip:100@pbx.example.com")

            var settings = BaresipLiveCommunicationConfiguration()
            settings.handleStyle = .phoneNumberWhenNumeric
            let numbers = try makeAdapter(settings)
            XCTAssertEqual(numbers.handle(for: "sip:100@pbx.example.com").type, .phoneNumber)
            XCTAssertEqual(numbers.handle(for: "sip:100@pbx.example.com").value, "100")
            XCTAssertEqual(numbers.handle(for: "sip:door1@pbx.example.com", displayName: "Door").displayName, "Door")
        }

        func testVideoIsOfferedOnlyForVideoCalls() throws {
            let adapter = try makeAdapter()

            XCTAssertFalse(adapter.capabilities(video: false).contains(.video))
            XCTAssertTrue(adapter.capabilities(video: true).contains(.video))
            XCTAssertTrue(adapter.capabilities(video: false).contains([.playingTones, .pausing]))
        }

        func testEndedCallsGiveTheirReason() {
            typealias Adapter = BaresipLiveCommunicationAdapter
            XCTAssertEqual(Adapter.endedReason(for: nil), .remoteEnded)
            XCTAssertEqual(Adapter.endedReason(for: BaresipError(code: .sip, sipStatus: 486, message: "busy")),
                           .unanswered)
            XCTAssertEqual(Adapter.endedReason(for: BaresipError(code: .sip, sipStatus: 404, message: "gone")),
                           .failed)
            XCTAssertEqual(Adapter.endedReason(for: BaresipError(code: .ok, sipStatus: 200,
                                                                 endReason: .answeredElsewhere)),
                           .joinedElsewhere)
            XCTAssertEqual(Adapter.endedReason(for: BaresipError(code: .ok, sipStatus: 603,
                                                                 endReason: .declinedElsewhere)),
                           .declinedElsewhere)
        }
    }
#endif
