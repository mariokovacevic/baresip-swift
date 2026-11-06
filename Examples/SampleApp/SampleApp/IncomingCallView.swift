import SwiftUI
import BaresipKit

struct IncomingCallView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color(red: 0.173, green: 0.173, blue: 0.18)
                if model.previewing, model.previewVideo, let incoming = model.incoming {
                    VideoPane(callID: incoming.id, local: false)
                        .accessibilityLabel("Caller's video")
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: hasVideo ? "video" : "person.wave.2")
                            .font(.system(size: 48, weight: .light))
                        Text(hasVideo ? "Tap Preview to see the caller" : "Tap Preview to hear the caller")
                            .font(.footnote)
                    }
                    .foregroundStyle(Color(white: 0.56))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasVideo ? "Incoming video call" : "Incoming call")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.78))
                    Text(title)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(model.incoming?.remoteURI ?? "")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.78))
                        .lineLimit(1)
                    Spacer()
                    if model.previewing {
                        Label("Previewing · they can't hear or see you", systemImage: "eye")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white, in: Capsule())
                    } else {
                        Button {
                            Task { await model.preview() }
                        } label: {
                            Label("Preview", systemImage: "eye")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(.white, in: Capsule())
                        }
                        .accessibilityIdentifier("incoming.preview")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 18)
            }
            .frame(height: 470)

            VStack(spacing: 28) {
                Spacer()
                Text(model.previewing
                    ? "You hear the caller\(model.previewVideo ? " and see their video" : ""). Your microphone and camera turn on when you answer."
                    : "Answer, decline, or preview the call first without being heard or seen.")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.78))
                    .multilineTextAlignment(.center)
                HStack {
                    callButton(title: "Decline", systemImage: "phone.down.fill",
                               color: Color(red: 1.0, green: 0.231, blue: 0.188), id: "incoming.reject") {
                        Task { await model.reject() }
                    }
                    Spacer()
                    callButton(title: "Answer", systemImage: "phone.fill",
                               color: Color(red: 0.188, green: 0.82, blue: 0.345), id: "incoming.answer") {
                        Task { await model.answer() }
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 48)
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .preferredColorScheme(.dark)
    }

    private var hasVideo: Bool {
        (model.incoming?.hasVideo ?? false) || model.incomingEarlyVideo
    }

    private var title: String {
        guard let incoming = model.incoming else { return "" }
        return incoming.remoteDisplayName.isEmpty ? CallRow.displayName(incoming.remoteURI) : incoming.remoteDisplayName
    }

    private func callButton(title: String, systemImage: String, color: Color, id: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(color, in: Circle())
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }
}
