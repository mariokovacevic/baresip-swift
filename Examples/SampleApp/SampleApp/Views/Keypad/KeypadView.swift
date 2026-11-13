import SwiftUI

/// Calls or messages any number or SIP address, and calls to send a code and hang up.
struct KeypadView: View {
    @EnvironmentObject private var model: CallModel
    @State private var showDTMF = false
    @State private var openThread = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                entry
                Note(text: """
                A number calls through \(domain). A full address, such as office@example.com, works too.
                """)
                .frame(maxWidth: .infinity, alignment: .leading)
                DialPad { digit in model.destination.append(digit) }
                    .padding(.top, 4)
                actions
                    .padding(.top, 4)
                codeButton
                pendingDTMF
                ContactsSection { contact in
                    model.destination = contact.address.trimmed
                    openThread = true
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Keypad")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $openThread) {
            ThreadView(peerURI: model.destination.trimmed)
        }
        .sheet(isPresented: $showDTMF) {
            NavigationStack {
                DTMFEntryView()
            }
            .environmentObject(model)
            .preferredColorScheme(.dark)
        }
    }

    private var domain: String {
        let domain = model.settings.domain.trimmed
        return domain.isEmpty ? "your server" : domain
    }

    private var entry: some View {
        HStack(spacing: 8) {
            TextField("Number or address", text: $model.destination)
                .font(.displayMedium(28))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.go)
                .onSubmit { Task { await model.call(video: false) } }
                .accessibilityIdentifier("call.destination")
            if !model.destination.isEmpty {
                Button {
                    model.destination.removeLast()
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete the last character")
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .frame(minHeight: 64)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: 30) {
            action("Message", systemImage: "bubble.left", size: 56, light: false) {
                openThread = true
            }
            action("Call", systemImage: "phone.fill", size: 72, light: true) {
                Task { await model.call(video: false) }
            }
            .accessibilityIdentifier("call.audio")
            action("Video", systemImage: "video", size: 56, light: false) {
                Task { await model.call(video: true) }
            }
            .accessibilityIdentifier("call.video")
        }
        .disabled(model.destination.trimmed.isEmpty)
    }

    private var codeButton: some View {
        Button {
            showDTMF = true
        } label: {
            Label("Call, send a code, hang up", systemImage: "key")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.field))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("call.dtmf")
    }

    private func action(_ title: String, systemImage: String, size: CGFloat, light: Bool,
                        perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(light ? Theme.background : Theme.text)
                    .frame(width: size, height: size)
                    .background(light ? Theme.text : Theme.raised, in: Circle())
                    .overlay(Circle().stroke(light ? Color.clear : Theme.field))
                Text(title)
                    .font(.footnote.weight(light ? .semibold : .medium))
                    .foregroundStyle(Theme.text)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var pendingDTMF: some View {
        if let pending = model.pendingDTMF {
            HStack(spacing: 8) {
                Image(systemName: "key")
                    .foregroundStyle(Theme.brass)
                    .accessibilityHidden(true)
                Text("Sends \(pending.digits) when the call connects")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 4)
                Button("Clear") { model.pendingDTMF = nil }
                    .font(.footnote)
            }
            .accessibilityIdentifier("call.dtmf.pending")
        }
    }
}
