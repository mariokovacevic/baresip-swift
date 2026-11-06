import Foundation

/// TLS settings for SIP over TLS.
///
/// By default the server certificate is verified against the system trust store. Add
/// ``caCertificatesPEM`` for a private CA or a self-signed server, and ``pinnedSPKISHA256``
/// to accept only specific server keys on top of normal validation.
public struct BaresipTLSConfiguration: Sendable, Equatable {
    /// Extra trusted CA certificates in PEM format.
    public var caCertificatesPEM: Data?
    /// A client certificate followed by its private key, in PEM format, for mutual TLS.
    public var clientCertificatePEM: Data?
    /// Base64-encoded SHA-256 hashes of accepted server SubjectPublicKeyInfo structures.
    public var pinnedSPKISHA256: [String]
    /// An OpenSSL cipher list, or `nil` for the core's default.
    public var cipherList: String?
    /// The lowest accepted TLS version.
    public var minimumVersion: TLSVersion
    /// Whether the server certificate is verified. Always `true` in release builds.
    public var verifyServer: Bool

    /// A TLS protocol version.
    public enum TLSVersion: Int, Sendable, Codable {
        /// TLS 1.2.
        case tls12 = 0x0303
        /// TLS 1.3.
        case tls13 = 0x0304
    }

    /// Creates TLS settings that verify the server.
    ///
    /// - Parameters:
    ///   - caCertificatesPEM: Extra trusted CA certificates in PEM format.
    ///   - clientCertificatePEM: A client certificate and key in PEM format.
    ///   - pinnedSPKISHA256: Accepted server key hashes.
    ///   - cipherList: An OpenSSL cipher list.
    ///   - minimumVersion: The lowest accepted TLS version.
    public init(caCertificatesPEM: Data? = nil, clientCertificatePEM: Data? = nil,
                pinnedSPKISHA256: [String] = [], cipherList: String? = nil,
                minimumVersion: TLSVersion = .tls12) {
        self.caCertificatesPEM = caCertificatesPEM
        self.clientCertificatePEM = clientCertificatePEM
        self.pinnedSPKISHA256 = pinnedSPKISHA256
        self.cipherList = cipherList
        self.minimumVersion = minimumVersion
        self.verifyServer = true
    }

    #if DEBUG
    /// Settings that accept any server certificate. Only available in debug builds.
    ///
    /// - Returns: TLS settings with verification turned off.
    public static func insecureSkippingServerVerification() -> BaresipTLSConfiguration {
        var configuration = BaresipTLSConfiguration()
        configuration.verifyServer = false
        return configuration
    }
    #endif
}
