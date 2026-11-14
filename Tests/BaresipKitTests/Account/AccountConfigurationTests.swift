import XCTest
@testable import BaresipKit

final class AccountConfigurationTests: XCTestCase {
    func testValidation() {
        XCTAssertNoThrow(try BaresipAccountConfiguration(aor: "sip:alice@example.com").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "alice@example.com").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:example.com").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:a@b", authUser: "").validate())
    }

    func testValidationRejectsWhatCannotBeSent() {
        let aor = "sip:alice@example.com"
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:@example.com").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:alice@").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:alice@example.com?transport=udp").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:alice@example.com;transport=udp").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: "sip:alice@example.com\r\nX-Injected: 1").validate())
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: aor, registrar: "example.com").validate())
        XCTAssertThrowsError(
            try BaresipAccountConfiguration(aor: aor, outboundProxy: "sip:proxy.example.com\r\nX: 1").validate()
        )
        XCTAssertThrowsError(try BaresipAccountConfiguration(aor: aor, authUser: "alice\nbob").validate())
        XCTAssertNoThrow(
            try BaresipAccountConfiguration(aor: "sips:alice@example.com",
                                            registrar: "sip:registrar.example.com:5061;transport=tls").validate()
        )
    }

    func testOnlyOneTURNServerIsAccepted() {
        let turn = BaresipTURNServer(uri: "turn:turn.example.com:3478", username: "user", password: "secret")
        var account = BaresipAccountConfiguration(aor: "sip:alice@example.com")
        account.nat = BaresipNATConfiguration(mode: .ice, turnServers: [turn])
        XCTAssertNoThrow(try account.validate())
        account.nat.turnServers = [turn, turn]
        XCTAssertThrowsError(try account.validate())
    }

    func testHugeDurationsAreClamped() {
        XCTAssertEqual(Duration.seconds(Int64.max).wholeMilliseconds, .max)
        XCTAssertEqual(Duration.seconds(Int64.max).wholeSeconds, .max)
        XCTAssertEqual(Duration.seconds(-5).wholeMilliseconds, 0)
        XCTAssertEqual(Duration.milliseconds(1500).wholeMilliseconds, 1500)
    }

    func testDefaultsAreSecure() {
        let cfg = BaresipConfiguration(instanceUUID: UUID())
        XCTAssertEqual(cfg.tls.minimumVersion, .tls12)
        let acc = BaresipAccountConfiguration(aor: "sip:alice@example.com")
        XCTAssertEqual(acc.transport, .tls)
        XCTAssertEqual(acc.mediaEncryption, .srtpOptional)
    }
}
