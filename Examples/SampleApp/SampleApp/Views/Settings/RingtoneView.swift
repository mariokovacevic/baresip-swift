import AVFoundation
import SwiftUI

/// Picks what a ringing call plays: the iPhone's ringtone or one of the app's sounds, which
/// plays once when it is picked.
struct RingtoneView: View {
    @EnvironmentObject private var model: CallModel
    @State private var player: AVAudioPlayer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(title: "Ringtone")
                Card {
                    ForEach(Array(Ringtone.allCases.enumerated()), id: \.element) { index, ringtone in
                        if index > 0 {
                            RowDivider()
                        }
                        row(ringtone)
                    }
                }
                Note(text: note)
            }
            .padding(16)
        }
        .titledScreen("Ringtone")
        .onDisappear {
            player?.stop()
            player = nil
        }
    }

    private var note: String {
        if model.ringtone == .iPhone {
            return "Calls ring with the ringtone set in the Settings app, under Sounds & Haptics."
        }
        return """
        Calls ring with this sound on the iPhone's call screen; with LiveCommunicationKit from \
        the next call on. The simulator shows no call screen, so it plays no ringtone.
        """
    }

    private func row(_ ringtone: Ringtone) -> some View {
        Button {
            model.ringtone = ringtone
            preview(ringtone)
        } label: {
            HStack(spacing: 12) {
                Text(ringtone.title)
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                if model.ringtone == ringtone {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.brass)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.ringtone == ringtone ? .isSelected : [])
        .accessibilityIdentifier("ringtone.\(ringtone.id)")
    }

    /// Plays an app sound once; not during a call, whose audio it would disturb.
    private func preview(_ ringtone: Ringtone) {
        player?.stop()
        player = nil
        guard model.activeCall == nil, let url = ringtone.url else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
