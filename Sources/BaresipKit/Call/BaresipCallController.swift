/// Carries out the user's call actions through a system call interface, such as CallKit.
///
/// With CallKit, an app must not answer, end, hold or mute a call on the engine directly:
/// the system call screen would keep ringing or show a different state, and only CallKit may
/// activate the audio session. A controller takes these actions instead and performs them on the
/// engine once the system agrees. `BaresipCallKitAdapter` is a controller.
///
/// `BaresipPhone` in `BaresipKitSwiftUI` uses a controller when one is set and the controller
/// ``controls(_:)`` the call, and the engine otherwise. Leave it unset to call the engine
/// directly, for example in the simulator, where CallKit does not activate the audio session.
///
/// The SDK's adapters implement this protocol; apps use it and do not implement it. Requirements
/// may be added to it in a minor release, so a type outside BaresipKit that conforms to it can
/// stop compiling.
public protocol BaresipCallController: AnyObject, Sendable {
    /// Whether the call is shown by the system call interface, so its actions go through the
    /// controller.
    ///
    /// - Parameter call: The engine call.
    /// - Returns: `true` when the controller knows the call.
    func controls(_ call: BaresipCallID) -> Bool

    /// Places a call through the system call interface.
    ///
    /// - Parameters:
    ///   - destination: A SIP URI, user name or number.
    ///   - video: Whether to send the camera.
    /// - Returns: The engine call, once the engine has placed it.
    /// - Throws: The system's error when it refuses the call, or ``BaresipError`` when the
    ///   engine cannot place it.
    func placeCall(to destination: String, video: Bool) async throws -> BaresipCallID

    /// Answers a call through the system call interface.
    ///
    /// - Parameters:
    ///   - call: The ringing call.
    ///   - video: Whether to send the camera.
    /// - Throws: The system's error when it refuses the request.
    func answer(_ call: BaresipCallID, video: Bool) async throws

    /// Ends or declines a call through the system call interface.
    ///
    /// - Parameter call: The call.
    /// - Throws: The system's error when it refuses the request.
    func end(_ call: BaresipCallID) async throws

    /// Holds or resumes a call through the system call interface.
    ///
    /// - Parameters:
    ///   - onHold: `true` to hold.
    ///   - call: The call.
    /// - Throws: The system's error when it refuses the request.
    func setOnHold(_ onHold: Bool, call: BaresipCallID) async throws

    /// Mutes or unmutes a call through the system call interface.
    ///
    /// - Parameters:
    ///   - muted: `true` to mute.
    ///   - call: The call.
    /// - Throws: The system's error when it refuses the request.
    func setMuted(_ muted: Bool, call: BaresipCallID) async throws

    /// Adds an observer called after a call was muted or unmuted through the controller, also
    /// from the system call screen.
    ///
    /// The engine reports no event for muting, so this keeps a mute button in step. The observer
    /// runs on an arbitrary thread and stays registered for the controller's lifetime.
    ///
    /// - Parameter observer: Called with the call and whether it is muted now.
    func addMuteObserver(_ observer: @escaping @Sendable (BaresipCallID, Bool) -> Void)
}
