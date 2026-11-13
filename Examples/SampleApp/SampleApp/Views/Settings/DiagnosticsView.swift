import SwiftUI
import BaresipKit
import BaresipKitSwiftUI

/// What the engine reports right now, its calls, and the log to share with support.
struct DiagnosticsView: View {
    @EnvironmentObject private var model: CallModel
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(title: "Diagnostics")
                TitledSection(title: "Right now") {
                    Card {
                        if registrations.isEmpty {
                            ValueRow(title: "Registration", value: "No account reported yet")
                        }
                        ForEach(registrations, id: \.account) { entry in
                            ValueRow(title: "Account \(entry.account.rawValue)",
                                     value: String(describing: entry.state),
                                     valueIdentifier: "engine.registration")
                            RowDivider()
                        }
                        ValueRow(title: "Network", value: model.lastNetworkPath ?? "Unknown")
                        RowDivider()
                        ValueRow(title: "Push",
                                 value: model.remoteToken == nil ? "No token yet" : "Token sent with the registration")
                        RowDivider()
                        HStack(spacing: 0) {
                            CardButton(title: "Register") { Task { await model.register() } }
                            CardButton(title: "Unregister") { Task { await model.unregister() } }
                        }
                        .disabled(!model.settings.isComplete)
                    }
                }
                TitledSection(title: "Calls in the engine") {
                    Card {
                        if let calls = model.phone?.calls, !calls.isEmpty {
                            ForEach(Array(calls.enumerated()), id: \.element.id) { index, call in
                                if index > 0 {
                                    RowDivider()
                                }
                                EngineCallRow(call: call)
                            }
                        } else {
                            ValueRow(title: "Calls", value: "None")
                        }
                    }
                }
                logSection
            }
            .padding(16)
        }
        .titledScreen("Diagnostics")
        .confirmationDialog("Clear the log on screen?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { model.log.removeAll() }
        } message: {
            Text("The log files you can share are kept for seven days.")
        }
    }

    private var logSection: some View {
        TitledSection(title: "Log") {
            Card {
                ToggleRow(title: "Log SIP messages",
                          detail: "They hold numbers, addresses and door codes. Applies after a restart.",
                          isOn: $model.logsSIPMessages)
                    .accessibilityIdentifier("log.sipMessages")
            }
            Text(model.log.suffix(60).reversed().joined(separator: "\n"))
                .font(.caption.monospaced())
                .foregroundStyle(Theme.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(14)
                .background(Theme.callBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
            HStack(spacing: 8) {
                ShareLink(items: FileLog.shared.files()) {
                    Text("Share the log")
                }
                .buttonStyle(FilledButtonStyle(kind: .raised, height: 48))
                .accessibilityIdentifier("log.share")
                Button("Clear") { confirmClear = true }
                    .buttonStyle(FilledButtonStyle(kind: .raised, height: 48))
                    .disabled(model.log.isEmpty)
            }
        }
    }

    private var registrations: [(account: BaresipAccountID, state: BaresipRegistrationState)] {
        (model.phone?.registrations ?? [:])
            .map { (account: $0.key, state: $0.value) }
            .sorted { $0.account.rawValue < $1.account.rawValue }
    }
}

struct EngineCallRow: View {
    @ObservedObject var call: BaresipPhoneCall

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(call.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .accessibilityIdentifier("engine.call.state")
            }
            Spacer(minLength: 4)
            iconButton(call.isMuted ? "mic.slash" : "mic", label: call.isMuted ? "Unmute" : "Mute") {
                try? await call.setMuted(!call.isMuted)
            }
            .disabled(!call.isConnected)
            iconButton("pause", label: call.isOnHold ? "Resume" : "Hold") {
                try? await call.setOnHold(!call.isOnHold)
            }
            .disabled(!call.isConnected && !call.isOnHold)
            Button {
                Task { try? await call.hangUp() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(HangUpButtonStyle(size: 44))
            .accessibilityLabel("Hang up")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
    }

    private func iconButton(_ systemImage: String, label: String,
                            action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.field))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var statusText: String {
        var parts = [String(describing: call.state)]
        if call.isHeldByRemote {
            parts.append("held by the other side")
        }
        if !call.audioCodec.isEmpty {
            parts.append(call.audioCodec)
        }
        if !call.videoCodec.isEmpty {
            parts.append(call.videoCodec)
        }
        return parts.joined(separator: ", ")
    }
}
