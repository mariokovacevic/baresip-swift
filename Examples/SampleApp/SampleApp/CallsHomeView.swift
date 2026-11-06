import SwiftUI
import BaresipKit

struct CallsHomeView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if model.currentCall != nil && model.callMinimized {
                    Button {
                        model.callMinimized = false
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Return to call")
                                .fontWeight(.semibold)
                            Spacer()
                            if let row = model.currentRow {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(callStatusText(row, now: context.date))
                                        .monospacedDigit()
                                }
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(Palette.green, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                accountCard
                dialCard

                if !model.calls.isEmpty {
                    callsSection
                }

                messagesSection

                NavigationLink {
                    LogView()
                } label: {
                    HStack {
                        Text("Log")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Palette.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Calls")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AccountView()
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Account settings")
            }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                AccountView()
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(registrationColor)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(model.settings.isComplete ? model.settings.aor : "Set up account")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Palette.secondaryText)
                }
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("account.link")

            Text(registrationText)
                .font(.footnote)
                .foregroundStyle(registrationTextColor)
                .padding(.leading, 22)
                .accessibilityIdentifier("registration.state")

            if model.settings.isComplete {
                HStack(spacing: 16) {
                    Button("Register") { Task { await model.register() } }
                    Button("Unregister") { Task { await model.unregister() } }
                }
                .font(.subheadline)
                .padding(.leading, 22)
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var dialCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CALL OR MESSAGE")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
            TextField("Number, user or SIP URI", text: $model.destination)
                .font(.system(size: 28, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .accessibilityIdentifier("call.destination")
            HStack(spacing: 8) {
                Button {
                    Task { await model.call(video: false) }
                } label: {
                    Label("Audio", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(Palette.green, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("call.audio")
                Button {
                    Task { await model.call(video: true) }
                } label: {
                    Label("Video", systemImage: "video.fill")
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(Palette.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("call.video")
                NavigationLink {
                    ThreadView(peerURI: model.destination)
                } label: {
                    Label("Message", systemImage: "message.fill")
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.primary)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(model.destination.trimmed.isEmpty)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var callsSection: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Calls (\(model.calls.count))")
            VStack(spacing: 0) {
                ForEach(Array(model.calls.enumerated()), id: \.element.id) { index, row in
                    CallListRow(row: row)
                    if index < model.calls.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var messagesSection: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Messages")
            NavigationLink {
                MessagesListView()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let first = model.conversations.first {
                            Text(first.peer)
                                .font(.headline)
                            Text(first.last.text)
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(1)
                        } else {
                            Text("No messages yet")
                                .font(.headline)
                            Text("Send a SIP message to any user")
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Palette.secondaryText)
                }
                .padding(16)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var registrationText: String {
        switch model.registration {
        case .registered:
            let ca = model.caSummaries.isEmpty ? "system CA" : "private CA"
            let pins = model.settings.pinList.count
            return "Registered over \(model.settings.transportName.uppercased()) · \(ca)\(pins > 0 ? " · \(pins) pin\(pins == 1 ? "" : "s")" : "")"
        case .registering:
            return "Registering…"
        case .unregistering:
            return "Signing out…"
        case .failed:
            return "Registration failed\(model.registrationError.map { ": \($0)" } ?? "")"
        case .none:
            return model.registrationError ?? "Offline"
        }
    }

    private var registrationColor: Color {
        switch model.registration {
        case .registered: return Color(red: 0.204, green: 0.78, blue: 0.349)
        case .failed: return Color(red: 1.0, green: 0.231, blue: 0.188)
        case .registering, .unregistering: return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .none: return Color(.systemGray3)
        }
    }

    private var registrationTextColor: Color {
        switch model.registration {
        case .registered: return Palette.green
        case .failed: return Palette.destructive
        default: return Palette.secondaryText
        }
    }
}

struct CallListRow: View {
    @EnvironmentObject private var model: CallModel
    let row: CallRow

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: row.initials,
                   tint: isCurrent ? Palette.green : Palette.secondaryText,
                   background: isCurrent ? Color(red: 0.89, green: 0.94, blue: 0.9) : Color(.systemGray6))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: row.outgoing ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .accessibilityLabel(row.outgoing ? "Outgoing" : "Incoming")
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text((isCurrent ? "Current · " : "") + callStatusText(row, now: context.date) + (row.codec.isEmpty ? "" : " · \(row.codec)"))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(isCurrent ? Palette.green : Palette.secondaryText)
                }
            }
            Spacer(minLength: 8)
            if row.state == .incoming {
                Button("Open") { model.callMinimized = false }
                    .buttonStyle(.bordered)
            } else if !isCurrent {
                Button("Switch") { Task { await model.switchTo(row.id) } }
                    .buttonStyle(.bordered)
                    .tint(Palette.blue)
            } else {
                Button(row.isHeld ? "Resume" : "Hold") { Task { await model.toggleHold(row.id) } }
                    .buttonStyle(.bordered)
                    .tint(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button("Hang up", role: .destructive) { Task { await model.hangup(row.id) } }
        }
        .accessibilityIdentifier("calls.row")
    }

    private var isCurrent: Bool { row.id == model.currentCall }
}
