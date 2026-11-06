/// A parameter added to the SIP `Contact` header of an account's REGISTER requests.
///
/// Use contact parameters for RFC 8599 push notification routing (`pn-provider`, `pn-prid`,
/// `pn-param`) or for registrar-specific parameters. Names and values are validated: they
/// must be SIP tokens and must not contain separators such as `;` or spaces.
///
/// ```swift
/// let parameters = [
///     BaresipContactParameter("pn-provider", "apns"),
///     BaresipContactParameter("pn-prid", voipToken),
/// ]
/// ```
public struct BaresipContactParameter: Hashable, Sendable, Codable {
    /// The parameter name.
    public let name: String
    /// The parameter value, or `nil` for a flag parameter without a value.
    public let value: String?

    /// Creates a parameter.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The value, or `nil` for a flag parameter.
    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }

    /// Creates a parameter with a value.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The value.
    public init(_ name: String, _ value: String) {
        self.init(name: name, value: value)
    }
}

/// The previous name of ``BaresipContactParameter``.
@available(*, deprecated, renamed: "BaresipContactParameter")
public typealias ContactParameter = BaresipContactParameter
