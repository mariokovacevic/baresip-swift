import Foundation
import CoreVideo
import BaresipKit

/// A video frame; the same type as `BaresipKit.BaresipVideoFrame`.
public typealias BaresipVideoFrame = BaresipKit.BaresipVideoFrame
/// A frame receiver; the same type as `BaresipKit.BaresipVideoRenderer`.
public typealias BaresipVideoRenderer = BaresipKit.BaresipVideoRenderer
/// A pixel format; the same type as `BaresipKit.BaresipPixelFormat`.
public typealias BaresipPixelFormat = BaresipKit.BaresipPixelFormat

/// A renderer that forwards frames and size changes to closures.
///
/// ```swift
/// let relay = BaresipVideoFrameRelay(onFrame: { frame in encoder.append(frame.pixelBuffer) })
/// try await engine.setVideoRenderer(relay, callID: call)
/// ```
public final class BaresipVideoFrameRelay: BaresipVideoRenderer, @unchecked Sendable {
    // SAFETY: both handlers are read and replaced only while holding `lock`.
    private let lock = NSLock()
    private var onFrame: (@Sendable (BaresipVideoFrame) -> Void)?
    private var onSize: (@Sendable (Int, Int) -> Void)?

    /// Creates a relay.
    ///
    /// - Parameters:
    ///   - onFrame: Called on a media thread for every frame.
    ///   - onSize: Called when the frame size changes.
    public init(onFrame: (@Sendable (BaresipVideoFrame) -> Void)? = nil,
                onSize: (@Sendable (Int, Int) -> Void)? = nil) {
        self.onFrame = onFrame
        self.onSize = onSize
    }

    /// Replaces both handlers.
    ///
    /// - Parameters:
    ///   - onFrame: Called for every frame, or `nil`.
    ///   - onSize: Called when the size changes, or `nil`.
    public func setHandlers(onFrame: (@Sendable (BaresipVideoFrame) -> Void)?,
                            onSize: (@Sendable (Int, Int) -> Void)?) {
        lock.withLock {
            self.onFrame = onFrame
            self.onSize = onSize
        }
    }

    /// Passes the frame to the frame handler.
    ///
    /// - Parameter frame: The frame.
    public func render(_ frame: BaresipVideoFrame) {
        let handler = lock.withLock { onFrame }
        handler?(frame)
    }

    /// Passes the new size to the size handler.
    ///
    /// - Parameters:
    ///   - width: The width in pixels.
    ///   - height: The height in pixels.
    public func didChangeSize(width: Int, height: Int) {
        let handler = lock.withLock { onSize }
        handler?(width, height)
    }
}
