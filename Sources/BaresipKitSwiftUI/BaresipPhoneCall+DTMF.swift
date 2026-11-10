import Foundation
import BaresipKit

extension BaresipPhoneCall {
    /// Sends DTMF digits and waits for the other side to answer with a digit, as door stations do
    /// to confirm that the door opened.
    ///
    /// - Parameters:
    ///   - digits: Digits from `0`–`9`, `*`, `#` and `A`–`D`.
    ///   - reply: The digit that confirms the request.
    ///   - timeout: How long to wait for a reply after the digits were sent.
    /// - Returns: Whether the expected digit, another digit or nothing arrived.
    /// - Throws: `BaresipError` when the call is gone or a digit is invalid.
    public func sendDTMF(_ digits: String, expectingReply reply: Character,
                         timeout: Duration = .seconds(5)) async throws -> BaresipDTMFReply {
        let engine = engine
        let id = id
        return try await sendDTMF(digits, expectingReply: reply, timeout: timeout) { digits in
            try await engine.sendDTMF(callID: id, digits: digits)
        }
    }

    /// Sends with `send` and waits for the reply; the listener is in place before sending, so a
    /// fast reply is not missed.
    func sendDTMF(_ digits: String, expectingReply reply: Character, timeout: Duration,
                  send: (String) async throws -> Void) async throws -> BaresipDTMFReply {
        let (stream, continuation) = AsyncStream.makeStream(of: Character.self)
        let listener = UUID()
        dtmfListeners[listener] = continuation
        defer {
            dtmfListeners[listener] = nil
            continuation.finish()
        }
        try await send(digits)
        return await withTaskGroup(of: BaresipDTMFReply.self) { group in
            group.addTask {
                for await digit in stream {
                    return digit == reply ? .confirmed : .other(digit)
                }
                return .noReply
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .noReply
            }
            let first = await group.next() ?? .noReply
            group.cancelAll()
            continuation.finish()
            return first
        }
    }
}

extension BaresipPhoneCall {
    /// The user or number of a SIP URI, such as `alice` for `sip:alice@example.com;transport=tls`.
    ///
    /// - Parameter uri: A SIP URI.
    /// - Returns: The user part, or the URI itself when it has none.
    public nonisolated static func userPart(of uri: String) -> String {
        var value = uri
        for scheme in ["sips:", "sip:", "tel:"] where value.hasPrefix(scheme) {
            value = String(value.dropFirst(scheme.count))
        }
        if let semicolon = value.firstIndex(of: ";") {
            value = String(value[..<semicolon])
        }
        if let at = value.firstIndex(of: "@") {
            value = String(value[..<at])
        }
        return value.isEmpty ? uri : value
    }
}

/// The other side's answer to DTMF sent with ``BaresipPhoneCall/sendDTMF(_:expectingReply:timeout:)``.
public enum BaresipDTMFReply: Sendable, Equatable {
    /// The expected digit arrived.
    case confirmed
    /// Another digit arrived first.
    case other(Character)
    /// No digit arrived in time.
    case noReply
}
