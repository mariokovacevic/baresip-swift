#if os(iOS)
    import AVFoundation
    import XCTest
    @testable import BaresipKitAudio

    final class AudioInterruptionTests: XCTestCase {
        private func response(to type: AVAudioSession.InterruptionType,
                              options: AVAudioSession.InterruptionOptions = [],
                              activation: SessionActivation) -> InterruptionResponse {
            BaresipAudioSessionController.interruptionResponse(to: type, options: options, activation: activation)
        }

        func testABeginningInterruptionPausesTheEngine() {
            XCTAssertEqual(response(to: .began, activation: .controller), .pauseEngine)
            XCTAssertEqual(response(to: .began, activation: .callKit), .pauseEngine)
            XCTAssertEqual(response(to: .began, activation: .inactive), .pauseEngine)
            XCTAssertEqual(response(to: .began, options: [.shouldResume], activation: .controller), .pauseEngine)
        }

        func testAnEndWithoutShouldResumeStaysPaused() {
            XCTAssertEqual(response(to: .ended, activation: .controller), .stayPaused)
            XCTAssertEqual(response(to: .ended, activation: .callKit), .stayPaused)
            XCTAssertEqual(response(to: .ended, activation: .inactive), .stayPaused)
        }

        func testAnEndWithShouldResumeReactivatesASessionTheControllerActivated() {
            XCTAssertEqual(response(to: .ended, options: [.shouldResume], activation: .controller),
                           .reactivateSessionAndResumeEngine)
        }

        func testAnEndWithShouldResumeWaitsForCallKitToActivateAgain() {
            XCTAssertEqual(response(to: .ended, options: [.shouldResume], activation: .callKit), .stayPaused)
        }

        func testAnEndWithShouldResumeResumesTheEngineWhenSomeoneElseOwnsTheSession() {
            XCTAssertEqual(response(to: .ended, options: [.shouldResume], activation: .inactive), .resumeEngine)
        }

        func testOnlyASessionTheControllerActivatedIsReactivatedAfterAReset() {
            XCTAssertTrue(BaresipAudioSessionController.reactivatesSession(afterResetWith: .controller))
            XCTAssertFalse(BaresipAudioSessionController.reactivatesSession(afterResetWith: .callKit))
            XCTAssertFalse(BaresipAudioSessionController.reactivatesSession(afterResetWith: .inactive))
        }
    }
#endif
