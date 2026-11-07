import Foundation
import Security

enum CertificateError: LocalizedError {
    case unreadable
    case noCertificate
    case noPrivateKey
    case encryptedKey
    case invalidCertificate

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "The file could not be read."
        case .noCertificate:
            return "The file contains no certificate (expected PEM or DER)."
        case .noPrivateKey:
            return "The client file needs the certificate and its private key in PEM."
        case .encryptedKey:
            return "Encrypted private keys are not supported; export the key without a passphrase."
        case .invalidCertificate:
            return "A certificate in the file is not valid."
        }
    }
}

struct PEMBlock {
    let label: String
    let der: Data
    let encrypted: Bool
}

enum PEM {
    static func blocks(_ data: Data) -> [PEMBlock] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var result: [PEMBlock] = []
        var label: String?
        var body = ""
        var encrypted = false
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("-----BEGIN "), line.hasSuffix("-----") {
                label = String(line.dropFirst(11).dropLast(5))
                body = ""
                encrypted = false
            } else if line.hasPrefix("-----END "), let current = label {
                if let der = Data(base64Encoded: body) {
                    result.append(PEMBlock(label: current, der: der,
                                           encrypted: encrypted || current.hasPrefix("ENCRYPTED")))
                }
                label = nil
            } else if label != nil, line.contains(":") {
                if line.hasPrefix("Proc-Type:") && line.contains("ENCRYPTED") || line.hasPrefix("DEK-Info:") {
                    encrypted = true
                }
            } else if label != nil {
                body += line
            }
        }
        return result
    }

    static func encode(_ der: Data, label: String) -> String {
        let b64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN \(label)-----\n\(b64)\n-----END \(label)-----\n"
    }

    static func caBundle(from data: Data) throws -> Data {
        let certs = blocks(data).filter { $0.label == "CERTIFICATE" }
        let ders: [Data]
        if certs.isEmpty {
            guard SecCertificateCreateWithData(nil, data as CFData) != nil else {
                throw CertificateError.noCertificate
            }
            ders = [data]
        } else {
            ders = certs.map(\.der)
        }
        for der in ders where SecCertificateCreateWithData(nil, der as CFData) == nil {
            throw CertificateError.invalidCertificate
        }
        return Data(ders.map { encode($0, label: "CERTIFICATE") }.joined().utf8)
    }

    static func clientIdentity(from data: Data) throws -> Data {
        let all = blocks(data)
        let certs = all.filter { $0.label == "CERTIFICATE" }
        guard !certs.isEmpty else { throw CertificateError.noCertificate }
        guard let key = all.first(where: { $0.label.hasSuffix("PRIVATE KEY") }) else {
            throw CertificateError.noPrivateKey
        }
        if key.encrypted {
            throw CertificateError.encryptedKey
        }
        for cert in certs where SecCertificateCreateWithData(nil, cert.der as CFData) == nil {
            throw CertificateError.invalidCertificate
        }
        let pem = certs.map { encode($0.der, label: "CERTIFICATE") }.joined()
            + encode(key.der, label: key.label)
        return Data(pem.utf8)
    }

    static func summaries(_ pem: Data?) -> [String] {
        guard let pem else { return [] }
        return blocks(pem)
            .filter { $0.label == "CERTIFICATE" }
            .compactMap { SecCertificateCreateWithData(nil, $0.der as CFData) }
            .map { (SecCertificateCopySubjectSummary($0) as String?) ?? "certificate" }
    }
}
