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
}
