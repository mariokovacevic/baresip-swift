import Foundation
import Security

enum SettingsStore {
    private static let settingsKey = "sip.settings"
    private static let passwordAccount = "sip.password"
    private static let turnPasswordAccount = "turn.password"
    private static let caFile = "ca.pem"
    private static let clientFile = "client.pem"
    private static let sipMessageLogKey = "log.sipMessages"

    #if DEBUG
        private static let isUITest = ProcessInfo.processInfo.environment["BSK_UITEST"] == "1"
        private static let logsSIPMessagesByDefault = true
    #else
        private static let isUITest = false
        private static let logsSIPMessagesByDefault = false
    #endif

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

    private static let doorsKey = "doors"

    static var doors: [Door] {
        get {
            guard let data = UserDefaults.standard.data(forKey: doorsKey),
                  let doors = try? JSONDecoder().decode([Door].self, from: data) else { return [] }
            return doors
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: doorsKey)
            }
        }
    }

    private static let instanceKey = "sip.instance"

    static var instanceUUID: UUID {
        if let stored = UserDefaults.standard.string(forKey: instanceKey).flatMap(UUID.init(uuidString:)) {
            return stored
        }
        let created = UUID()
        UserDefaults.standard.set(created.uuidString, forKey: instanceKey)
        return created
    }

    private static let ringtoneKey = "ringtone"

    static var ringtone: Ringtone {
        get { UserDefaults.standard.string(forKey: ringtoneKey).flatMap(Ringtone.init(rawValue:)) ?? .default }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: ringtoneKey) }
    }

    private static let callScreenKey = "callScreen"

    static var callScreen: SystemCallScreen {
        get {
            UserDefaults.standard.string(forKey: callScreenKey).flatMap(SystemCallScreen.init(rawValue:)) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: callScreenKey) }
    }

    private static let contactsKey = "contacts"

    static var contacts: [Contact] {
        get {
            guard let data = UserDefaults.standard.data(forKey: contactsKey),
                  let contacts = try? JSONDecoder().decode([Contact].self, from: data) else { return [] }
            return contacts
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: contactsKey)
            }
        }
    }

    private static let historyKey = "call.history"
    static let historyLimit = 200

    static var history: [CallRecord] {
        get {
            guard let data = UserDefaults.standard.data(forKey: historyKey),
                  let records = try? JSONDecoder().decode([CallRecord].self, from: data) else { return [] }
            return records
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue.prefix(historyLimit))) {
                UserDefaults.standard.set(data, forKey: historyKey)
            }
        }
    }

    static var logsSIPMessages: Bool {
        get { UserDefaults.standard.object(forKey: sipMessageLogKey) as? Bool ?? logsSIPMessagesByDefault }
        set { UserDefaults.standard.set(newValue, forKey: sipMessageLogKey) }
    }

    static var caCertificates: Data? {
        readFile(caFile)
    }

    static var clientCertificate: Data? {
        readFile(clientFile)
    }

    static func storeCACertificates(_ data: Data) {
        writeFile(caFile, data)
    }

    static func storeClientCertificate(_ data: Data) {
        writeFile(clientFile, data)
    }

    static func removeCACertificates() {
        removeFile(caFile)
    }

    static func removeClientCertificate() {
        removeFile(clientFile)
    }

    private static func certificateRoot() throws -> URL {
        if isUITest {
            return FileManager.default.temporaryDirectory.appendingPathComponent("UITest", isDirectory: true)
        }
        return try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                           appropriateFor: nil, create: true)
    }

    private static func directory() throws -> URL {
        var url = try certificateRoot().appendingPathComponent("Certificates", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }

    private static func readFile(_ name: String) -> Data? {
        guard let url = try? directory().appendingPathComponent(name),
              let data = try? Data(contentsOf: url) else { return nil }
        allowReadingAfterFirstUnlock(url)
        return data
    }

    private static func allowReadingAfterFirstUnlock(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    private static func writeFile(_ name: String, _ data: Data) {
        guard let url = try? directory().appendingPathComponent(name) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func removeFile(_ name: String) {
        guard let url = try? directory().appendingPathComponent(name) else { return }
        try? FileManager.default.removeItem(at: url)
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
