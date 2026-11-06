#if canImport(UIKit)
import UIKit
import AVFoundation
import CoreMedia
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

    /// Creates the view.
    ///
    /// - Parameter frame: The initial frame.
    public override init(frame: CGRect) {
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
    public override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }

    /// How the video fills the view; `.resizeAspect` by default.
    public var videoGravity: AVLayerVideoGravity {
        get { displayLayer.videoGravity }
        set { displayLayer.videoGravity = newValue }
    }

    /// The renderer to attach to a call or preview.
    public var renderer: BaresipVideoRenderer { relay }

    /// Removes the current image, for example when a call ends.
    public func flush() {
        displayLayer.flushAndRemoveImage()
    }

    private func relayFrames() {
        let box = SendableBox(displayLayer)
        relay.setHandlers(onFrame: { frame in
            guard let sample = BaresipVideoView.makeSample(frame: frame) else { return }
            box.value.enqueue(sample)
        }, onSize: nil)
    }

    nonisolated private static func makeSample(frame: BaresipVideoFrame) -> CMSampleBuffer? {
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

    nonisolated private static func presentationTime(of frame: BaresipVideoFrame) -> CMTime {
        let microsecondsPerSecond: Int64 = 1_000_000
        let attosecondsPerMicrosecond: Int64 = 1_000_000_000_000
        let components = frame.timestamp.components
        let microseconds = components.seconds * microsecondsPerSecond + components.attoseconds / attosecondsPerMicrosecond
        return CMTime(value: microseconds, timescale: CMTimeScale(microsecondsPerSecond))
    }
}

private struct SendableBox<T>: @unchecked Sendable {
    // SAFETY: wraps the AVSampleBufferDisplayLayer, whose enqueue(_:) may be called from any thread.
    let value: T
    init(_ value: T) { self.value = value }
}
#endif
