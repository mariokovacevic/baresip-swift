import Foundation
import CoreVideo
import BaresipKitCore

public enum BaresipPixelFormat: Int, Sendable, Codable {
    case nv12 = 0
    case i420 = 1
    case bgra = 2

    init(_ c: bsk_pixel_format) {
        self = BaresipPixelFormat(rawValue: Int(c.rawValue)) ?? .nv12
    }

    var cvFormat: OSType {
        switch self {
        case .nv12: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case .i420: return kCVPixelFormatType_420YpCbCr8Planar
        case .bgra: return kCVPixelFormatType_32BGRA
        }
    }
}

public struct BaresipVideoFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let timestamp: Duration
    public let rotationDegrees: Int
    public let width: Int
    public let height: Int

    public init(pixelBuffer: CVPixelBuffer, timestamp: Duration, rotationDegrees: Int) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.rotationDegrees = rotationDegrees
        self.width = CVPixelBufferGetWidth(pixelBuffer)
        self.height = CVPixelBufferGetHeight(pixelBuffer)
    }

    init?(_ c: bsk_video_frame) {
        let buffer: CVPixelBuffer
        if let native = c.native_buffer {
            buffer = Unmanaged<CVPixelBuffer>.fromOpaque(native).takeUnretainedValue()
        } else if let copied = BaresipVideoFrame.copyPlanes(c) {
            buffer = copied
        } else {
            return nil
        }
        self.init(pixelBuffer: buffer,
                  timestamp: .microseconds(Int64(c.timestamp_us)),
                  rotationDegrees: Int(c.rotation_degrees))
    }

    private static func copyPlanes(_ c: bsk_video_frame) -> CVPixelBuffer? {
        let format = BaresipPixelFormat(c.format)
        var out: CVPixelBuffer?
        let width = Int(c.width)
        let height = Int(c.height)
        guard width > 0, height > 0 else { return nil }
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format.cvFormat, nil, &out)
        guard status == kCVReturnSuccess, let out else { return nil }
        CVPixelBufferLockBaseAddress(out, [])
        defer { CVPixelBufferUnlockBaseAddress(out, []) }
        let planes: [(UnsafePointer<UInt8>?, UInt32)] = [
            (c.planes.0, c.strides.0), (c.planes.1, c.strides.1), (c.planes.2, c.strides.2),
        ]
        let planeCount = max(1, CVPixelBufferGetPlaneCount(out))
        for i in 0..<planeCount {
            guard let src = planes[i].0, let dst = CVPixelBufferGetBaseAddressOfPlane(out, i) else { continue }
            let dstStride = CVPixelBufferGetBytesPerRowOfPlane(out, i)
            let rows = CVPixelBufferGetHeightOfPlane(out, i)
            let srcStride = Int(planes[i].1)
            let rowBytes = min(srcStride, dstStride)
            for row in 0..<rows {
                memcpy(dst + row * dstStride, src + row * srcStride, rowBytes)
            }
        }
        return out
    }
}

public protocol BaresipVideoRenderer: AnyObject, Sendable {
    func render(_ frame: BaresipVideoFrame)
    func didChangeSize(width: Int, height: Int)
}

final class VideoSinkBox: @unchecked Sendable {
    let renderer: BaresipVideoRenderer
    let callID: BaresipCallID?
    let local: Bool

    init(renderer: BaresipVideoRenderer, callID: BaresipCallID?, local: Bool) {
        self.renderer = renderer
        self.callID = callID
        self.local = local
    }

    func makeSink() -> bsk_video_sink {
        var sink = bsk_video_sink()
        sink.user = Unmanaged.passUnretained(self).toOpaque()
        sink.on_frame = { _, _, _, frame, user in
            guard let user, let frame else { return }
            let box = Unmanaged<VideoSinkBox>.fromOpaque(user).takeUnretainedValue()
            guard let swiftFrame = BaresipVideoFrame(frame.pointee) else { return }
            box.renderer.render(swiftFrame)
        }
        sink.on_size = { _, _, _, width, height, user in
            guard let user else { return }
            let box = Unmanaged<VideoSinkBox>.fromOpaque(user).takeUnretainedValue()
            box.renderer.didChangeSize(width: Int(width), height: Int(height))
        }
        return sink
    }
}

struct VideoSinkKey: Hashable {
    let callID: BaresipCallID?
    let local: Bool
}
