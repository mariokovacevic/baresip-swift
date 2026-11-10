/// Receives the frames of a call's local or remote video, or of the camera preview.
///
/// Attach a renderer with ``BaresipEngine/setVideoRenderer(_:callID:local:)`` or
/// ``BaresipEngine/startVideoPreview(device:renderer:)``. Both methods are called on a media
/// thread and must return quickly; hand the frame to the main thread or a display layer.
public protocol BaresipVideoRenderer: AnyObject, Sendable {
    /// Called for every frame.
    ///
    /// - Parameter frame: The frame.
    func render(_ frame: BaresipVideoFrame)

    /// Called when the frame size changes.
    ///
    /// - Parameters:
    ///   - width: The new width in pixels.
    ///   - height: The new height in pixels.
    func didChangeSize(width: Int, height: Int)
}
