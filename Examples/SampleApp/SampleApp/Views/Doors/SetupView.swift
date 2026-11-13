import SwiftUI
import BaresipKit

/// The first screen without an account: server, user and password, then Connect.
struct SetupView: View {
    @EnvironmentObject private var model: CallModel
    @State private var server = ""
    @State private var user = ""
    @State private var password = ""
    @State private var transport = BaresipTransport.tls
    @State private var connecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LogoMark()
                Text("Connect your intercom")
                    .font(.display(36, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Zvono rings your phone when someone is at the door, shows you who it is and opens the door.")
                    .font(.body)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    StackedField(title: "Server", text: $server, prompt: "pbx.example.com", keyboard: .URL)
                    HStack(alignment: .top, spacing: 12) {
                        StackedField(title: "User", text: $user, prompt: "100", keyboard: .asciiCapable)
                        StackedField(title: "Password", text: $password, prompt: "Required", secure: true)
                    }
                    Picker("Connection", selection: $transport) {
                        Text("TLS").tag(BaresipTransport.tls)
                        Text("TCP").tag(BaresipTransport.tcp)
                        Text("UDP").tag(BaresipTransport.udp)
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 10) {
                        Image(systemName: transport == .tls ? "lock" : "lock.open")
                            .foregroundStyle(transport == .tls ? Theme.info : Theme.alert)
                            .accessibilityHidden(true)
                        Text(transport == .tls ? "Encrypted connection on port 5061" : "Not encrypted, port 5060")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                    .frame(minHeight: 32)
                    Button {
                        connect()
                    } label: {
                        if connecting {
                            ProgressView()
                        } else {
                            Text("Connect")
                        }
                    }
                    .buttonStyle(FilledButtonStyle(kind: .light))
                    .disabled(!canConnect || connecting)
                }

                Note(text: """
                The password is kept in the Keychain of this phone. Certificates, NAT traversal and codecs are \
                in Settings, Account. Next, Zvono asks for notifications, the microphone and the camera.
                """)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var canConnect: Bool {
        !server.trimmed.isEmpty && !user.trimmed.isEmpty && !password.isEmpty
    }

    private func connect() {
        connecting = true
        model.password = password
        var settings = model.settings
        settings.domain = server.trimmed
        settings.username = user.trimmed
        settings.transport = transport
        settings.port = ""
        model.settings = settings
        Task {
            await model.saveAndRegister()
            connecting = false
        }
    }
}

/// A label above a text field, as on the setup and door screens.
struct StackedField: View {
    let title: String
    @Binding var text: String
    var prompt = ""
    var keyboard: UIKeyboardType = .default
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondary)
            Group {
                if secure {
                    SecureField(title, text: $text, prompt: Text(prompt))
                } else {
                    TextField(title, text: $text, prompt: Text(prompt))
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.field))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
