import XCTest
@testable import BaresipKit

final class ContactParameterTests: XCTestCase {
    func testEncodingPreservesSeparators() throws {
        let params = [
            ContactParameter("app-id", "com.example.app"),
            ContactParameter("pn-type", "apple"),
            ContactParameter("pn-tok", "0123abcd:remote&ffff0000:voip"),
            ContactParameter("pn-silent", "1"),
            ContactParameter("pn-timeout", "0"),
        ]
        let encoded = try BaresipEngine.encodeContactParameters(params)
        XCTAssertEqual(encoded,
                       "app-id=com.example.app;pn-type=apple;pn-tok=0123abcd:remote&ffff0000:voip;pn-silent=1;pn-timeout=0")
    }

    func testRejectsSeparatorInsideValue() {
        XCTAssertThrowsError(try BaresipEngine.encodeContactParameters([ContactParameter("pn-tok", "a;b")]))
        XCTAssertThrowsError(try BaresipEngine.encodeContactParameters([ContactParameter("pn tok", "a")]))
        XCTAssertThrowsError(try BaresipEngine.encodeContactParameters([ContactParameter("pn-tok", "a b")]))
    }

    func testEmptyIsAllowed() throws {
        XCTAssertEqual(try BaresipEngine.encodeContactParameters([]), "")
    }
}

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

final class EngineLifecycleTests: XCTestCase {
    func testCreateStartStop() async throws {
        var cfg = BaresipConfiguration()
        cfg.modules = ["g711", "l16", "auconv", "auresamp", "fakevideo"]
        cfg.audio.sourceModule = "ausine"
        cfg.audio.playerModule = "aufile"
        cfg.audio.playerDevice = "/dev/null"
        cfg.extraConfiguration = "sip_listen\t\t0.0.0.0:0"
        let engine = try BaresipEngine(configuration: cfg)
        XCTAssertEqual(engine.state, .idle)
        try await engine.start()
        XCTAssertTrue(engine.state == .ready || engine.state == .running)
        let id = try await engine.addAccount(BaresipAccountConfiguration(aor: "sip:alice@example.invalid",
                                                                         authUser: "alice",
                                                                         authPassword: "secret"))
        XCTAssertEqual(engine.registrationState(accountID: id), .none)
        try await engine.removeAccount(id)
        await engine.stop()
        XCTAssertEqual(engine.state, .stopped)
    }

    func testCapabilities() {
        XCTAssertTrue(BaresipEngine.capabilities.contains("reg.contact-params"))
        XCTAssertFalse(BaresipEngine.coreVersion.isEmpty)
    }
}
