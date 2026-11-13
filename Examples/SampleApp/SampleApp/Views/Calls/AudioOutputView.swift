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

/// Where call audio plays: iPhone, speaker, headphones, Bluetooth or a car, and the system
/// picker for the rest.
struct AudioOutputList: View {
    @EnvironmentObject private var model: CallModel
    var onSelect: () -> Void = {}

    var body: some View {
        Card {
            ForEach(outputs) { output in
                Button {
                    model.selectOutput(output)
                    onSelect()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: outputIcon(output.route))
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(output.name)
                            .foregroundStyle(Theme.text)
                        Spacer()
                        if output.id == current?.id {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.info)
                                .accessibilityLabel("Selected")
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                RowDivider()
            }
            HStack(spacing: 12) {
                RoutePicker()
                    .frame(width: 24, height: 24)
                Text("Other devices")
                    .foregroundStyle(Theme.info)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
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

struct AudioOutputView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AudioOutputList { dismiss() }
                Note(text: "AirPlay and Bluetooth devices without a microphone are chosen in Other devices.")
            }
            .padding(16)
        }
        .background(Theme.bar.ignoresSafeArea())
        .navigationTitle("Sound comes from")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .tint(Theme.info)
    }
}

/// The system route picker button.
struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = UIColor(Theme.info)
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
