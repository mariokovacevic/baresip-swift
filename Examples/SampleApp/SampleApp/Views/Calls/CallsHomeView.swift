import SwiftUI
import BaresipKit

struct CallsHomeView: View {
    @EnvironmentObject private var model: CallModel
    @State private var showDTMF = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if model.currentCall != nil, model.callMinimized {
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

                AccountCard()
                dialCard

                if !model.calls.isEmpty {
                    callsSection
                }

                recentsSection

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
        .sheet(isPresented: $showDTMF) {
            NavigationStack {
                DTMFEntryView()
            }
            .environmentObject(model)
            .presentationDetents([.large])
        }
        .navigationTitle("Calls")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let phone = model.phone {
                    NavigationLink {
                        EngineStateView(phone: phone)
                    } label: {
                        Image(systemName: "waveform.path.ecg")
                    }
                    .accessibilityLabel("Engine state")
                    .accessibilityIdentifier("engine.link")
                }
            }
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
                    actionLabel("Audio", icon: "phone.fill", foreground: .white, background: Palette.green)
                }
                .accessibilityIdentifier("call.audio")
                Button {
                    Task { await model.call(video: true) }
                } label: {
                    actionLabel("Video", icon: "video.fill", foreground: .white, background: Palette.blue)
                }
                .accessibilityIdentifier("call.video")
                NavigationLink {
                    ThreadView(peerURI: model.destination)
                } label: {
                    actionLabel("Message", icon: "message.fill", foreground: .primary,
                                background: Color(.systemGray5))
                }
                .disabled(model.destination.trimmed.isEmpty)
                Button {
                    showDTMF = true
                } label: {
                    actionLabel("DTMF", icon: "circle.grid.3x3.fill", foreground: .primary,
                                background: Color(.systemGray5))
                }
                .accessibilityIdentifier("call.dtmf")
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.plain)

            if let pending = model.pendingDTMF {
                HStack(spacing: 8) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .foregroundStyle(Palette.secondaryText)
                        .accessibilityHidden(true)
                    Text("Sends \(pending.digits) when the call connects")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Palette.secondaryText)
                    Spacer(minLength: 4)
                    Button("Clear") { model.pendingDTMF = nil }
                        .font(.footnote)
                }
                .accessibilityIdentifier("call.dtmf.pending")
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func actionLabel(_ title: String, icon: String, foreground: Color, background: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: 12))
    }

    private static let recentsOnHome = 5

    private var recentsSection: some View {
        VStack(spacing: 8) {
            HStack {
                SectionHeader(title: "Recent calls")
                if model.history.count > Self.recentsOnHome {
                    NavigationLink("All (\(model.history.count))") {
                        RecentCallsView()
                    }
                    .font(.footnote)
                }
            }
            VStack(spacing: 0) {
                if model.history.isEmpty {
                    Text("No calls yet")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    let shown = Array(model.history.prefix(Self.recentsOnHome))
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, record in
                        RecentCallRow(record: record)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        if index < shown.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
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
}
