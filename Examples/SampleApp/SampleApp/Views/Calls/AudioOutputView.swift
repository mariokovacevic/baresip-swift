import SwiftUI
import AVKit
import BaresipKitAudio

func outputIcon(_ route: BaresipAudioRoute?) -> String {
    switch route {
    case .speaker: return "speaker.wave.3.fill"
    case .bluetooth: return "airpodspro"
    case .wiredHeadset: return "headphones"
    case .earpiece, .none: return "iphone"
    case .other: return "hifispeaker.fill"
    }
}

/// Lets the user pick where call audio plays: iPhone, speaker, headphones, Bluetooth or a car.
struct AudioOutputView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(outputs) { output in
                    Button {
                        model.selectOutput(output)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: outputIcon(output.route))
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            Text(output.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if output.id == current?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Palette.blue)
                                    .accessibilityLabel("Selected")
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                HStack(spacing: 12) {
                    RoutePicker()
                        .frame(width: 28, height: 28)
                    Text("Other devices")
                    Spacer()
                }
                .frame(minHeight: 44)
            } footer: {
                Text("AirPlay and Bluetooth devices without a microphone are chosen in the system picker.")
            }
        }
        .navigationTitle("Audio output")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var outputs: [BaresipAudioOutput] {
        _ = model.audioRouteChanges
        return model.audio?.availableOutputs ?? [.speaker]
    }

    private var current: BaresipAudioOutput? {
        _ = model.audioRouteChanges
        return model.audio?.currentOutput
    }
}

/// The system route picker button.
struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
