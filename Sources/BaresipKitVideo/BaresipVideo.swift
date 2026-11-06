import Foundation
import CoreVideo
import BaresipKit

public struct BaresipVideoFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let timestamp: Duration
    public let rotationDegrees: Int
}

public protocol BaresipVideoRenderer: AnyObject, Sendable {
    func render(_ frame: BaresipVideoFrame)
    func didChangeSize(width: Int, height: Int)
}

public enum BaresipVideoSupport {
    public static let status = "Decoded-frame sinks, the VideoToolbox H.264 module and the camera source are the next core work item; this module currently exposes only the frame and renderer types."
}
