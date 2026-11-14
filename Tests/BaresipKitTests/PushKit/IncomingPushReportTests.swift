import XCTest
@testable import BaresipKitPushKit

final class IncomingPushReportTests: XCTestCase {
    private struct CallKitUnavailable: Error {}

    private static func failingHandler(_: [AnyHashable: Any]) throws {
        throw CallKitUnavailable()
    }

    func testAReportedPushNeedsNoPlaceholder() {
        let alice = "sip:alice@example.com"
        var caller: String?
        var placeholders = 0

        let failure = IncomingPushReport.deliver(["from": alice], to: { caller = $0["from"] as? String },
                                                 orReportPlaceholder: { placeholders += 1 })

        XCTAssertNil(failure)
        XCTAssertEqual(caller, alice)
        XCTAssertEqual(placeholders, 0)
    }

    func testAThrowingHandlerReportsThePlaceholderBeforeReturning() {
        var placeholders = 0

        let failure = IncomingPushReport.deliver([:], to: Self.failingHandler,
                                                 orReportPlaceholder: { placeholders += 1 })

        XCTAssertTrue(failure is CallKitUnavailable)
        XCTAssertEqual(placeholders, 1)
    }

    func testAnAsynchronousHandlerThatReturnsInTimeNeedsNoPlaceholder() async {
        let failure = await IncomingPushReport.deliver(within: .seconds(5)) {}

        XCTAssertNil(failure)
    }

    func testAnAsynchronousHandlerThatThrowsGivesItsError() async {
        let failure = await IncomingPushReport.deliver(within: .seconds(5)) {
            throw CallKitUnavailable()
        }

        XCTAssertTrue(failure?.error is CallKitUnavailable)
    }

    func testAnAsynchronousHandlerThatHangsTimesOutAndIsCancelled() async {
        let cancelled = expectation(description: "the hanging handler is cancelled")
        let started = ContinuousClock.now

        let failure = await IncomingPushReport.deliver(within: .milliseconds(100)) {
            await withTaskCancellationHandler {
                try? await Task.sleep(for: .seconds(60))
            } onCancel: {
                cancelled.fulfill()
            }
        }

        XCTAssertEqual(failure?.error as? BaresipPushKitError, .reportTimedOut)
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(5))
        await fulfillment(of: [cancelled], timeout: 5)
    }
}
