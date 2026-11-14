import XCTest
@testable import BaresipKitSystemCall

final class PushMatchTests: XCTestCase {
    private func match(_ push: String?, _ invite: String, withoutCaller: Bool = true) -> PushMatch {
        PushMatch.between(push: push, invite: invite, matchesPushWithoutCaller: withoutCaller)
    }

    func testSameUserAndHostIsTheStrongestMatch() {
        XCTAssertEqual(match("sip:100@pbx.example.com", "<sip:100@pbx.example.com:5061;transport=tls>"),
                       .userAndHost)
        XCTAssertEqual(match("SIP:100@PBX.example.com", "\"Bob\" <sips:100@pbx.example.com>;tag=1"), .userAndHost)
        XCTAssertEqual(match("sip:100@[2001:db8::1]:5061", "sip:100@[2001:db8::1]"), .userAndHost)
    }

    func testAPushWithoutHostMatchesTheUser() {
        XCTAssertEqual(match("100", "sip:100@pbx.example.com"), .user)
        XCTAssertEqual(match("sip:100", "sip:100@pbx.example.com"), .user)
    }

    func testAPushThatNamesACallerNeverMatchesAnotherUser() {
        XCTAssertEqual(match("100", "sip:1001@pbx.example.com"), .mismatch)
        XCTAssertEqual(match("sip:100@pbx.example.com", "sip:200@pbx.example.com"), .mismatch)
    }

    func testAPushWithHostNeverMatchesAnotherHost() {
        XCTAssertEqual(match("sip:100@a.example.com", "sip:100@b.example.com"), .mismatch)
        XCTAssertEqual(match("sip:100@a.example.com", "tel:100"), .mismatch)
        XCTAssertEqual(match("sip:100@[2001:db8::1]", "sip:100@[2001:db8::2]"), .mismatch)
    }

    func testAPushWithoutCallerMatchesAnyCallerOnlyWhenAllowed() {
        XCTAssertEqual(match(nil, "sip:anyone@example.com"), .anyCaller)
        XCTAssertEqual(match("", "sip:anyone@example.com"), .anyCaller)
        XCTAssertEqual(match("  ", "sip:anyone@example.com"), .anyCaller)
        XCTAssertEqual(match(nil, "sip:anyone@example.com", withoutCaller: false), .mismatch)
        XCTAssertEqual(match("", "sip:anyone@example.com", withoutCaller: false), .mismatch)
        XCTAssertEqual(match("sip:100@example.com", "sip:100@example.com", withoutCaller: false), .userAndHost)
    }

    func testMatchesAreOrderedByStrength() {
        XCTAssertLessThan(PushMatch.mismatch, .anyCaller)
        XCTAssertLessThan(PushMatch.anyCaller, .user)
        XCTAssertLessThan(PushMatch.user, .userAndHost)
    }

    func testIdentityParsing() {
        XCTAssertEqual(SIPIdentity("<sip:Alice@Example.com:5060;transport=tcp>").user, "alice")
        XCTAssertEqual(SIPIdentity("<sip:Alice@Example.com:5060;transport=tcp>").host, "example.com")
        XCTAssertEqual(SIPIdentity("sip:alice@example.com?subject=hello").host, "example.com")
        XCTAssertEqual(SIPIdentity("alice").host, "")
        XCTAssertTrue(SIPIdentity(" ").isEmpty)
        XCTAssertFalse(SIPIdentity("sip:alice@example.com").isEmpty)
    }

    func testOnlyANumericUserIsAPhoneNumber() {
        XCTAssertEqual(SIPIdentity("sip:100@pbx.example.com").phoneNumber, "100")
        XCTAssertEqual(SIPIdentity("<sip:+15555550100@pbx.example.com;user=phone>").phoneNumber, "+15555550100")
        XCTAssertEqual(SIPIdentity("tel:+15555550100").phoneNumber, "+15555550100")
        XCTAssertEqual(SIPIdentity("100").phoneNumber, "100")
        XCTAssertNil(SIPIdentity("sip:door1@pbx.example.com").phoneNumber)
        XCTAssertNil(SIPIdentity("sip:+@pbx.example.com").phoneNumber)
        XCTAssertNil(SIPIdentity("sip:10-0@pbx.example.com").phoneNumber)
        XCTAssertNil(SIPIdentity("sip:pbx.example.com").phoneNumber)
        XCTAssertNil(SIPIdentity("unknown").phoneNumber)
    }
}
