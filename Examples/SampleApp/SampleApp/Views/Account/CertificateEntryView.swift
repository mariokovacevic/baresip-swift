import SwiftUI
import BaresipKit

/// Lets the user paste a CA bundle, or a client certificate and its private key, as PEM text.
struct CertificateEntryView: View {
    enum Kind: Identifiable {
        case ca
        case client

        var id: Self {
            self
        }
    }

    let kind: Kind
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    @State private var certificates = ""
    @State private var key = ""
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                editor($certificates, identifier: "certificate.entry.certificate")
            } header: {
                Text(kind == .ca ? "CA certificates (PEM)" : "Certificate (PEM)")
            } footer: {
                Text(
                    kind == .ca
                        ? "One or more -----BEGIN CERTIFICATE----- blocks."
                        : "The client certificate, optionally followed by intermediate certificates."
                )
            }
            if kind == .client {
                Section {
                    editor($key, identifier: "certificate.entry.key")
                } header: {
                    Text("Private key (PEM)")
                } footer: {
                    Text("Unencrypted: BEGIN PRIVATE KEY, BEGIN RSA PRIVATE KEY or BEGIN EC PRIVATE KEY.")
                }
            }
            if let error {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(kind == .ca ? "CA certificate" : "Client certificate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .accessibilityIdentifier("certificate.entry.save")
            }
        }
        .onAppear(perform: load)
    }

    private func editor(_ text: Binding<String>, identifier: String) -> some View {
        TextEditor(text: text)
            .font(.caption.monospaced())
            .frame(minHeight: 160)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier(identifier)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch kind {
        case .ca:
            certificates = model.caCertificates.flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
        case .client:
            (certificates, key) = BaresipCertificates.split(model.clientCertificate)
        }
    }

    private func save() {
        do {
            switch kind {
            case .ca: try model.setCA(pem: certificates)
            case .client: try model.setClientCertificate(certificate: certificates, key: key)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
