#if os(iOS)
    import Foundation
    import Intents

    /// A call the user asked for outside the app, for example with a tap on one of the app's calls
    /// in the Recents list of the Phone app.
    ///
    /// iOS hands the request to the app as a user activity. Declare ``activityType`` under
    /// `NSUserActivityTypes` in the Info.plist, read the request from the activity and place the
    /// call the way the app's own call button does:
    ///
    /// ```swift
    /// WindowGroup {
    ///     ContentView()
    ///         .onContinueUserActivity(BaresipRedialRequest.activityType) { activity in
    ///             guard let request = BaresipRedialRequest(activity: activity) else { return }
    ///             Task { try await phone.makeCall(to: request.destination, video: request.video) }
    ///         }
    /// }
    /// ```
    ///
    /// The destination is what the adapter gave CallKit or LiveCommunicationKit for the earlier
    /// call: the SIP URI, or the number with ``BaresipHandleStyle/phoneNumberWhenNumeric``.
    public struct BaresipRedialRequest: Sendable, Equatable {
        /// The type of the user activity that carries a request.
        public static let activityType = "INStartCallIntent"

        /// The SIP URI or number to call.
        public let destination: String
        /// Whether a video call was asked for.
        public let video: Bool

        /// Creates a request.
        ///
        /// - Parameters:
        ///   - destination: The SIP URI or number to call.
        ///   - video: Whether a video call was asked for.
        public init(destination: String, video: Bool) {
            self.destination = destination
            self.video = video
        }

        /// Reads the request from a user activity.
        ///
        /// - Parameter activity: The activity iOS continued the app with.
        /// - Returns: `nil` when the activity asks for no call or names nobody to call.
        public init?(activity: NSUserActivity) {
            guard let intent = activity.interaction?.intent else { return nil }
            self.init(intent: intent)
        }

        init?(intent: INIntent) {
            guard let call = intent as? INStartCallIntent,
                  let destination = call.contacts?.first?.personHandle?.value, !destination.isEmpty else { return nil }
            self.init(destination: destination, video: call.callCapability == .videoCall)
        }
    }
#endif
