import Foundation
import Security

/// An error from ``BaresipCertificates``.
public enum BaresipCertificateError: Error, Equatable, Sendable {
    /// The file could not be read.
    case unreadable
    /// No certificate was found (expected PEM or DER).
    case noCertificate
    /// A client certificate needs its private key, in PEM.
    case noPrivateKey
    /// The private key is encrypted; only unencrypted keys are supported.
    case encryptedKey
    /// A certificate is not valid.
    case invalidCertificate
}

extension BaresipCertificateError: LocalizedError {
    /// A sentence to show the user.
    public var errorDescription: String? {
        switch self {
        case .unreadable:
            return "The file could not be read."
        case .noCertificate:
            return "No certificate found (expected PEM or DER)."
        case .noPrivateKey:
            return "The client certificate needs its private key, in PEM."
        case .encryptedKey:
            return "Encrypted private keys are not supported; export the key without a passphrase."
        case .invalidCertificate:
            return "A certificate is not valid."
        }
    }
}

/// Parses and validates PEM-encoded certificates and keys for ``BaresipTLSConfiguration``.
///
/// The results are exactly the PEM that ``BaresipTLSConfiguration/caCertificatesPEM`` and
/// ``BaresipTLSConfiguration/clientCertificatePEM`` accept.
public enum BaresipCertificates {
    /// One decoded `-----BEGIN label-----` block.
    struct Block {
        let label: String
        let der: Data
        let encrypted: Bool
    }

    private static let beginMarker = "-----BEGIN "
    private static let markerEnd = "-----"

    private static func separatingMarkers(_ text: String) -> String {
        text.replacingOccurrences(of: "-----(BEGIN|END) [A-Z0-9 ]+-----", with: "\n$0\n",
                                  options: .regularExpression)
    }

    /// Decodes every PEM block in `data`, in order.
    static func blocks(_ data: Data) -> [Block] {
        guard let raw = String(data: data, encoding: .utf8) else { return [] }
        let text = separatingMarkers(raw)
        var result: [Block] = []
        var label: String?
        var body = ""
        var encrypted = false
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(beginMarker), line.hasSuffix(markerEnd) {
                label = String(line.dropFirst(beginMarker.count).dropLast(markerEnd.count))
                body = ""
                encrypted = false
            } else if line.hasPrefix("-----END "), let current = label {
                if let der = Data(base64Encoded: body) {
                    result.append(Block(label: current, der: der,
                                        encrypted: encrypted || current.hasPrefix("ENCRYPTED")))
                }
                label = nil
            } else if label != nil, line.contains(":") {
                if line.hasPrefix("Proc-Type:") && line.contains("ENCRYPTED") || line.hasPrefix("DEK-Info:") {
                    encrypted = true
                }
            } else if label != nil {
                body += line.filter { !$0.isWhitespace }
            }
        }
        return result
    }

    private static func encode(_ der: Data, label: String) -> String {
        let b64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN \(label)-----\n\(b64)\n-----END \(label)-----\n"
    }

    /// Validates a CA bundle and returns it as PEM for ``BaresipTLSConfiguration/caCertificatesPEM``.
    ///
    /// `data` may already be PEM (one or more `CERTIFICATE` blocks) or a single DER certificate.
    ///
    /// - Throws: ``BaresipCertificateError/noCertificate`` when no certificate is found, or
    ///   ``BaresipCertificateError/invalidCertificate`` when one does not parse.
    public static func caBundle(from data: Data) throws -> Data {
        let certs = blocks(data).filter { $0.label == "CERTIFICATE" }
        let ders: [Data]
        if certs.isEmpty {
            guard SecCertificateCreateWithData(nil, data as CFData) != nil else {
                throw BaresipCertificateError.noCertificate
            }
            ders = [data]
        } else {
            ders = certs.map(\.der)
        }
        for der in ders where SecCertificateCreateWithData(nil, der as CFData) == nil {
            throw BaresipCertificateError.invalidCertificate
        }
        return Data(ders.map { encode($0, label: "CERTIFICATE") }.joined().utf8)
    }

    /// Validates a client identity (certificates plus an unencrypted private key) and returns
    /// it as PEM for ``BaresipTLSConfiguration/clientCertificatePEM``.
    ///
    /// - Throws: ``BaresipCertificateError/noCertificate`` when no certificate is found,
    ///   ``BaresipCertificateError/noPrivateKey`` when no private key is found,
    ///   ``BaresipCertificateError/encryptedKey`` when the key is encrypted, or
    ///   ``BaresipCertificateError/invalidCertificate`` when a certificate does not parse.
    public static func clientIdentity(from data: Data) throws -> Data {
        let all = blocks(data)
        let certs = all.filter { $0.label == "CERTIFICATE" }
        guard !certs.isEmpty else { throw BaresipCertificateError.noCertificate }
        guard let key = all.first(where: { $0.label.hasSuffix("PRIVATE KEY") }) else {
            throw BaresipCertificateError.noPrivateKey
        }
        if key.encrypted {
            throw BaresipCertificateError.encryptedKey
        }
        for cert in certs where SecCertificateCreateWithData(nil, cert.der as CFData) == nil {
            throw BaresipCertificateError.invalidCertificate
        }
        let pem = certs.map { encode($0.der, label: "CERTIFICATE") }.joined()
            + encode(key.der, label: key.label)
        return Data(pem.utf8)
    }

    /// Splits a client identity, as returned by ``clientIdentity(from:)``, back into its
    /// certificate and key text, for editing.
    ///
    /// - Parameter identity: A client identity, or `nil`.
    /// - Returns: The certificate PEM and the key PEM, each empty when `identity` is `nil`.
    public static func split(_ identity: Data?) -> (certificates: String, key: String) {
        guard let identity else { return ("", "") }
        let all = blocks(identity)
        let certs = all.filter { $0.label == "CERTIFICATE" }.map { encode($0.der, label: $0.label) }.joined()
        let key = all.first { $0.label.hasSuffix("PRIVATE KEY") }.map { encode($0.der, label: $0.label) } ?? ""
        return (certs, key)
    }

    /// Human-readable subject summaries of the certificates in `pem`, for display.
    ///
    /// - Parameter pem: A CA bundle or client identity, or `nil`.
    public static func summaries(_ pem: Data?) -> [String] {
        guard let pem else { return [] }
        return blocks(pem)
            .filter { $0.label == "CERTIFICATE" }
            .compactMap { SecCertificateCreateWithData(nil, $0.der as CFData) }
            .map { (SecCertificateCopySubjectSummary($0) as String?) ?? "certificate" }
    }
}
