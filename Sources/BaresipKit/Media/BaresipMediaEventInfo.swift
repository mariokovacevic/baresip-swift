/// Details of a ``BaresipEvent/media(_:_:)`` event.
public struct BaresipMediaEventInfo: Sendable, Equatable {
    /// What changed.
    public let event: BaresipMediaEvent
    /// The audio direction after the change.
    public let audioDirection: BaresipMediaDirection
    /// The video direction after the change.
    public let videoDirection: BaresipMediaDirection
    /// Extra information, for example the encryption method, or an empty string.
    public let detail: String
}
