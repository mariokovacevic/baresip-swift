import XCTest
@testable import BaresipKit

final class AccountConfigurationTests: XCTestCase {
    func testValidation() {
        XCTAssertNoThrow(try BaresipAccountConfiguration(aor: "sip:alice@example.com").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "alice@example.com").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:example.com").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:a@b", authUser: "").validate())
    }

    func testDefaultsAreSecure() {
        let cfg = BaresipConfiguration()
        XCTAssertTrue(cfg.tls.verifyServer)
        XCTAssertEqual(cfg.tls.minimumVersion, .tls12)
        let acc = BaresipAccountConfiguration(aor: "sip:alice@example.com")
        XCTAssertEqual(acc.transport, .tls)
        XCTAssertEqual(acc.mediaEncryption, .srtpOptional)
    }
}
