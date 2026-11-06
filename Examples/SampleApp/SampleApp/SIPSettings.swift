import Foundation
import Security
import BaresipKit

struct SIPSettings: Codable, Equatable {
    var domain = ""
    var port = ""
    var transport: BaresipTransport = .tls
    var username = ""
    var authUser = ""
    var displayName = ""
    var outboundProxy = ""
    var mediaEncryption: BaresipMediaEncryption = .srtpOptional
    var pins = ""
    var useICE = false
    var stunURI = ""
    var turnURI = ""
    var turnUser = ""
    var autoPreview = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SIPSettings.defaults
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        domain = try value(.domain, defaults.domain)
        port = try value(.port, defaults.port)
        transport = try value(.transport, defaults.transport)
        username = try value(.username, defaults.username)
        authUser = try value(.authUser, defaults.authUser)
        displayName = try value(.displayName, defaults.displayName)
        outboundProxy = try value(.outboundProxy, defaults.outboundProxy)
        mediaEncryption = try value(.mediaEncryption, defaults.mediaEncryption)
        pins = try value(.pins, defaults.pins)
        useICE = try value(.useICE, defaults.useICE)
        stunURI = try value(.stunURI, defaults.stunURI)
        turnURI = try value(.turnURI, defaults.turnURI)
        turnUser = try value(.turnUser, defaults.turnUser)
        autoPreview = try value(.autoPreview, defaults.autoPreview)
    }

    private static let defaults = SIPSettings()

    var isComplete: Bool {
        !domain.trimmed.isEmpty && !username.trimmed.isEmpty
    }

    var transportName: String {
        switch transport {
        case .udp: return "udp"
        case .tcp: return "tcp"
        case .tls: return "tls"
        case .wss: return "wss"
        }
    }

    var aor: String {
        "sip:\(username.trimmed)@\(domain.trimmed)"
    }

    var registrar: String {
        let host = domain.trimmed
        let trimmedPort = port.trimmed
        return "sip:\(host)\(trimmedPort.isEmpty ? "" : ":\(trimmedPort)");transport=\(transportName)"
    }

    var proxy: String? {
        let raw = outboundProxy.trimmed
        guard !raw.isEmpty else { return nil }
        if raw.hasPrefix("sip:") || raw.hasPrefix("sips:") {
            return raw
        }
        return "sip:\(raw);transport=\(transportName);lr"
    }

    var pinList: [String] {
        pins.split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == " " })
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SettingsStore {
    private static let settingsKey = "sip.settings"
    private static let passwordAccount = "sip.password"
    private static let turnPasswordAccount = "turn.password"
    private static let caFile = "ca.pem"
    private static let clientFile = "client.pem"

    static func load() -> SIPSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(SIPSettings.self, from: data) else {
            return SIPSettings()
        }
        return settings
    }

    static func save(_ settings: SIPSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    static var password: String {
        get { Keychain.read(passwordAccount) ?? "" }
        set { Keychain.write(passwordAccount, newValue) }
    }

    static var turnPassword: String {
        get { Keychain.read(turnPasswordAccount) ?? "" }
        set { Keychain.write(turnPasswordAccount, newValue) }
    }

    static var caCertificates: Data? {
        get { readFile(caFile) }
        set { writeFile(caFile, newValue) }
    }

    static var clientCertificate: Data? {
        get { readFile(clientFile) }
        set { writeFile(clientFile, newValue) }
    }

    private static func directory() throws -> URL {
        let url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
            .appendingPathComponent("Certificates", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func readFile(_ name: String) -> Data? {
        guard let url = try? directory().appendingPathComponent(name) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func writeFile(_ name: String, _ data: Data?) {
        guard let url = try? directory().appendingPathComponent(name) else { return }
        if let data {
            try? data.write(to: url, options: [.atomic, .completeFileProtection])
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum Keychain {
    private static let service = "com.example.BaresipKitSample"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ account: String, _ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
