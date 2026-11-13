import SwiftUI
import UniformTypeIdentifiers
import BaresipKit

struct AccountView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var importTarget: ImportTarget = .ca
    @State private var entryTarget: CertificateEntryView.Kind?

    enum ImportTarget {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(title: "Account")
                if let section = model.profile.accountSection(model: model) {
                    Card {
                        section
                            .padding(16)
                    }
                }
                serverSection
                credentialsSection
                AccountCertificateSections(importTarget: $importTarget, showImporter: $showImporter,
                                           entryTarget: $entryTarget)
                AccountCallSections()
                AccountNATSection()
                AccountSIPSection()
                AccountCodecSection()
                VStack(alignment: .leading, spacing: 8) {
                    Button("Save and register", action: saveAndRegister)
                        .buttonStyle(FilledButtonStyle(kind: .light))
                        .disabled(!canSave)
                    Note(text: """
                    Everything you enter is saved right away: the passwords in the Keychain, certificates and \
                    keys in the app's protected storage. It takes effect when you tap Save and register; \
                    changing certificates restarts the SIP engine.
                    """)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.immediately)
        .titledScreen("Account")
        .toolbar {
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
            .preferredColorScheme(.dark)
        }
    }

    private var serverSection: some View {
        TitledSection(title: "Server", note: "Registrar: \(model.settings.registrar)") {
            Card {
                FieldRow(title: "Domain", text: $model.settings.domain, prompt: "pbx.example.com",
                         identifier: "account.domain", keyboard: .URL)
                RowDivider()
                SegmentRow(title: "Transport", selection: $model.settings.transport) {
                    Text("TLS").tag(BaresipTransport.tls)
                    Text("TCP").tag(BaresipTransport.tcp)
                    Text("UDP").tag(BaresipTransport.udp)
                }
                RowDivider()
                FieldRow(title: "Port", text: $model.settings.port,
                         prompt: model.settings.transport == .tls ? "5061" : "5060",
                         identifier: "account.port", keyboard: .numberPad)
                RowDivider()
                FieldRow(title: "Outbound proxy", text: $model.settings.outboundProxy, prompt: "None")
            }
        }
    }

    private var credentialsSection: some View {
        TitledSection(title: "Credentials") {
            Card {
                FieldRow(title: "Username", text: $model.settings.username, prompt: "100",
                         identifier: "account.username")
                RowDivider()
                FieldRow(title: "Password", text: $model.password, prompt: "Required",
                         identifier: "account.password", secure: true)
                RowDivider()
                FieldRow(title: "Auth user", text: $model.settings.authUser, prompt: "Same as username")
                RowDivider()
                FieldRow(title: "Display name", text: $model.settings.displayName, prompt: "None")
            }
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
