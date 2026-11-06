/// The registration state of an account.
public enum BaresipRegistrationState: Int, Sendable, Codable {
    /// The account is not registered and no registration is in progress.
    case none = 0
    /// A REGISTER request is in progress.
    case registering = 1
    /// The registrar accepted the registration.
    case registered = 2
    /// The account is removing its registration.
    case unregistering = 3
    /// The last registration attempt failed; the engine retries with back-off.
    case failed = 4
}
