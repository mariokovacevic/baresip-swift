import SwiftUI
import BaresipKit

/// The server certificate, the client certificate and the pins of the Account screen.
struct AccountCertificateSections: View {
    @EnvironmentObject private var model: CallModel
    @Binding var importTarget: AccountView.ImportTarget
    @Binding var showImporter: Bool
    @Binding var entryTarget: CertificateEntryView.Kind?

    var body: some View {
        TitledSection(title: "Server certificate", note: """
        PEM (one or more certificates) or DER (.cer/.crt). Needed for a private CA or a self-signed \
        server. Without verification any server certificate is accepted; use it only for testing.
        """) {
            Card {
                if model.caSummaries.isEmpty {
                    ValueRow(title: "Trusted CA", value: "System trust store")
                } else {
                    ForEach(model.caSummaries, id: \.self) { summary in
                        ValueRow(title: "CA", value: summary)
                        RowDivider()
                    }
                    CardButton(title: "Remove CA certificates", role: .destructive) { model.removeCA() }
                }
                RowDivider()
                CardButton(title: "Import CA certificate…") {
                    importTarget = .ca
                    showImporter = true
                }
                RowDivider()
                CardButton(title: model.caSummaries.isEmpty ? "Enter CA certificate…" : "Edit CA certificates…",
                           identifier: "account.ca.enter") {
                    entryTarget = .ca
                }
                #if DEBUG
                    RowDivider()
                    ToggleRow(title: "Verify server certificate", isOn: $model.settings.verifyServer)
                #endif
            }
        }

        TitledSection(title: "Client certificate (mutual TLS)", note: """
        Import one PEM file with the certificate and its unencrypted private key, or paste both by hand.
        """) {
            Card {
                if model.clientSummaries.isEmpty {
                    ValueRow(title: "Certificate", value: "None")
                } else {
                    ForEach(model.clientSummaries, id: \.self) { summary in
                        ValueRow(title: "Certificate", value: summary)
                        RowDivider()
                    }
                    CardButton(title: "Remove client certificate", role: .destructive) {
                        model.removeClientCertificate()
                    }
                }
                RowDivider()
                CardButton(title: "Import client certificate…") {
                    importTarget = .client
                    showImporter = true
                }
                RowDivider()
                CardButton(title: model.clientSummaries.isEmpty
                    ? "Enter certificate and key…" : "Edit certificate and key…",
                    identifier: "account.client.enter") {
                        entryTarget = .client
                    }
            }
        }

        TitledSection(title: "Certificate pinning", note: """
        One pin per line. With pins set, the connection is accepted only if the chain verifies and a \
        certificate matches a pin.
        """) {
            Card {
                TextField("SPKI SHA-256 pins (base64)", text: $model.settings.pins, axis: .vertical)
                    .lineLimit(1 ... 4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .accessibilityIdentifier("account.pins")
                if !model.settings.pins.trimmed.isEmpty {
                    RowDivider()
                    CardButton(title: "Clear pins", role: .destructive, identifier: "account.pins.clear") {
                        model.settings.pins = ""
                    }
                }
            }
        }
    }
}
