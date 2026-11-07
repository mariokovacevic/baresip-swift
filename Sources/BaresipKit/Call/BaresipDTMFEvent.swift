/// A DTMF digit received from the remote side.
public struct BaresipDTMFEvent: Sendable, Equatable {
    /// The digit: `0`–`9`, `*`, `#` or `A`–`D`.
    public let digit: Character
    /// `true` when the key was released, `false` when it was pressed.
    public let isEnd: Bool
    /// `true` when the digit arrived as SIP INFO instead of an RTP event.
    public let viaSIPInfo: Bool
}
