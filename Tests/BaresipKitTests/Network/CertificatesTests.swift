import XCTest
@testable import BaresipKit

final class CertificatesTests: XCTestCase {
    // A throwaway self-signed EC certificate and key, generated with openssl for this test only.
    static let certificatePEM = """
    -----BEGIN CERTIFICATE-----
    MIIBgTCCASegAwIBAgIUQk+jbEL0eLViS+P5DkaERSmMpi4wCgYIKoZIzj0EAwIw
    FjEUMBIGA1UEAwwLVGVzdCBDbGllbnQwHhcNMjYxMTEwMDkxMTM0WhcNMzYxMTA3
    MDkxMTM0WjAWMRQwEgYDVQQDDAtUZXN0IENsaWVudDBZMBMGByqGSM49AgEGCCqG
    SM49AwEHA0IABGLCZZcppTxU99zGJA2liw2lFlCA6UjaKOM2NYtRv0OvfiNqKtsB
    F53CIEoY77H6MPHRddqchDAIiASxYsimmrCjUzBRMB0GA1UdDgQWBBS4mkKVqsWc
    9sUaIctevq+DbwZfQjAfBgNVHSMEGDAWgBS4mkKVqsWc9sUaIctevq+DbwZfQjAP
    BgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIEqJZnMoj3URh+rKlQRi
    mtrJ0DKOEsax+mmuXP30lhP0AiEAv17vbWlMsSkHhuRgZS7/MlqYpw9kgi80dS10
    vi5uRpQ=
    -----END CERTIFICATE-----
    """

    static let unencryptedKeyPEM = """
    -----BEGIN EC PRIVATE KEY-----
    MHcCAQEEIHs6FhaxXh0PODRoB9UtIis5SOJzmP+LPOEyttdowrqJoAoGCCqGSM49
    AwEHoUQDQgAEYsJllymlPFT33MYkDaWLDaUWUIDpSNoo4zY1i1G/Q69+I2oq2wEX
    ncIgShjvsfow8dF12pyEMAiIBLFiyKaasA==
    -----END EC PRIVATE KEY-----
    """

    static let encryptedKeyPEM = """
    -----BEGIN EC PRIVATE KEY-----
    Proc-Type: 4,ENCRYPTED
    DEK-Info: AES-256-CBC,EC1479096091C99400BB300630DA5E9F

    veTMkWX5BXESD5eVeXovrkNNJlhMIDmvZMrQlJ3u7pjNfwRFV89mf2EC3p4T5ul6
    MSe+M8ycZUdc0GfvTc/C1B4ehLirf2iIUV8JOKaR5dKP/in3MSSUgrATe+ycAELP
    dnU3pe407GXmqZq3H6Jwyr2bPWXCWGpRTyZr6S7Eucs=
    -----END EC PRIVATE KEY-----
    """

    func testCABundleAcceptsPEMCertificate() throws {
        let pem = try BaresipCertificates.caBundle(from: Data(Self.certificatePEM.utf8))
        XCTAssertEqual(String(data: pem, encoding: .utf8), Self.certificatePEM + "\n")
    }

    func testCABundleAcceptsDERCertificate() throws {
        let der = try derFromFirstBlock(Self.certificatePEM)
        let pem = try BaresipCertificates.caBundle(from: der)
        XCTAssertEqual(String(data: pem, encoding: .utf8), Self.certificatePEM + "\n")
    }

    func testCABundleRejectsGarbage() {
        XCTAssertThrowsError(try BaresipCertificates.caBundle(from: Data("not a cert".utf8))) { error in
            XCTAssertEqual(error as? BaresipCertificateError, .noCertificate)
        }
    }

    func testClientIdentityCombinesCertificateAndKey() throws {
        let data = Data((Self.certificatePEM + "\n" + Self.unencryptedKeyPEM + "\n").utf8)
        let identity = try BaresipCertificates.clientIdentity(from: data)
        let text = String(data: identity, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("BEGIN CERTIFICATE"))
        XCTAssertTrue(text.contains("BEGIN EC PRIVATE KEY"))
    }

    func testClientIdentityRejectsMissingCertificate() {
        let data = Data(Self.unencryptedKeyPEM.utf8)
        XCTAssertThrowsError(try BaresipCertificates.clientIdentity(from: data)) { error in
            XCTAssertEqual(error as? BaresipCertificateError, .noCertificate)
        }
    }

    func testClientIdentityRejectsMissingKey() {
        let data = Data(Self.certificatePEM.utf8)
        XCTAssertThrowsError(try BaresipCertificates.clientIdentity(from: data)) { error in
            XCTAssertEqual(error as? BaresipCertificateError, .noPrivateKey)
        }
    }

    func testClientIdentityRejectsEncryptedKey() {
        let data = Data((Self.certificatePEM + "\n" + Self.encryptedKeyPEM + "\n").utf8)
        XCTAssertThrowsError(try BaresipCertificates.clientIdentity(from: data)) { error in
            XCTAssertEqual(error as? BaresipCertificateError, .encryptedKey)
        }
    }

    func testSplitRoundTrips() throws {
        let data = Data((Self.certificatePEM + "\n" + Self.unencryptedKeyPEM + "\n").utf8)
        let identity = try BaresipCertificates.clientIdentity(from: data)
        let (certificates, key) = BaresipCertificates.split(identity)
        XCTAssertTrue(certificates.contains("BEGIN CERTIFICATE"))
        XCTAssertTrue(key.contains("BEGIN EC PRIVATE KEY"))
    }

    func testSplitOfNilIsEmpty() {
        let (certificates, key) = BaresipCertificates.split(nil)
        XCTAssertEqual(certificates, "")
        XCTAssertEqual(key, "")
    }

    func testSummariesReadsSubject() {
        let summaries = BaresipCertificates.summaries(Data(Self.certificatePEM.utf8))
        XCTAssertEqual(summaries, ["Test Client"])
    }

    func testSummariesOfNilIsEmpty() {
        XCTAssertEqual(BaresipCertificates.summaries(nil), [])
    }

    private func derFromFirstBlock(_ pem: String) throws -> Data {
        let lines = pem.split(separator: "\n").dropFirst().dropLast()
        guard let der = Data(base64Encoded: lines.joined()) else {
            throw XCTSkip("could not decode fixture")
        }
        return der
    }
}
