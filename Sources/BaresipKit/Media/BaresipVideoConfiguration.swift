/// Video settings for the engine.
public struct BaresipVideoConfiguration: Sendable, Equatable {
    /// The baresip video source module; `bskcapture` is the camera source on iOS.
    public var sourceModule: String
    /// The camera, or `nil` for the default front camera.
    public var sourceDevice: String?
    /// The capture width in pixels.
    public var width: Int
    /// The capture height in pixels.
    public var height: Int
    /// The capture frame rate.
    public var framesPerSecond: Int
    /// The maximum encoder bitrate in bits per second.
    public var bitrate: Int
    /// Video codecs in order of preference.
    public var codecs: [String]
    /// Whether the VideoToolbox hardware encoder and decoder are used.
    public var hardwareAcceleration: Bool

    /// Creates video settings.
    ///
    /// - Parameters:
    ///   - sourceModule: The video source module.
    ///   - sourceDevice: The camera.
    ///   - width: The capture width.
    ///   - height: The capture height.
    ///   - framesPerSecond: The frame rate.
    ///   - bitrate: The maximum bitrate in bits per second.
    ///   - codecs: Codecs in order of preference.
    ///   - hardwareAcceleration: Whether hardware coding is used.
    public init(sourceModule: String = "bskcapture", sourceDevice: String? = nil,
                width: Int = 640, height: Int = 480, framesPerSecond: Int = 30,
                bitrate: Int = 800_000, codecs: [String] = ["H264"],
                hardwareAcceleration: Bool = true) {
        self.sourceModule = sourceModule
        self.sourceDevice = sourceDevice
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.bitrate = bitrate
        self.codecs = codecs
        self.hardwareAcceleration = hardwareAcceleration
    }
}
