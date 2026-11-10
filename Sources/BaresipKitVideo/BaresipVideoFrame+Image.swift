import CoreGraphics
import CoreImage
import BaresipKit

extension BaresipVideoFrame {
    /// Draws the frame upright into an image, for a snapshot or a thumbnail.
    ///
    /// The frame's `rotationDegrees` is applied, so the image looks like the
    /// video on screen. Converting a frame takes a few milliseconds; do it for single frames,
    /// not for every frame of a call.
    ///
    /// ```swift
    /// if let image = frame.makeImage() {
    ///     thumbnail = UIImage(cgImage: image)
    /// }
    /// ```
    ///
    /// - Parameter context: The Core Image context to draw with. Reuse one for many images.
    /// - Returns: The image, or `nil` when the pixel buffer cannot be drawn.
    public func makeImage(context: CIContext = CIContext(options: [.cacheIntermediates: false])) -> CGImage? {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        switch ((rotationDegrees % 360) + 360) % 360 {
        case 90: image = image.oriented(.right)
        case 180: image = image.oriented(.down)
        case 270: image = image.oriented(.left)
        default: break
        }
        return context.createCGImage(image, from: image.extent)
    }
}
