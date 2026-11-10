#if canImport(UIKit)
    import UIKit
    import AVFoundation
    import CoreMedia
    import os
    import BaresipKit

    /// A view that displays a call's video or the camera preview.
    ///
    /// Pass ``renderer`` to `BaresipEngine.setVideoRenderer(_:callID:local:)` or
    /// `BaresipEngine.startVideoPreview(device:renderer:)`. Frames are shown through an
    /// `AVSampleBufferDisplayLayer` without copying.
    ///
    /// ```swift
    /// let view = BaresipVideoView()
    /// try await engine.setVideoRenderer(view.renderer, callID: call)
    /// ```
    @MainActor
    public final class BaresipVideoView: UIView {
        private let displayLayer = AVSampleBufferDisplayLayer()
        private let relay = BaresipVideoFrameRelay()
        private let latest = LatestFrame()

        /// Creates the view.
        ///
        /// - Parameter frame: The initial frame.
        override public init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }

        /// Creates the view from an archive.
        ///
        /// - Parameter coder: The decoder.
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        private func setup() {
            backgroundColor = .black
            displayLayer.videoGravity = .resizeAspect
            layer.addSublayer(displayLayer)
            relayFrames()
        }

        /// Keeps the display layer the size of the view.
        override public func layoutSubviews() {
            super.layoutSubviews()
            displayLayer.frame = bounds
        }

        /// How the video fills the view; `.resizeAspect` by default.
        public var videoGravity: AVLayerVideoGravity {
            get { displayLayer.videoGravity }
            set { displayLayer.videoGravity = newValue }
        }

        /// The renderer to attach to a call or preview.
        public var renderer: BaresipVideoRenderer {
            relay
        }

        /// Removes the current image, for example when a call ends.
        public func flush() {
            if #available(iOS 17.0, *) {
                displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
            } else {
                displayLayer.flushAndRemoveImage()
            }
            latest.frame = nil
        }

        /// The frame on screen, or `nil` before the first frame and after ``flush()``.
        public var currentFrame: BaresipVideoFrame? {
            latest.frame
        }

        /// An upright image of the frame on screen, for example to keep a door station's
        /// picture with the call history.
        ///
        /// - Returns: The image, or `nil` when no frame is shown.
        public func snapshot() -> CGImage? {
            latest.frame?.makeImage()
        }

        private func relayFrames() {
            let latest = latest
            let enqueue: @Sendable (SendableBox<CMSampleBuffer>) -> Void
            if #available(iOS 17.0, *) {
                let renderer = SendableBox(displayLayer.sampleBufferRenderer)
                let failures = FailureLog()
                enqueue = { sample in
                    let target = renderer.value
                    if target.needsFlush {
                        failures.report(target.error)
                        target.flush()
                    }
                    target.enqueue(sample.value)
                }
            } else {
                let layer = SendableBox(displayLayer)
                enqueue = { sample in
                    Task { @MainActor in layer.value.enqueue(sample.value) }
                }
            }
            relay.setHandlers(onFrame: { frame in
                latest.frame = frame
                guard let sample = BaresipVideoView.makeSample(frame: frame) else { return }
                enqueue(SendableBox(sample))
            }, onSize: nil)
        }

        private nonisolated static func makeSample(frame: BaresipVideoFrame) -> CMSampleBuffer? {
            var description: CMVideoFormatDescription?
            let status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                      imageBuffer: frame.pixelBuffer,
                                                                      formatDescriptionOut: &description)
            guard status == noErr, let description else { return nil }
            var timing = CMSampleTimingInfo(duration: .invalid,
                                            presentationTimeStamp: presentationTime(of: frame),
                                            decodeTimeStamp: .invalid)
            var sample: CMSampleBuffer?
            let created = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                                   imageBuffer: frame.pixelBuffer,
                                                                   formatDescription: description,
                                                                   sampleTiming: &timing,
                                                                   sampleBufferOut: &sample)
            guard created == noErr, let sample else { return nil }
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
               CFArrayGetCount(attachments) > 0,
               let raw = CFArrayGetValueAtIndex(attachments, 0) {
                let dict = unsafeBitCast(raw, to: CFMutableDictionary.self)
                CFDictionarySetValue(dict,
                                     Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                     Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
            }
            return sample
        }

        private nonisolated static func presentationTime(of frame: BaresipVideoFrame) -> CMTime {
            let microsecondsPerSecond: Int64 = 1_000_000
            let attosecondsPerMicrosecond: Int64 = 1_000_000_000_000
            let components = frame.timestamp.components
            let microseconds = components.seconds * microsecondsPerSecond + components
                .attoseconds / attosecondsPerMicrosecond
            return CMTime(value: microseconds, timescale: CMTimeScale(microsecondsPerSecond))
        }
    }

    /// Logs the first renderer failures of a view, so a recovered failure still leaves a trace.
    private final class FailureLog: @unchecked Sendable {
        // SAFETY: `count` is read and written only while holding `lock`.
        private let lock = NSLock()
        private var count = 0
        private static let logger = Logger(subsystem: "BaresipKitVideo", category: "render")
        private static let reportedFailures = 5

        func report(_ error: Error?) {
            let number = lock.withLock { () -> Int in
                count += 1
                return count
            }
            guard number <= Self.reportedFailures else { return }
            let reason = error.map { "\($0)" } ?? "flush requested"
            Self.logger.error("video renderer flushed after failure \(number): \(reason, privacy: .public)")
        }
    }

    private final class LatestFrame: @unchecked Sendable {
        // SAFETY: `stored` is read and written only while holding `lock`.
        private let lock = NSLock()
        private var stored: BaresipVideoFrame?

        var frame: BaresipVideoFrame? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }

    private struct SendableBox<T>: @unchecked Sendable {
        // SAFETY: wraps the layer's AVSampleBufferVideoRenderer, which takes frames from any
        // thread; the layer itself, used only on the main actor before iOS 17; or a
        // CMSampleBuffer, which is not changed after it is created.
        let value: T
        init(_ value: T) {
            self.value = value
        }
    }

    @available(iOS 17.0, *)
    private extension AVSampleBufferVideoRenderer {
        var needsFlush: Bool {
            status == .failed || requiresFlushToResumeDecoding
        }
    }
#endif
