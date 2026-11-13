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
        XCTAssertTrue(BaresipEngine.capabilities.contains("audio.hold-music"))
        XCTAssertTrue(BaresipEngine.capabilities.contains("call.session-timer"))
        XCTAssertFalse(BaresipEngine.coreVersion.isEmpty)
    }

    func testHoldMusicFileIsReadWhenTheEngineIsCreated() throws {
        var cfg = BaresipConfiguration()
        cfg.modules = ["g711", "l16", "auconv", "auresamp"]
        cfg.audio.sourceModule = "ausine"
        cfg.audio.playerModule = "aufile"
        cfg.audio.playerDevice = "/dev/null"
        cfg.extraConfiguration = "sip_listen\t\t0.0.0.0:0"

        cfg.audio.holdMusicFile = URL(fileURLWithPath: "/nonexistent/hold.wav")
        XCTAssertThrowsError(try BaresipEngine(configuration: cfg))

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("hold-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("not a wave file, only text".utf8).write(to: file)
        cfg.audio.holdMusicFile = file
        XCTAssertThrowsError(try BaresipEngine(configuration: cfg))

        try Self.wav(sampleRate: 8000, seconds: 1).write(to: file)
        XCTAssertNoThrow(try BaresipEngine(configuration: cfg))
    }

    func testASessionTimerShorterThanItsMinimumIsRejected() throws {
        var cfg = BaresipConfiguration()
        cfg.modules = ["g711", "l16", "auconv", "auresamp"]
        cfg.audio.sourceModule = "ausine"
        cfg.audio.playerModule = "aufile"
        cfg.audio.playerDevice = "/dev/null"
        cfg.extraConfiguration = "sip_listen\t\t0.0.0.0:0"

        XCTAssertEqual(cfg.sessionTimer, .seconds(1800))
        XCTAssertEqual(cfg.minimumSessionTimer, .seconds(90))

        cfg.sessionTimer = .seconds(60)
        XCTAssertThrowsError(try BaresipEngine(configuration: cfg))

        cfg.minimumSessionTimer = .seconds(60)
        XCTAssertNoThrow(try BaresipEngine(configuration: cfg))

        cfg.sessionTimer = nil
        cfg.minimumSessionTimer = .seconds(90)
        XCTAssertNoThrow(try BaresipEngine(configuration: cfg))
    }

    /// A mono 16-bit PCM WAV file with a 440 Hz tone.
    private static func wav(sampleRate: Int, seconds: Int) -> Data {
        let frames = sampleRate * seconds
        var data = Data()
        func append(_ value: some FixedWidthInteger) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + frames * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(frames * 2))
        for frame in 0 ..< frames {
            append(Int16(8000 * sin(2 * Double.pi * 440 * Double(frame) / Double(sampleRate))))
        }
        return data
    }
}
