import Foundation
import BaresipKit

extension CallModel {
    func importCA(from url: URL) {
        do {
            let data = try readSecurityScoped(url)
            caCertificates = try BaresipCertificates.caBundle(from: data)
            append("CA imported: \(caSummaries.joined(separator: ", "))")
        } catch {
            append("CA import failed: \(error.localizedDescription)")
        }
    }

    func importClientCertificate(from url: URL) {
        do {
            let data = try readSecurityScoped(url)
            clientCertificate = try BaresipCertificates.clientIdentity(from: data)
            append("client certificate imported: \(clientSummaries.first ?? "")")
        } catch {
            append("client certificate import failed: \(error.localizedDescription)")
        }
    }

    /// Uses CA certificates pasted as PEM text. Empty text removes them.
    func setCA(pem: String) throws {
        guard !pem.trimmed.isEmpty else {
            removeCA()
            return
        }
        caCertificates = try BaresipCertificates.caBundle(from: Data(pem.utf8))
        append("CA entered: \(caSummaries.joined(separator: ", "))")
    }

    /// Uses a client certificate and private key pasted as PEM text. Both empty removes them.
    func setClientCertificate(certificate: String, key: String) throws {
        guard !certificate.trimmed.isEmpty || !key.trimmed.isEmpty else {
            removeClientCertificate()
            return
        }
        clientCertificate = try BaresipCertificates
            .clientIdentity(from: Data((certificate.trimmed + "\n" + key.trimmed).utf8))
        append("client certificate entered: \(clientSummaries.first ?? "")")
    }

    func removeCA() {
        caCertificates = nil
        SettingsStore.removeCACertificates()
    }

    func removeClientCertificate() {
        clientCertificate = nil
        SettingsStore.removeClientCertificate()
    }

    private func saveSecretsOrReloadUnreadOnes() {
        if password.isEmpty {
            password = SettingsStore.password
        } else {
            SettingsStore.password = password
        }
        if turnPassword.isEmpty {
            turnPassword = SettingsStore.turnPassword
        } else {
            SettingsStore.turnPassword = turnPassword
        }
        if let caCertificates {
            SettingsStore.storeCACertificates(caCertificates)
        } else {
            caCertificates = SettingsStore.caCertificates
        }
        if let clientCertificate {
            SettingsStore.storeClientCertificate(clientCertificate)
        } else {
            clientCertificate = SettingsStore.clientCertificate
        }
    }

    func saveAndRegister() async {
        SettingsStore.save(settings)
        saveSecretsOrReloadUnreadOnes()
        if currentCall != nil {
            pendingApply = true
            append("settings saved; they apply after the current call")
            return
        }
        await applySaved()
    }

    func applySaved() async {
        if savedTLS != engineTLS || SettingsStore.load().engine != engineOptions {
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
        let settings = SettingsStore.load()
        return TLSSnapshot(ca: SettingsStore.caCertificates, client: SettingsStore.clientCertificate,
                           pins: settings.pinList, verifyServer: settings.verifyServer)
    }

    func tlsConfiguration(_ tls: TLSSnapshot) -> BaresipTLSConfiguration {
        #if DEBUG
            if !tls.verifyServer {
                var insecure = BaresipTLSConfiguration.insecureSkippingServerVerification()
                insecure.caCertificatesPEM = tls.ca
                insecure.clientCertificatePEM = tls.client
                return insecure
            }
        #endif
        return BaresipTLSConfiguration(caCertificatesPEM: tls.ca, clientCertificatePEM: tls.client,
                                       pinnedSPKISHA256: tls.pins)
    }

    func accountConfiguration(_ settings: SIPSettings, password: String,
                              turnPassword: String) -> BaresipAccountConfiguration {
        var nat = BaresipNATConfiguration(mode: settings.natMode,
                                          rtpTimeout: .seconds(max(0, settings.rtpTimeoutSeconds)),
                                          rtcpMultiplexing: settings.rtcpMux,
                                          pinhole: settings.pinhole)
        if settings.natMode != .none, !settings.stunURI.trimmed.isEmpty {
            nat.stunURI = settings.stunURI.trimmed
        }
        if settings.natMode == .ice, !settings.turnURI.trimmed.isEmpty {
            let turnUser = settings.turnUser.trimmed
            let server = BaresipTURNServer(uri: settings.turnURI.trimmed,
                                           username: turnUser.isEmpty ? nil : turnUser,
                                           password: turnPassword.isEmpty ? nil : turnPassword)
            nat.turnServers = [server]
        }
        let authUser = settings.authUser.trimmed.isEmpty ? settings.username.trimmed : settings.authUser.trimmed
        let displayName = settings.displayName.trimmed
        var account = BaresipAccountConfiguration(aor: settings.aor,
                                                  displayName: displayName.isEmpty ? nil : displayName,
                                                  registrar: settings.registrar,
                                                  outboundProxy: settings.proxy,
                                                  transport: settings.transport,
                                                  authUser: authUser,
                                                  authPassword: password,
                                                  registerExpires: .seconds(max(60, settings.registerExpiresSeconds)),
                                                  sipOutbound: settings.sipOutbound,
                                                  mediaEncryption: settings.mediaEncryption,
                                                  nat: nat,
                                                  dtmfMode: settings.dtmfMode,
                                                  audioCodecs: SIPSettings.codecList(settings.audioCodecs),
                                                  videoCodecs: SIPSettings.codecList(settings.videoCodecs),
                                                  answerEarlyMedia: settings.previewAudio,
                                                  acceptTransfers: settings.acceptTransfers,
                                                  pictureUpdateOverSIPInfo: settings.pictureUpdateOverInfo)
        profile.configure(&account)
        return account
    }

    /// Applies the engine settings from the Account screen on top of the profile's.
    func apply(_ options: EngineOptions, to config: inout BaresipConfiguration) {
        config.ipv6 = options.ipv6
        config.iceRelayOnly = options.iceRelayOnly
        config.videoAdaptiveBitrate = options.adaptiveBitrate
        if options.videoHeight > 0 {
            config.video.height = options.videoHeight
            config.video.width = EngineOptions.width(forHeight: options.videoHeight)
        }
        if options.videoFramesPerSecond > 0 {
            config.video.framesPerSecond = options.videoFramesPerSecond
        }
        if options.videoBitrateKbps > 0 {
            config.video.bitrate = options.videoBitrateKbps * 1000
        }
    }
}
