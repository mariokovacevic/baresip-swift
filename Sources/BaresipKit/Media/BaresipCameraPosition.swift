/// A camera of the device.
public enum BaresipCameraPosition: String, Sendable, Codable, CaseIterable {
    /// The camera on the screen side, the default for calls.
    case front
    /// The camera on the back.
    case back

    /// The device name to pass to `BaresipEngine.setCamera(_:callID:)`.
    public var deviceName: String {
        rawValue
    }

    /// The other camera.
    public var toggled: BaresipCameraPosition {
        self == .front ? .back : .front
    }

    /// Whether a picture from this camera is usually shown mirrored to the person in front of it.
    public var isMirroredInPreview: Bool {
        self == .front
    }
}
