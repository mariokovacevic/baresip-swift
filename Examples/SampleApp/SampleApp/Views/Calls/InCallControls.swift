import SwiftUI
import BaresipKit
import BaresipKitAudio

/// The lower part of the call screen: the controls or the keypad, then Open door and Hang up.
struct InCallControls: View {
    @EnvironmentObject private var model: CallModel
    @Binding var showMore: Bool
    @Binding var showOutputs: Bool
    @State private var showKeypad = false
    @State private var digits = ""

    var body: some View {
        VStack(spacing: 16) {
            if showKeypad {
                keypad
            } else {
                controls
            }
            HStack(spacing: 12) {
                if model.currentDoor != nil {
                    Button {
                        Task { await model.openCurrentDoor() }
                    } label: {
                        Label(model.currentDoorOpened ? "Open again" : "Open door", systemImage: "key")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(FilledButtonStyle(kind: model.currentDoorOpened ? .softBrass : .brass, height: 64,
                                                   radius: 18))
                    .accessibilityIdentifier("call.openDoor")
                    hangUpButton
                        .buttonStyle(HangUpButtonStyle(size: 64))
                } else {
                    hangUpButton
                        .buttonStyle(FilledButtonStyle(kind: .danger, height: 64, radius: 18))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .background(Theme.bar.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.barLine).frame(height: 1)
        }
    }

    private var hangUpButton: some View {
        Button {
            Task { await model.hangup() }
        } label: {
            if model.currentDoor != nil {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .semibold))
            } else {
                Label("End call", systemImage: "phone.down.fill")
                    .font(.title3.weight(.semibold))
            }
        }
        .accessibilityLabel("Hang up")
        .accessibilityIdentifier("call.hangup")
    }

    private var controls: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 14) {
            GridRow {
                CallControl(title: model.muted ? "Muted" : "Mute",
                            systemImage: model.muted ? "mic.slash.fill" : "mic", active: model.muted) {
                    Task { await model.toggleMute() }
                }
                CallControl(title: outputTitle, systemImage: outputIcon(currentOutput?.route),
                            active: currentOutput.map { $0.route != .earpiece } ?? false) {
                    showOutputs = true
                }
                .accessibilityIdentifier("call.audioOutput")
                CallControl(title: "My camera", systemImage: model.sendingVideo ? "video.fill" : "video.slash",
                            active: model.sendingVideo) {
                    Task { await model.toggleVideo() }
                }
            }
            GridRow {
                CallControl(title: "Keypad", systemImage: "circle.grid.3x3.fill") {
                    showKeypad = true
                }
                CallControl(title: model.onHold ? "Resume" : "Hold", systemImage: "pause", active: model.onHold) {
                    Task { await model.toggleHold() }
                }
                CallControl(title: "More", systemImage: "ellipsis") {
                    showMore = true
                }
                .accessibilityIdentifier("call.more")
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(digits.isEmpty ? "Tones go to the other side" : digits)
                    .font(digits.isEmpty ? .subheadline : .displayMedium(26))
                    .tracking(digits.isEmpty ? 0 : 2)
                    .foregroundStyle(digits.isEmpty ? Theme.secondary : Theme.text)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Hide keypad") {
                    showKeypad = false
                    digits = ""
                }
                .buttonStyle(FilledButtonStyle(kind: .raised, height: 44, radius: 22, expands: false))
            }
            DialPad(keySize: 52, showsLetters: false) { digit in
                digits.append(digit)
                Task { await model.sendDTMF(digit) }
            }
        }
    }

    private var currentOutput: BaresipAudioOutput? {
        _ = model.audioRouteChanges
        return model.audio?.currentOutput
    }

    private var outputTitle: String {
        guard let output = currentOutput, output.route != .earpiece else { return "Speaker" }
        return output.name
    }
}
