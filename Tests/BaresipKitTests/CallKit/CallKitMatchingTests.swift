import XCTest
@testable import BaresipKitCallKit

final class CallKitMatchingTests: XCTestCase {
    func testPushMatchesSameUser() {
        XCTAssertTrue(BaresipCallKitAdapter.pushMatches("100", invite: "sip:100@pbx.example.com"))
        XCTAssertTrue(BaresipCallKitAdapter.pushMatches("sip:100@pbx.example.com",
                                                        invite: "<sip:100@pbx.example.com:5061;transport=tls>"))
        XCTAssertTrue(BaresipCallKitAdapter.pushMatches(nil, invite: "sip:anyone@example.com"))
        XCTAssertTrue(BaresipCallKitAdapter.pushMatches("", invite: "sip:anyone@example.com"))
    }

    func testPushDoesNotMatchPrefixOrOtherHost() {
        XCTAssertFalse(BaresipCallKitAdapter.pushMatches("100", invite: "sip:1001@pbx.example.com"))
        XCTAssertFalse(BaresipCallKitAdapter.pushMatches("sip:100@a.example.com", invite: "sip:100@b.example.com"))
    }
}
