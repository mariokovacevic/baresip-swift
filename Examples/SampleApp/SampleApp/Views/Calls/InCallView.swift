import SwiftUI
import BaresipKit
import BaresipKitSwiftUI
import BaresipKitVideo

/// The running call: the other side's video, your camera in the corner, controls below.
struct InCallView: View {
    @EnvironmentObject private var model: CallModel
    @State private var showMore = false
    @State private var showOutputs = false

    static let selfViewSize = CGSize(width: 88, height: 118)

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                remote
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.picture.ignoresSafeArea(edges: .top))
                header
                if let call = model.activeCall {
                    BaresipSelfView(call: call, size: Self.selfViewSize)
                        .accessibilityIdentifier("call.selfView")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 110)
                        .padding(.trailing, 16)
                }
                notes
            }
            InCallControls(showMore: $showMore, showOutputs: $showOutputs)
        }
        .background(Theme.callBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMore) {
            CallMoreView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showOutputs) {
            NavigationStack {
                AudioOutputView()
            }
            .environmentObject(model)
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: showChat) {
            NavigationStack {
                ThreadView(peerURI: model.showCallChat ?? "", overCall: true)
                    .screenBackground()
            }
            .environmentObject(model)
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
        }
    }

    private var showChat: Binding<Bool> {
        Binding(
            get: { model.showCallChat != nil },
            set: { shown in
                if !shown {
                    model.showCallChat = nil
                }
            }
        )
    }

    @ViewBuilder
    private var remote: some View {
        if model.receivingVideo, let call = model.activeCall {
            BaresipCallVideo(call: call) { view in
                model.snapshots.register(view, for: call.id)
            }
            .accessibilityLabel("Remote video")
        } else if door != nil {
            VStack(spacing: 12) {
                Image(systemName: "person")
                    .font(.system(size: 110, weight: .ultraLight))
                    .foregroundStyle(Theme.pictureMark)
                Text("Waiting for the door camera")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .opacity(model.captions.isEmpty ? 1 : 0)
            }
            .padding(.top, 70)
            .accessibilityElement(children: .combine)
        } else {
            Avatar(initials: model.currentRow?.initials ?? "", size: 120)
                .padding(.top, 70)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                model.callMinimized = true
                model.tab = .doors
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back to the app, the call goes on")
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.display(32, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    StatusDot(color: model.onHold ? Theme.brass : Theme.info)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(model.currentRow.map { callStatusText($0, now: context.date) } ?? "")
                            .textCase(.uppercase)
                            .font(.footnote.weight(.semibold))
                            .tracking(0.8)
                            .monospacedDigit()
                            .foregroundStyle(model.onHold ? Theme.brass : Theme.info)
                            .accessibilityIdentifier("call.state")
                            .accessibilityValue(model.callState.map { String(describing: $0) } ?? "")
                    }
                }
            }
            Spacer(minLength: 4)
            chatButton
            VStack(alignment: .trailing, spacing: 6) {
                if model.stats?.audio.isSecure == true {
                    chip("Encrypted", systemImage: "lock")
                }
                if model.calls.count > 1 {
                    chip("\(model.calls.count) calls", systemImage: "phone")
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .background(Theme.overlay.ignoresSafeArea(edges: .top))
    }

    private var chatButton: some View {
        Button {
            model.openCallChat()
        } label: {
            RoundIcon(systemImage: "bubble.left", size: 44)
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.onBrass)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.brass, in: Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .accessibilityLabel(unread > 0 ? "Messages, \(unread) unread" : "Messages")
        .accessibilityIdentifier("call.chat")
    }

    private var unread: Int {
        guard let peer = model.callOnScreen?.remoteURI else { return 0 }
        return model.unreadCount(from: peer)
    }

    private var captions: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.captions) { caption in
                VStack(alignment: .leading, spacing: 2) {
                    Text(caption.sender)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.brass)
                    Text(caption.text)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(caption.id == model.captions.last?.id ? 1 : 0.6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture {
                    model.openCallChat()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("call.caption")
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.captions)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            captions
            if model.currentDoorOpened {
                Label("Door opened", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onBrass)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.brass, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityAddTraits(.updatesFrequently)
            }
            Text(model.sendingVideo ? "The other side sees you." : "Your camera is off. The other side hears you only.")
                .font(.footnote)
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.overlay, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.field))
    }

    private var door: Door? {
        model.door(of: model.activeCall)
    }

    private var title: String {
        door?.title ?? model.currentRow?.title ?? "Call"
    }
}
