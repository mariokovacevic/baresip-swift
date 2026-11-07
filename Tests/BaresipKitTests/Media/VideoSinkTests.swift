import AVFoundation
import XCTest
import BaresipKitCore
import BaresipKitVideo
@testable import BaresipKit

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

        var frameCount: Int {
            lock.withLock { frames }
        }
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
        while recorder.frameCount < 3, Date() < deadline {
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
        var raw = bsk_video_frame()
        raw.format = BSK_PIX_NV12
        raw.width = 16
        raw.height = 8
        raw.timestamp_us = 1_500_000
        raw.rotation_degrees = 90
        raw.native_buffer = Unmanaged.passUnretained(buffer).toOpaque()
        let frame = try XCTUnwrap(BaresipVideoFrame(raw))
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

final class MediaEventMappingTests: XCTestCase {
    func testUnknownCoreValueMapsToUnknown() {
        XCTAssertEqual(BaresipMediaEvent(bsk_media_event(rawValue: 999)), .unknown)
        XCTAssertEqual(BaresipMediaEvent(BSK_MEDIA_RECORDING_STOPPED), .recordingStopped)
    }
}
