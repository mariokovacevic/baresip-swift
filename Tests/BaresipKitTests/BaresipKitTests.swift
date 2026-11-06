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

import BaresipKitBridge
import BaresipKitVideo
import BaresipKitAudio
import AVFoundation

final class VideoSinkTests: XCTestCase {
    final class Recorder: BaresipVideoRenderer, @unchecked Sendable {
        let lock = NSLock()
        var frames = 0
        var sizes = 0
        var lastWidth = 0
        var lastHeight = 0
        func render(_ frame: BaresipVideoFrame) {
            lock.withLock {
                frames += 1
                lastWidth = frame.width
                lastHeight = frame.height
            }
        }
        func didChangeSize(width: Int, height: Int) {
            lock.withLock { sizes += 1 }
        }
        var frameCount: Int { lock.withLock { frames } }
    }

    private func makeEngine() throws -> BaresipEngine {
        var cfg = BaresipConfiguration()
        cfg.modules = ["g711", "l16", "auconv", "auresamp", "fakevideo"]
        cfg.audio.sourceModule = "ausine"
        cfg.audio.playerModule = "aufile"
        cfg.audio.playerDevice = "/dev/null"
        cfg.video.sourceModule = "fakevideo"
        cfg.video.width = 320
        cfg.video.height = 240
        cfg.video.framesPerSecond = 15
        cfg.extraConfiguration = "sip_listen\t\t0.0.0.0:0"
        return try BaresipEngine(configuration: cfg)
    }

    func testPreviewDeliversFramesAndStops() async throws {
        let engine = try makeEngine()
        try await engine.start()
        let recorder = Recorder()
        try await engine.startVideoPreview(renderer: recorder)
        let deadline = Date().addingTimeInterval(3)
        while recorder.frameCount < 3 && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertGreaterThanOrEqual(recorder.frameCount, 3)
        XCTAssertEqual(recorder.lastWidth, 320)
        XCTAssertEqual(recorder.lastHeight, 240)
        XCTAssertGreaterThanOrEqual(recorder.sizes, 1)
        try await engine.stopVideoPreview()
        let after = recorder.frameCount
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(recorder.frameCount, after)
        await engine.stop()
    }

    func testUnknownCallIsNotFound() async throws {
        let engine = try makeEngine()
        try await engine.start()
        let recorder = Recorder()
        do {
            try await engine.setVideoRenderer(recorder, callID: BaresipCallID(rawValue: 42))
            XCTFail("expected notFound")
        } catch let error as BaresipError {
            XCTAssertEqual(error.status, .notFound)
        }
        do {
            try await engine.setVideoMaxBitrate(callID: BaresipCallID(rawValue: 42), bitsPerSecond: 200_000)
            XCTFail("expected notFound")
        } catch let error as BaresipError {
            XCTAssertEqual(error.status, .notFound)
        }
        do {
            try await engine.restartICE(callID: BaresipCallID(rawValue: 42))
            XCTFail("expected notFound")
        } catch let error as BaresipError {
            XCTAssertEqual(error.status, .notFound)
        }
        do {
            try await engine.transferAttended(callID: BaresipCallID(rawValue: 42), to: BaresipCallID(rawValue: 43))
            XCTFail("expected notFound")
        } catch let error as BaresipError {
            XCTAssertEqual(error.status, .notFound)
        }
        do {
            try await engine.sendMessage(to: "sip:bob@example.invalid", text: "hi")
            XCTFail("expected notFound without an account")
        } catch let error as BaresipError {
            XCTAssertEqual(error.status, .notFound)
        }
        let devices = await engine.videoDevices()
        XCTAssertNotNil(devices)
        await engine.stop()
    }

    func testAdaptiveBitrateDefaults() {
        let cfg = BaresipConfiguration()
        XCTAssertTrue(cfg.videoAdaptiveBitrate)
        XCTAssertEqual(cfg.videoMinimumBitrate, 150_000)
    }

    func testFrameFromNativeBuffer() throws {
        var pb: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 16, 8,
                                           kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &pb),
                       kCVReturnSuccess)
        let buffer = try XCTUnwrap(pb)
        var c = bsk_video_frame()
        c.format = BSK_PIX_NV12
        c.width = 16
        c.height = 8
        c.timestamp_us = 1_500_000
        c.rotation_degrees = 90
        c.native_buffer = Unmanaged.passUnretained(buffer).toOpaque()
        let frame = try XCTUnwrap(BaresipVideoFrame(c))
        XCTAssertEqual(frame.width, 16)
        XCTAssertEqual(frame.height, 8)
        XCTAssertEqual(frame.rotationDegrees, 90)
        XCTAssertEqual(frame.timestamp, .microseconds(1_500_000))
        XCTAssertTrue(frame.pixelBuffer === buffer)
    }

    @MainActor
    func testVideoViewAcceptsFrame() throws {
        var pb: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 32, 16,
                                           kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &pb),
                       kCVReturnSuccess)
        let buffer = try XCTUnwrap(pb)
        let view = BaresipVideoView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let frame = BaresipVideoFrame(pixelBuffer: buffer, timestamp: .milliseconds(10), rotationDegrees: 0)
        view.renderer.render(frame)
        view.renderer.didChangeSize(width: 32, height: 16)
        view.flush()
    }
}

final class NetworkEventTests: XCTestCase {
    func testNetworkEventMapping() {
        var ev = bsk_event()
        bsk_bridge_make_network_event(&ev, true, "192.0.2.10")
        let mapped = withUnsafePointer(to: &ev) { BaresipEvent($0) }
        guard case .network(let net)? = mapped else {
            return XCTFail("expected network event, got \(String(describing: mapped))")
        }
        XCTAssertTrue(net.transportsReset)
        XCTAssertEqual(net.localAddress, "192.0.2.10")
    }

    func testEngineThreadAndABI() throws {
        let engine = try BaresipEngine(configuration: BaresipConfiguration())
        XCTAssertFalse(engine.isEngineThread)
        XCTAssertEqual(BaresipEngine.abiVersion.major, 0)
        XCTAssertEqual(BaresipEngine.abiVersion.minor, 5)
    }
}

final class AudioOptionsTests: XCTestCase {
    func testBluetoothFlagControlsBothProfiles() {
        let on = BaresipAudioSessionController.voipCategoryOptions(allowBluetooth: true, defaultToSpeaker: false)
        let off = BaresipAudioSessionController.voipCategoryOptions(allowBluetooth: false, defaultToSpeaker: true)
        XCTAssertTrue(on.contains(.allowBluetoothA2DP))
        XCTAssertFalse(on.contains(.defaultToSpeaker))
        XCTAssertFalse(off.contains(.allowBluetoothA2DP))
        XCTAssertTrue(off.contains(.defaultToSpeaker))
        #if compiler(>=6.2)
        XCTAssertTrue(on.contains(.allowBluetoothHFP))
        XCTAssertFalse(off.contains(.allowBluetoothHFP))
        #else
        XCTAssertTrue(on.contains(.allowBluetooth))
        XCTAssertFalse(off.contains(.allowBluetooth))
        #endif
    }
}
