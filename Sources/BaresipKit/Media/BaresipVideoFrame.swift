import CoreVideo

/// A video frame delivered to a ``BaresipVideoRenderer``.
///
/// Frames from the hardware decoder and the camera wrap the original `CVPixelBuffer`
/// without copying.
public struct BaresipVideoFrame: @unchecked Sendable {
    // SAFETY: the pixel buffer is not written after the decoder or camera hands it over, and
    // Core Video buffers are reference counted and safe to retain and read from any thread.

    /// The pixel data.
    public let pixelBuffer: CVPixelBuffer
    /// The presentation time stamp.
    public let timestamp: Duration
    /// The clockwise rotation to apply when displaying the frame: 0, 90, 180 or 270.
    public let rotationDegrees: Int
    /// The width of ``pixelBuffer`` in pixels.
    public let width: Int
    /// The height of ``pixelBuffer`` in pixels.
    public let height: Int

    /// Creates a frame.
    ///
    /// - Parameters:
    ///   - pixelBuffer: The pixel data.
    ///   - timestamp: The presentation time stamp.
    ///   - rotationDegrees: The display rotation.
    public init(pixelBuffer: CVPixelBuffer, timestamp: Duration, rotationDegrees: Int) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.rotationDegrees = rotationDegrees
        self.width = CVPixelBufferGetWidth(pixelBuffer)
        self.height = CVPixelBufferGetHeight(pixelBuffer)
    }
}
