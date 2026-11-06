import SwiftUI
import BaresipKit
import BaresipKitVideo

enum Palette {
    static let blue = Color(red: 0.0, green: 0.388, blue: 0.8)
    static let green = Color(red: 0.141, green: 0.541, blue: 0.239)
    static let destructive = Color(red: 0.843, green: 0.0, blue: 0.082)
    static let secondaryText = Color(red: 0.424, green: 0.424, blue: 0.439)
    static let darkButton = Color(red: 0.227, green: 0.227, blue: 0.235)
    static let darkChip = Color(red: 0.173, green: 0.173, blue: 0.180)
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(Palette.secondaryText)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Avatar: View {
    let initials: String
    var size: CGFloat = 40
    var tint: Color = Palette.secondaryText
    var background: Color = Color(.systemGray6)

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .accessibilityHidden(true)
    }
}

struct CircleButton: View {
    let title: String
    let systemImage: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .regular))
                    .frame(width: 76, height: 76)
                    .foregroundStyle(active ? Color.black : Color.white)
                    .background(active ? Color.white : Palette.darkButton, in: Circle())
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

struct DTMFPad: View {
    let send: (String) -> Void
    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["*", "0", "#"]]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { digit in
                        Button(digit) { send(digit) }
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Palette.darkButton, in: Circle())
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct VideoPane: UIViewRepresentable {
    @EnvironmentObject private var model: CallModel
    let callID: BaresipCallID
    let local: Bool

    final class Coordinator {
        var attachedCall: BaresipCallID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BaresipVideoView {
        let view = BaresipVideoView()
        attach(view, context: context)
        return view
    }

    func updateUIView(_ uiView: BaresipVideoView, context: Context) {
        attach(uiView, context: context)
    }

    private func attach(_ view: BaresipVideoView, context: Context) {
        guard context.coordinator.attachedCall != callID, let engine = model.engine else { return }
        context.coordinator.attachedCall = callID
        let renderer = view.renderer
        let call = callID
        let local = local
        Task {
            try? await engine.setVideoRenderer(renderer, callID: call, local: local)
        }
    }
}

func formatDuration(since start: Date?, now: Date) -> String {
    guard let start else { return "00:00" }
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}

func callStatusText(_ row: CallRow, now: Date) -> String {
    switch row.state {
    case .incoming: return "Incoming"
    case .outgoingInit: return "Calling…"
    case .outgoingRinging: return "Ringing…"
    case .earlyMedia: return "Connecting…"
    case .connected, .streamsRunning, .updating, .resuming: return formatDuration(since: row.connectedAt, now: now)
    case .pausing, .paused: return "On hold · " + formatDuration(since: row.connectedAt, now: now)
    case .pausedByRemote: return "Held by the other side"
    case .ended, .failed, .released: return "Ended"
    }
}
