import CoreVideo

/// The pixel layout of a decoded or captured video frame.
public enum BaresipPixelFormat: Int, Sendable, Codable {
    /// Bi-planar 4:2:0 YCbCr, the native VideoToolbox format.
    case nv12 = 0
    /// Planar 4:2:0 YCbCr.
    case i420 = 1
    /// 32-bit BGRA.
    case bgra = 2

    var coreVideoFormat: OSType {
        switch self {
        case .nv12: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case .i420: return kCVPixelFormatType_420YpCbCr8Planar
        case .bgra: return kCVPixelFormatType_32BGRA
        }
    }
}
