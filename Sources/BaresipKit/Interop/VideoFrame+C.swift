import CoreVideo
import Foundation
import BaresipKitCore

extension BaresipVideoFrame {
    init?(_ frame: bsk_video_frame) {
        guard let buffer = Self.pixelBuffer(for: frame) else { return nil }
        self.init(pixelBuffer: buffer,
                  timestamp: .microseconds(Int64(frame.timestamp_us)),
                  rotationDegrees: Int(frame.rotation_degrees))
    }

    private static func pixelBuffer(for frame: bsk_video_frame) -> CVPixelBuffer? {
        if let native = frame.native_buffer {
            // SAFETY: native_buffer is a CVPixelBufferRef the core keeps alive for the duration of
            // the callback; taking it unretained and storing it in a Swift value retains it.
            return Unmanaged<CVPixelBuffer>.fromOpaque(native).takeUnretainedValue()
        }
        return copyPlanes(of: frame)
    }

    /// Copies a frame without a native buffer, such as a camera frame the engine converted for
    /// the encoder, into an IOSurface-backed buffer. `AVSampleBufferDisplayLayer` shows only such
    /// buffers, and only bi-planar YUV, so I420 is copied as NV12.
    private static func copyPlanes(of frame: bsk_video_frame) -> CVPixelBuffer? {
        let width = Int(frame.width)
        let height = Int(frame.height)
        guard width > 0, height > 0 else { return nil }
        let format = BaresipPixelFormat(frame.format)
        let target = format == .i420 ? BaresipPixelFormat.nv12 : format
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [String: Any]()] as CFDictionary
        var created: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, target.coreVideoFormat,
                                         attributes, &created)
        guard status == kCVReturnSuccess, let buffer = created else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let planes: [(source: UnsafePointer<UInt8>?, stride: UInt32)] = [
            (frame.planes.0, frame.strides.0),
            (frame.planes.1, frame.strides.1),
            (frame.planes.2, frame.strides.2),
        ]
        if format == .i420 {
            copy(plane: planes[0], into: buffer, at: 0)
            interleave(blue: planes[1], red: planes[2], into: buffer)
            return buffer
        }
        let planeCount = max(1, CVPixelBufferGetPlaneCount(buffer))
        for index in 0 ..< min(planeCount, planes.count) {
            copy(plane: planes[index], into: buffer, at: index)
        }
        return buffer
    }

    private static func copy(plane: (source: UnsafePointer<UInt8>?, stride: UInt32),
                             into buffer: CVPixelBuffer, at index: Int) {
        guard let source = plane.source, let destination = CVPixelBufferGetBaseAddressOfPlane(buffer, index) else {
            return
        }
        let destinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, index)
        let sourceStride = Int(plane.stride)
        let rowBytes = min(sourceStride, destinationStride)
        // SAFETY: both planes have at least `rows` rows of their own stride; rowBytes fits in either.
        for row in 0 ..< CVPixelBufferGetHeightOfPlane(buffer, index) {
            memcpy(destination + row * destinationStride, source + row * sourceStride, rowBytes)
        }
    }

    /// Writes the blue (U) and red (V) chroma planes of an I420 frame as the interleaved
    /// chroma plane of NV12.
    private static func interleave(blue: (source: UnsafePointer<UInt8>?, stride: UInt32),
                                   red: (source: UnsafePointer<UInt8>?, stride: UInt32),
                                   into buffer: CVPixelBuffer) {
        guard let bluePlane = blue.source, let redPlane = red.source,
              let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else { return }
        let destination = base.assumingMemoryBound(to: UInt8.self)
        let destinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        let rows = CVPixelBufferGetHeightOfPlane(buffer, 1)
        let pairs = min(CVPixelBufferGetWidthOfPlane(buffer, 1), Int(blue.stride), Int(red.stride))
        // SAFETY: the I420 chroma planes have `rows` rows of their stride, and each destination row
        // has room for `pairs` two-byte pairs.
        for row in 0 ..< rows {
            let blueRow = bluePlane + row * Int(blue.stride)
            let redRow = redPlane + row * Int(red.stride)
            let out = destination + row * destinationStride
            for column in 0 ..< pairs {
                out[2 * column] = blueRow[column]
                out[2 * column + 1] = redRow[column]
            }
        }
    }
}
