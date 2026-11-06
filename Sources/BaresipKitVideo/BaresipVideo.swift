import Foundation
import CoreVideo
import BaresipKit

public typealias BaresipVideoFrame = BaresipKit.BaresipVideoFrame
public typealias BaresipVideoRenderer = BaresipKit.BaresipVideoRenderer
public typealias BaresipPixelFormat = BaresipKit.BaresipPixelFormat

public final class BaresipVideoFrameRelay: BaresipVideoRenderer, @unchecked Sendable {
    private let lock = NSLock()
    private var onFrame: (@Sendable (BaresipVideoFrame) -> Void)?
    private var onSize: (@Sendable (Int, Int) -> Void)?

    public init(onFrame: (@Sendable (BaresipVideoFrame) -> Void)? = nil,
                onSize: (@Sendable (Int, Int) -> Void)? = nil) {
        self.onFrame = onFrame
        self.onSize = onSize
    }

    public func render(_ frame: BaresipVideoFrame) {
        let handler = lock.withLock { onFrame }
        handler?(frame)
    }

    public func didChangeSize(width: Int, height: Int) {
        let handler = lock.withLock { onSize }
        handler?(width, height)
    }
}

public enum BaresipVideoSupport {
    public static let status = "Renderer and preview APIs are wired to the C ABI; the core returns unsupported until the VideoToolbox H.264 module and the camera source land."
}
