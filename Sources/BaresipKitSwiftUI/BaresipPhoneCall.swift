import Combine
import Foundation
import BaresipKit

/// One call as observable state for SwiftUI, with the actions a call screen needs.
///
/// ``BaresipPhone`` creates the calls and keeps their state current. The actions forward to
/// the phone's ``BaresipPhone/callController`` when it controls the call, such as CallKit, and to
/// the engine otherwise; the published state follows from the engine's events, so a button only
/// needs to call the action and read the state. ``state`` comes from the engine's events, and
/// from the engine's own view of the call each time ``BaresipPhone/run()`` starts; the other
/// properties are read from the engine after every state and media change.
@MainActor
public final class BaresipPhoneCall: ObservableObject, Identifiable {
    /// The call's identifier.
    public let id: BaresipCallID

    /// When the phone first saw the call.
    public let startedAt = Date()

    /// The call's state.
    @Published public private(set) var state: BaresipCallState

    /// The last error of the call: why it failed, or why the other side rejected a hold, resume
    /// or direction change.
    @Published public private(set) var error: BaresipError?

    /// The other side's SIP URI.
    @Published public private(set) var remoteURI = ""

    /// The other side's display name, or an empty string.
    @Published public private(set) var remoteDisplayName = ""

    /// Whether this side placed the call. Valid when ``isDirectionKnown`` is `true`.
    @Published public private(set) var isOutgoing = false

    /// Whether the call's direction is known yet.
    ///
    /// A call first seen in early media is known only after its details were read.
    @Published public private(set) var isDirectionKnown = false

    /// Whether the call has a video stream.
    @Published public private(set) var hasVideo = false

    /// Whether the microphone is muted.
    @Published public private(set) var isMuted = false

    /// The negotiated audio direction.
    @Published public private(set) var audioDirection: BaresipMediaDirection = .inactive

    /// The negotiated video direction.
    @Published public private(set) var videoDirection: BaresipMediaDirection = .inactive

    /// The audio codec in use, or an empty string.
    @Published public private(set) var audioCodec = ""

    /// The video codec in use, or an empty string.
    @Published public private(set) var videoCodec = ""

    /// When the call was first connected, or `nil` before that.
    @Published public private(set) var connectedAt: Date?

    /// Whether the camera is sent.
    ///
    /// Before the call is answered it is what the call was placed with, or `false` for an
    /// incoming call; afterwards it follows ``setVideoEnabled(_:)`` and the negotiated direction.
    @Published public private(set) var isSendingVideo = false

    /// The camera the call sends, as last set with ``setCamera(_:)``.
    @Published public private(set) var camera: BaresipCameraPosition

    /// Whether an early media preview of the ringing call runs; see ``startPreview(video:audio:)``.
    @Published public private(set) var isPreviewing = false

    /// The DTMF digits received from the other side, in order.
    @Published public private(set) var receivedDTMF = ""

    weak var phone: BaresipPhone?

    /// The engine of the call.
    public let engine: BaresipEngine
    private var refreshGeneration = 0
    var dtmfListeners: [UUID: AsyncStream<Character>.Continuation] = [:]

    init(id: BaresipCallID, state: BaresipCallState, engine: BaresipEngine) {
        self.id = id
        self.state = state
        self.engine = engine
        camera = engine.configuration.video.sourceDevice == BaresipCameraPosition.back.deviceName ? .back : .front
        inferDirection(from: state)
        noteConnected()
    }

    /// Whether the call rings on this side and is not answered yet.
    public var isRinging: Bool {
        guard isDirectionKnown, !isOutgoing else { return false }
        return state == .incoming || state == .earlyMedia
    }

    /// Whether the call is on hold on this side, including while it is put on hold or resumed.
    public var isOnHold: Bool {
        state == .pausing || state == .paused || state == .resuming
    }

    /// Whether the other side put the call on hold.
    public var isHeldByRemote: Bool {
        state == .pausedByRemote
    }

    /// Whether audio and video are flowing.
    public var isConnected: Bool {
        state == .connected || state == .streamsRunning || state == .updating
    }

    /// Whether the other side's video reaches this side, early media included.
    public var isReceivingVideo: Bool {
        videoDirection == .receiveOnly || videoDirection == .sendReceive
    }

    /// The display name, or the user part of the SIP URI when there is none.
    public var displayName: String {
        remoteDisplayName.isEmpty ? BaresipPhoneCall.userPart(of: remoteURI) : remoteDisplayName
    }

    /// Answers an incoming call, through the phone's call controller when it controls the call.
    ///
    /// The phone makes the call its ``BaresipPhone/activeCall``. A call controller answers with
    /// audio; with `audio: false` the engine answers directly.
    ///
    /// - Parameters:
    ///   - video: Whether to send the camera; the caller's video is received either way.
    ///   - audio: Whether to open the microphone and play the caller's audio.
    /// - Throws: `BaresipError` when the call cannot be answered, or the controller's error.
    public func answer(video: Bool = false, audio: Bool = true) async throws {
        if audio, let controller {
            try await controller.answer(id, video: video)
        } else {
            try await engine.answer(callID: id, video: video, audio: audio)
        }
        isSendingVideo = video
        isPreviewing = false
        await phone?.callWasAnswered(self)
    }

    /// Starts an early media preview: the caller is seen and heard, but does not see or hear
    /// this side until the call is answered.
    ///
    /// With a call controller such as CallKit, iOS activates the audio session only when the call
    /// is answered, so preview audio is heard only without one.
    ///
    /// - Parameters:
    ///   - video: Whether to receive the caller's video.
    ///   - audio: Whether to receive the caller's audio.
    /// - Throws: `BaresipError` when the call is not ringing.
    public func startPreview(video: Bool = true, audio: Bool = true) async throws {
        try await engine.sendProgress(callID: id, earlyVideo: video, earlyAudio: audio)
        isPreviewing = true
        refresh()
    }

    /// Declines an incoming call: through the call controller when it controls the call, and with
    /// 486 Busy Here otherwise.
    ///
    /// - Throws: `BaresipError` when the call cannot be declined, or the controller's error.
    public func reject() async throws {
        if let controller {
            try await controller.end(id)
        } else {
            try await engine.reject(callID: id)
        }
    }

    /// Ends the call.
    ///
    /// - Throws: `BaresipError` when the call is already gone, or the controller's error.
    public func hangUp() async throws {
        if let controller {
            try await controller.end(id)
        } else {
            try await engine.hangUp(callID: id)
        }
    }

    /// Mutes or unmutes the microphone.
    ///
    /// Through a call controller, ``isMuted`` changes when the controller reports that the
    /// microphone was muted, not when the request was accepted.
    ///
    /// - Parameter muted: `true` to mute.
    /// - Throws: `BaresipError` when the call is gone, or the controller's error.
    public func setMuted(_ muted: Bool) async throws {
        if let controller {
            try await controller.setMuted(muted, call: id)
        } else {
            try await engine.setMicrophoneMuted(muted, callID: id)
            applyMuted(muted)
        }
    }

    /// Puts the call on hold or resumes it.
    ///
    /// - Parameter onHold: `true` to hold.
    /// - Throws: `BaresipError` when the call cannot change, or the controller's error.
    public func setOnHold(_ onHold: Bool) async throws {
        if let controller {
            try await controller.setOnHold(onHold, call: id)
        } else if onHold {
            try await engine.hold(callID: id)
        } else {
            try await engine.resume(callID: id)
        }
    }

    /// Starts or stops sending the camera. The other side's video keeps playing either way.
    ///
    /// - Parameter enabled: Whether the camera is sent.
    /// - Throws: `BaresipError` when the call is not established.
    public func setVideoEnabled(_ enabled: Bool) async throws {
        let previous = isSendingVideo
        isSendingVideo = enabled
        do {
            try await engine.setVideoEnabled(enabled, callID: id)
        } catch {
            isSendingVideo = previous
            throw error
        }
        refresh()
    }

    /// Sends the front or back camera.
    ///
    /// - Parameter position: The camera.
    /// - Throws: `BaresipError` when the call is gone.
    public func setCamera(_ position: BaresipCameraPosition) async throws {
        try await engine.setCamera(position, callID: id)
        camera = position
    }

    /// Switches between the front and back camera.
    ///
    /// - Throws: `BaresipError` when the call is gone.
    public func switchCamera() async throws {
        try await setCamera(camera.toggled)
    }

    /// Sends DTMF digits.
    ///
    /// - Parameter digits: Digits from `0`–`9`, `*`, `#` and `A`–`D`.
    /// - Throws: `BaresipError` when the call is gone or a digit is invalid.
    public func sendDTMF(_ digits: String) async throws {
        try await engine.sendDTMF(callID: id, digits: digits)
    }

    /// Reads the call's details from the engine again.
    ///
    /// ``BaresipPhone`` calls this after every state and media change. A read that a newer read
    /// or a mute or video change overtook is dropped.
    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let engine = engine
        let id = id
        Task { [weak self] in
            guard let info = try? await engine.callInfo(callID: id), let self,
                  generation == refreshGeneration else { return }
            update(with: info)
        }
    }

    private var controller: BaresipCallController? {
        guard let controller = phone?.callController, controller.controls(id) else { return nil }
        return controller
    }

    func update(state: BaresipCallState, error: BaresipError?) {
        self.state = state
        inferDirection(from: state)
        noteConnected()
        if isConnected || state == .released {
            isPreviewing = false
        }
        if let error {
            self.error = error
        }
    }

    func update(with info: BaresipCallInfo) {
        remoteURI = info.remoteURI
        remoteDisplayName = info.remoteDisplayName
        isOutgoing = info.isOutgoing
        isDirectionKnown = true
        hasVideo = info.hasVideo
        isMuted = info.isMicrophoneMuted
        audioDirection = info.audioDirection
        videoDirection = info.videoDirection
        audioCodec = info.audioCodec
        videoCodec = info.videoCodec
        // Before the answer the direction says nothing about the camera, and on hold it is
        // reduced for a while; keep the last known value then.
        if isConnected {
            isSendingVideo = info.videoDirection == .sendOnly || info.videoDirection == .sendReceive
        }
    }

    func markOutgoing(to destination: String, video: Bool = false) {
        isOutgoing = true
        isDirectionKnown = true
        isSendingVideo = video
        if remoteURI.isEmpty {
            remoteURI = destination
        }
    }

    func applyMuted(_ muted: Bool) {
        refreshGeneration += 1
        isMuted = muted
    }

    func didReceiveDTMF(_ digit: Character) {
        receivedDTMF.append(digit)
        for listener in dtmfListeners.values {
            listener.yield(digit)
        }
    }

    private func noteConnected() {
        if connectedAt == nil, isConnected {
            connectedAt = Date()
        }
    }

    private func inferDirection(from state: BaresipCallState) {
        guard !isDirectionKnown else { return }
        switch state {
        case .incoming:
            isOutgoing = false
            isDirectionKnown = true
        case .outgoingInit, .outgoingRinging:
            isOutgoing = true
            isDirectionKnown = true
        default:
            break
        }
    }
}
