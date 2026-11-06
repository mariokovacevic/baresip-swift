import Foundation

extension BaresipEngine {
    /// Mutes or unmutes the microphone for a call.
    ///
    /// - Parameters:
    ///   - muted: `true` to send silence.
    ///   - callID: The call.
    /// - Throws: ``BaresipError`` for an unknown call.
    public func setMicrophoneMuted(_ muted: Bool, callID: BaresipCallID) async throws {
        try await run { try $0.setMicrophoneMuted(callID, muted) }
    }

    /// Changes the audio direction of a call with a re-INVITE.
    ///
    /// - Parameters:
    ///   - direction: The new direction.
    ///   - callID: The call.
    /// - Throws: ``BaresipError`` when the call is not established.
    public func setAudioDirection(_ direction: BaresipMediaDirection, callID: BaresipCallID) async throws {
        try await run { try $0.setAudioDirection(callID, direction) }
    }

    /// Changes the video direction of a call with a re-INVITE.
    ///
    /// - Parameters:
    ///   - direction: The new direction.
    ///   - callID: The call.
    /// - Throws: ``BaresipError`` when the call is not established.
    public func setVideoDirection(_ direction: BaresipMediaDirection, callID: BaresipCallID) async throws {
        try await run { try $0.setVideoDirection(callID, direction) }
    }

    /// Turns video on (send and receive) or off (inactive) for a call.
    ///
    /// - Parameters:
    ///   - enabled: Whether video is on.
    ///   - callID: The call.
    /// - Throws: ``BaresipError`` when the call is not established.
    public func setVideoEnabled(_ enabled: Bool, callID: BaresipCallID) async throws {
        try await setVideoDirection(enabled ? .sendReceive : .inactive, callID: callID)
    }

    /// Switches the camera used for a call, for example to the back camera.
    ///
    /// - Parameters:
    ///   - device: A device name from ``videoDevices()``.
    ///   - callID: The call.
    /// - Throws: ``BaresipError`` for an unknown call or device.
    public func setCamera(_ device: String, callID: BaresipCallID) async throws {
        try await run { try $0.setCamera(callID, device: device) }
    }

    /// Asks the encoder to send a keyframe.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` when the call has no video.
    public func requestKeyframe(callID: BaresipCallID) async throws {
        try await run { try $0.requestKeyframe(callID) }
    }

    /// Caps the video bitrate of a call, below the engine's configured bitrate.
    ///
    /// - Parameters:
    ///   - callID: The call.
    ///   - bitsPerSecond: The cap, or `nil` to remove it.
    /// - Throws: ``BaresipError`` for an unknown call.
    public func setVideoMaxBitrate(callID: BaresipCallID, bitsPerSecond: Int?) async throws {
        let cap = UInt32(clamping: max(0, bitsPerSecond ?? 0))
        try await run { try $0.setVideoMaxBitrate(callID, bitsPerSecond: cap) }
    }

    /// Starts recording a call to a 16-bit stereo WAV file.
    ///
    /// The left channel is the microphone and the right channel the remote party. Recording
    /// continues through hold and re-INVITEs and stops with ``stopRecording(callID:)`` or when
    /// the call ends. ``BaresipMediaEvent/recordingStarted`` and
    /// ``BaresipMediaEvent/recordingStopped`` report the state. Check local law before
    /// recording calls.
    ///
    /// - Parameters:
    ///   - callID: The call.
    ///   - fileURL: A file URL the app can write; an existing file is replaced.
    /// - Throws: ``BaresipError`` when the call is unknown, already recording, or the file
    ///   cannot be created.
    public func startRecording(callID: BaresipCallID, to fileURL: URL) async throws {
        let path = fileURL.path
        try await run { try $0.startRecording(callID, path: path) }
    }

    /// Stops recording and completes the file.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` when the call is not recording.
    public func stopRecording(callID: BaresipCallID) async throws {
        try await run { try $0.stopRecording(callID) }
    }
}
