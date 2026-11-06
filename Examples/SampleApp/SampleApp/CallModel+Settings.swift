import Foundation
import BaresipKit

extension CallModel {
    func importCA(from url: URL) {
        do {
            let data = try readSecurityScoped(url)
            caCertificates = try PEM.caBundle(from: data)
            append("CA imported: \(caSummaries.joined(separator: ", "))")
        } catch {
            append("CA import failed: \(error.localizedDescription)")
        }
    }

    func importClientCertificate(from url: URL) {
        do {
            let data = try readSecurityScoped(url)
            clientCertificate = try PEM.clientIdentity(from: data)
            append("client certificate imported: \(clientSummaries.first ?? "")")
        } catch {
            append("client certificate import failed: \(error.localizedDescription)")
        }
    }

    func removeCA() {
        caCertificates = nil
    }

    func removeClientCertificate() {
        clientCertificate = nil
    }

    func saveAndRegister() async {
        SettingsStore.save(settings)
        SettingsStore.password = password
        SettingsStore.turnPassword = turnPassword
        SettingsStore.caCertificates = caCertificates
        SettingsStore.clientCertificate = clientCertificate
        if currentCall != nil {
            pendingApply = true
            append("settings saved; they apply after the current call")
            return
        }
        await applySaved()
    }

    func applySaved() async {
        if savedTLS != engineTLS {
            await restartEngine()
        }
        await register()
    }

    func register() async {
        guard let engine else { return }
        let saved = SettingsStore.load()
        guard saved.isComplete else {
            registrationError = "Domain and username are required."
            return
        }
        registrationError = nil
        do {
            if let accountID {
                try? await engine.unregister(accountID: accountID)
                try await engine.removeAccount(accountID)
                self.accountID = nil
            }
            let id = try await engine.addAccount(accountConfiguration(saved, password: SettingsStore.password,
                                                                      turnPassword: SettingsStore.turnPassword))
            accountID = id
            registeredSettings = saved
            push?.bind(accountID: id)
            try await engine.register(accountID: id)
            append("registering \(saved.aor) via \(saved.registrar)")
        } catch {
            registrationError = "\(error)"
            append("register failed: \(error)")
        }
    }

    func unregister() async {
        guard let engine, let accountID else { return }
        try? await engine.unregister(accountID: accountID)
    }

    var savedTLS: TLSSnapshot {
        TLSSnapshot(ca: SettingsStore.caCertificates, client: SettingsStore.clientCertificate,
                    pins: SettingsStore.load().pinList)
    }

    func accountConfiguration(_ settings: SIPSettings, password: String,
                              turnPassword: String) -> BaresipAccountConfiguration {
        var nat = BaresipNATConfiguration()
        if settings.useICE {
            nat.mode = .ice
            if !settings.stunURI.trimmed.isEmpty {
                nat.stunURI = settings.stunURI.trimmed
            }
            if !settings.turnURI.trimmed.isEmpty {
                let turnUser = settings.turnUser.trimmed
                let server = BaresipTURNServer(uri: settings.turnURI.trimmed,
                                               username: turnUser.isEmpty ? nil : turnUser,
                                               password: turnPassword.isEmpty ? nil : turnPassword)
                nat.turnServers = [server]
            }
        }
        let authUser = settings.authUser.trimmed.isEmpty ? settings.username.trimmed : settings.authUser.trimmed
        return BaresipAccountConfiguration(aor: settings.aor,
                                           displayName: settings.displayName.trimmed.isEmpty ? nil : settings
                                               .displayName.trimmed,
                                           registrar: settings.registrar,
                                           outboundProxy: settings.proxy,
                                           transport: settings.transport,
                                           authUser: authUser,
                                           authPassword: password,
                                           mediaEncryption: settings.mediaEncryption,
                                           nat: nat,
                                           answerEarlyMedia: settings.autoPreview)
    }
}
