import SwiftUI
import BaresipKit
import BaresipKitSwiftUI
import BaresipKitVideo

/// A ringing call: the caller's picture before answering, then Decline, Open door and Answer.
struct IncomingCallView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                picture
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.picture.ignoresSafeArea(edges: .top))
                header
                if model.previewing {
                    Text(previewNote)
                        .font(.footnote)
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.overlay, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            controls
        }
        .background(Theme.callBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var picture: some View {
        if model.previewing, model.previewVideo, let incoming = model.incoming {
            previewVideo(of: incoming)
                .accessibilityLabel("Caller's video")
        } else if hasVideo || door != nil {
            VStack(spacing: 14) {
                Image(systemName: "person")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(Theme.pictureMark)
                    .accessibilityHidden(true)
                previewButton
            }
            .padding(.top, 90)
        } else {
            VStack(spacing: 16) {
                Avatar(initials: CallRow.initials(title), size: 120)
                previewButton
            }
            .padding(.top, 90)
        }
    }

    @ViewBuilder
    private var previewButton: some View {
        if !model.previewing {
            Button {
                Task { await model.preview() }
            } label: {
                Label(hasVideo ? "See who is there" : "Listen first", systemImage: hasVideo ? "eye" : "ear")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Theme.text, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("incoming.preview")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StatusDot(color: Theme.brass)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Ringing \(formatDuration(since: model.incoming?.startedAt, now: context.date))")
                        .monospacedDigit()
                }
            }
            .textCase(.uppercase)
            .font(.footnote.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.brass)
            Text(title)
                .font(.display(40, relativeTo: .largeTitle))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if door == nil, let uri = model.incoming?.remoteURI {
                Text(uri)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Theme.overlay.ignoresSafeArea(edges: .top))
    }

    private var controls: some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom) {
                callButton(title: "Decline", systemImage: "xmark", size: 68, foreground: Theme.alert,
                           background: Theme.hangUp, id: "incoming.reject") {
                    Task { await model.reject() }
                }
                Spacer()
                if model.ringingDoor != nil {
                    callButton(title: "Open door", systemImage: "key", size: 96, foreground: Theme.onBrass,
                               background: Theme.brass, id: "incoming.openDoor") {
                        Task { await model.openRingingDoor() }
                    }
                    Spacer()
                }
                callButton(title: "Answer", systemImage: "phone.fill", size: 68, foreground: Theme.background,
                           background: Theme.text, id: "incoming.answer") {
                    Task { await model.answer() }
                }
            }
            Text(hint)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 24)
        .background(Theme.bar.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.barLine).frame(height: 1)
        }
    }

    private func callButton(title: String, systemImage: String, size: CGFloat, foreground: Color, background: Color,
                            id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(foreground)
                    .frame(width: size, height: size)
                    .background(background, in: Circle())
                Text(title)
                    .font(size > 80 ? .subheadline.weight(.semibold) : .subheadline.weight(.medium))
                    .foregroundStyle(size > 80 ? Theme.brass : Theme.text)
            }
            .frame(minWidth: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }

    /// The caller's video through the feed that also saves pictures of it, or attached to the
    /// call directly when there is no feed.
    @ViewBuilder
    private func previewVideo(of incoming: BaresipPhoneCall) -> some View {
        if let feed = model.previewFeed, feed.call == incoming.id {
            PreviewVideoView(feed: feed) { view in
                model.snapshots.register(view, for: incoming.id)
            }
        } else {
            BaresipCallVideo(call: incoming) { view in
                model.snapshots.register(view, for: incoming.id)
            }
        }
    }

    private var door: Door? {
        model.door(of: model.incoming)
    }

    private var title: String {
        door?.title ?? model.incoming?.displayName ?? ""
    }

    private var hasVideo: Bool {
        (model.incoming?.hasVideo ?? false) || model.incomingEarlyVideo
    }

    private var previewNote: String {
        let what = model.previewVideo ? "see" : "hear"
        return "You \(what) \(door == nil ? "the caller" : "the door"). They cannot see or hear you."
    }

    private var hint: String {
        if model.ringingDoor != nil {
            return "Open door answers, sends the door code and hangs up."
        }
        return "Your microphone and camera turn on only when you answer."
    }
}
