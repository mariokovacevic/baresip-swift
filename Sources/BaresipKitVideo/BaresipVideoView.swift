#if canImport(UIKit)
import UIKit
import AVFoundation
import CoreMedia
import BaresipKit

@MainActor
public final class BaresipVideoView: UIView {
    private let displayLayer = AVSampleBufferDisplayLayer()
    private let relay = BaresipVideoFrameRelay()
    private var formatDescription: CMVideoFormatDescription?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

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

    public override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }

    public var videoGravity: AVLayerVideoGravity {
        get { displayLayer.videoGravity }
        set { displayLayer.videoGravity = newValue }
    }

    public var renderer: BaresipVideoRenderer { relay }

    public func flush() {
        displayLayer.flushAndRemoveImage()
        formatDescription = nil
    }

    private func relayFrames() {
        let layer = displayLayer
        let box = SendableBox(layer)
        relay.setHandlers(onFrame: { [weak self] frame in
            let sample = Self.makeSample(frame: frame, cache: self)
            guard let sample else { return }
            box.value.enqueue(sample)
        }, onSize: nil)
    }

    nonisolated private static func makeSample(frame: BaresipVideoFrame,
                                               cache: BaresipVideoView?) -> CMSampleBuffer? {
        var description: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                  imageBuffer: frame.pixelBuffer,
                                                                  formatDescriptionOut: &description)
        guard status == noErr, let description else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: CMTime(value: Int64(frame.timestamp.components.seconds * 1_000_000 + frame.timestamp.components.attoseconds / 1_000_000_000_000), timescale: 1_000_000),
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        let created = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                               imageBuffer: frame.pixelBuffer,
                                                               formatDescription: description,
                                                               sampleTiming: &timing,
                                                               sampleBufferOut: &sample)
        guard created == noErr, let sample else { return nil }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) as? [CFMutableDictionary],
           let first = attachments.first {
            CFDictionarySetValue(first,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        _ = cache
        return sample
    }
}

private struct SendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
#endif
