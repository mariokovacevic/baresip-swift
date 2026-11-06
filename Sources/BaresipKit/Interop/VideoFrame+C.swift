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

    private static func copyPlanes(of frame: bsk_video_frame) -> CVPixelBuffer? {
        let width = Int(frame.width)
        let height = Int(frame.height)
        guard width > 0, height > 0 else { return nil }
        let format = BaresipPixelFormat(frame.format)
        var created: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format.coreVideoFormat, nil, &created)
        guard status == kCVReturnSuccess, let buffer = created else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let planes: [(source: UnsafePointer<UInt8>?, stride: UInt32)] = [
            (frame.planes.0, frame.strides.0),
            (frame.planes.1, frame.strides.1),
            (frame.planes.2, frame.strides.2),
        ]
        let planeCount = max(1, CVPixelBufferGetPlaneCount(buffer))
        for index in 0..<min(planeCount, planes.count) {
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
        for row in 0..<CVPixelBufferGetHeightOfPlane(buffer, index) {
            memcpy(destination + row * destinationStride, source + row * sourceStride, rowBytes)
        }
    }
}
