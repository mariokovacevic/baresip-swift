import SwiftUI
import UniformTypeIdentifiers
import BaresipKit

struct AccountView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var importTarget: ImportTarget = .ca

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
            } header: {
                Text("Server certificate")
            } footer: {
                Text("PEM (one or more certificates) or DER (.cer/.crt). Needed for a private CA or a self-signed server.")
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
            } header: {
                Text("Client certificate (mutual TLS)")
            } footer: {
                Text("One PEM file with the certificate and its unencrypted private key.")
            }

            Section {
                TextField("SPKI SHA-256 pins (base64)", text: $model.settings.pins, axis: .vertical)
                    .accessibilityIdentifier("account.pins")
                    .lineLimit(1...4)
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
                Text("One pin per line. With pins set, the connection is accepted only if the chain verifies and a certificate matches a pin.")
            }

            Section("Media") {
                Picker("Encryption", selection: $model.settings.mediaEncryption) {
                    Text("SRTP optional").tag(BaresipMediaEncryption.srtpOptional)
                    Text("SRTP required").tag(BaresipMediaEncryption.srtpMandatory)
                    Text("DTLS-SRTP").tag(BaresipMediaEncryption.dtlsSRTP)
                    Text("None").tag(BaresipMediaEncryption.none)
                }
            }

            Section("NAT") {
                Toggle("ICE", isOn: $model.settings.useICE)
                if model.settings.useICE {
                    TextField("STUN URI (optional)", text: $model.settings.stunURI, prompt: Text("stun:stun.example.com"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("TURN URI (optional)", text: $model.settings.turnURI, prompt: Text("turns:turn.example.com:5349"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("TURN user", text: $model.settings.turnUser)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("TURN password", text: $model.turnPassword)
                }
            }

            Section {
                Button("Save and register") {
                    Task {
                        await model.saveAndRegister()
                        dismiss()
                    }
                }
                .disabled(!model.settings.isComplete || model.password.isEmpty)
                .accessibilityIdentifier("account.save")
            } footer: {
                Text("The password is stored in the Keychain and certificates in the app's protected storage. Changing certificates restarts the SIP engine.")
            }
        }
        .navigationTitle("Account")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.certificateTypes) { result in
            guard case .success(let url) = result else { return }
            switch importTarget {
            case .ca: model.importCA(from: url)
            case .client: model.importClientCertificate(from: url)
            }
        }
    }
}
