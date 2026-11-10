import XCTest
@testable import BaresipKit

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
