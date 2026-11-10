import SwiftUI
import UniformTypeIdentifiers
import BaresipKit

struct AccountView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var importTarget: ImportTarget = .ca
    @State private var entryTarget: CertificateEntryView.Kind?

    private enum ImportTarget {
        case ca
        case client
    }

    private static let certificateTypes: [UTType] = [
        UTType(filenameExtension: "pem") ?? .data,
        UTType(filenameExtension: "crt") ?? .data,
        UTType(filenameExtension: "cer") ?? .data,
        UTType(filenameExtension: "der") ?? .data,
        UTType(filenameExtension: "key") ?? .data,
        .x509Certificate,
        .plainText,
        .data,
    ]

    var body: some View {
        Form {
            if let section = model.profile.accountSection(model: model) {
                section
            }

            Section {
                TextField("Domain", text: $model.settings.domain, prompt: Text("pbx.example.com"))
                    .accessibilityIdentifier("account.domain")
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Transport", selection: $model.settings.transport) {
                    Text("TLS").tag(BaresipTransport.tls)
                    Text("TCP").tag(BaresipTransport.tcp)
                    Text("UDP").tag(BaresipTransport.udp)
                }
                TextField("Port", text: $model.settings.port,
                          prompt: Text(model.settings.transport == .tls ? "5061" : "5060"))
                    .accessibilityIdentifier("account.port")
                    .keyboardType(.numberPad)
                TextField("Outbound proxy (optional)", text: $model.settings.outboundProxy)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Server")
            } footer: {
                Text("Registrar: \(model.settings.registrar)")
            }

            Section("Credentials") {
                TextField("Username", text: $model.settings.username)
                    .accessibilityIdentifier("account.username")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $model.password)
                    .accessibilityIdentifier("account.password")
                TextField("Auth user (if different)", text: $model.settings.authUser)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Display name (optional)", text: $model.settings.displayName)
            }

            Section {
                if model.caSummaries.isEmpty {
                    Text("System trust store").foregroundStyle(.secondary)
                } else {
                    ForEach(model.caSummaries, id: \.self) { Label($0, systemImage: "checkmark.seal") }
                    Button("Remove CA certificates", role: .destructive) { model.removeCA() }
                }
                Button("Import CA certificate…") {
                    importTarget = .ca
                    showImporter = true
                }
                Button(model.caSummaries.isEmpty ? "Enter CA certificate…" : "Edit CA certificates…") {
                    entryTarget = .ca
                }
                .accessibilityIdentifier("account.ca.enter")
                #if DEBUG
                    Toggle("Verify server certificate", isOn: $model.settings.verifyServer)
                #endif
            } header: {
                Text("Server certificate")
            } footer: {
                Text(
                    """
                    PEM (one or more certificates) or DER (.cer/.crt). Needed for a private CA or a \
                    self-signed server. Without verification any server certificate is accepted; use it \
                    only for testing.
                    """
                )
            }

            Section {
                if model.clientSummaries.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                } else {
                    ForEach(model.clientSummaries, id: \.self) { Label($0, systemImage: "person.badge.key") }
                    Button("Remove client certificate", role: .destructive) { model.removeClientCertificate() }
                }
                Button("Import client certificate…") {
                    importTarget = .client
                    showImporter = true
                }
                Button(model.clientSummaries.isEmpty ? "Enter certificate and key…" : "Edit certificate and key…") {
                    entryTarget = .client
                }
                .accessibilityIdentifier("account.client.enter")
            } header: {
                Text("Client certificate (mutual TLS)")
            } footer: {
                Text(
                    """
                    Import one PEM file with the certificate and its unencrypted private key, or paste both \
                    by hand.
                    """
                )
            }

            Section {
                TextField("SPKI SHA-256 pins (base64)", text: $model.settings.pins, axis: .vertical)
                    .accessibilityIdentifier("account.pins")
                    .lineLimit(1 ... 4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                if !model.settings.pins.trimmed.isEmpty {
                    Button("Clear pins", role: .destructive) { model.settings.pins = "" }
                        .accessibilityIdentifier("account.pins.clear")
                }
            } header: {
                Text("Certificate pinning (optional)")
            } footer: {
                Text(
                    """
                    One pin per line. With pins set, the connection is accepted only if the chain verifies \
                    and a certificate matches a pin.
                    """
                )
            }

            Section {
                Toggle("Receive the caller's audio in the preview", isOn: $model.settings.previewAudio)
            } header: {
                Text("Incoming calls")
            } footer: {
                Text(
                    """
                    Every incoming call is previewed with 183 Session Progress: the caller's media is \
                    received before answering, for example from a door intercom, while your microphone and \
                    camera stay off. Off receives only the picture when the caller offers video. On a phone \
                    iOS plays the audio only once the call is answered, so the caller is heard from then on; \
                    the simulator plays it while ringing. The log shows what each preview receives.
                    """
                )
            }

            Section {
                Picker("Encryption", selection: $model.settings.mediaEncryption) {
                    Text("SRTP optional").tag(BaresipMediaEncryption.srtpOptional)
                    Text("SRTP required").tag(BaresipMediaEncryption.srtpMandatory)
                    Text("DTLS-SRTP").tag(BaresipMediaEncryption.dtlsSRTP)
                    Text("None").tag(BaresipMediaEncryption.none)
                }
                Toggle("Picture updates over SIP INFO", isOn: $model.settings.pictureUpdateOverInfo)
            } header: {
                Text("Media")
            } footer: {
                Text(
                    """
                    Also asks for a new video picture with SIP INFO, for door stations that ignore RTCP.
                    """
                )
            }

            AccountNATSection()
            AccountSIPSection()
            AccountCodecSection()

            Section {
                Button("Save and register", action: saveAndRegister)
                    .disabled(!canSave)
            } footer: {
                Text(
                    """
                    Everything you enter is saved right away: the passwords in the Keychain, certificates and \
                    keys in the app's protected storage. It takes effect when you tap Save and register; \
                    changing certificates restarts the SIP engine.
                    """
                )
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Account")
        .toolbar {
            // The form is long, so saving is also reachable without scrolling to the end.
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveAndRegister)
                    .disabled(!canSave)
                    .accessibilityIdentifier("account.save")
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.certificateTypes) { result in
            guard case .success(let url) = result else { return }
            switch importTarget {
            case .ca: model.importCA(from: url)
            case .client: model.importClientCertificate(from: url)
            }
        }
        .sheet(item: $entryTarget) { kind in
            NavigationStack {
                CertificateEntryView(kind: kind)
            }
            .environmentObject(model)
        }
    }

    private var canSave: Bool {
        model.settings.isComplete && !model.password.isEmpty
    }

    private func saveAndRegister() {
        Task {
            await model.saveAndRegister()
            dismiss()
        }
    }
}
