import Foundation

/// TLS settings for SIP over TLS.
///
/// The server certificate is always verified: against the system trust store by default, or
/// against ``caCertificatesPEM`` for a private CA or a self-signed server. Add
/// ``pinnedSPKISHA256`` to accept only specific server keys on top of that validation. There is
/// no setting that accepts any certificate; a test server needs its CA in ``caCertificatesPEM``.
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
    }

}
