import SwiftUI
import BaresipKit

/// What the call screen keeps out of the way: transfer, recording, the camera, the sound
/// output and the call's quality.
struct CallMoreView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Card {
                        NavigationLink {
                            TransferView()
                        } label: {
                            LinkRowLabel(title: "Transfer the call", systemImage: "arrow.left.arrow.right")
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                        ToggleRow(title: isRecording ? "Recording this call" : "Record this call",
                                  detail: isRecording ? "Saved to Recordings in the Files app" : nil,
                                  isOn: Binding(get: { isRecording },
                                                set: { _ in Task { await model.toggleRecording() } }))
                            .accessibilityIdentifier("call.record")
                        if model.sendingVideo {
                            RowDivider()
                            CardButton(title: "Switch between front and back camera") {
                                Task { await model.switchCamera() }
                            }
                        }
                        if model.settings.useICE {
                            RowDivider()
                            CardButton(title: "Reconnect the call after a network change") {
                                Task { await model.restartICE() }
                            }
                        }
                    }
                    TitledSection(title: "Sound comes from") {
                        AudioOutputList()
                    }
                    if let stats = model.stats {
                        TitledSection(title: "Call quality") {
                            CallQuality(stats: stats, codec: model.currentRow?.codec ?? "",
                                        useICE: model.settings.useICE,
                                        showsVideo: model.receivingVideo || model.sendingVideo)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bar.ignoresSafeArea())
            .navigationTitle(model.currentDoor?.title ?? model.currentRow?.title ?? "Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.info)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var isRecording: Bool {
        model.recordingCall != nil && model.recordingCall == model.currentCall
    }
}

/// Loss, jitter, round trip and MOS of a call, then how it is carried.
struct CallQuality: View {
    let stats: BaresipCallStatistics
    let codec: String
    let useICE: Bool
    let showsVideo: Bool

    var body: some View {
        VStack(spacing: 8) {
            Grid(horizontalSpacing: 8) {
                GridRow {
                    tile(String(format: "%.1f", stats.mosEstimate), "MOS")
                    tile(String(format: "%.1f %%", Double(stats.audio.receivedFractionLostPermille) / 10), "Loss")
                    tile("\(Self.milliseconds(stats.audio.receivedJitter)) ms", "Jitter")
                    tile("\(Self.milliseconds(stats.audio.roundTripTime)) ms", "Round trip")
                }
            }
            Card(radius: 16) {
                ValueRow(title: "Encryption", value: stats.audio.isSecure ? "SRTP" : "Not encrypted")
                if !codec.isEmpty {
                    RowDivider()
                    ValueRow(title: "Audio codec", value: codec)
                }
                if showsVideo {
                    RowDivider()
                    ValueRow(title: "Video", value: "\(stats.videoTargetBitrate / 1000) kbit/s")
                }
                if useICE {
                    RowDivider()
                    ValueRow(title: "Path", value: stats.localCandidate == .relay ? "Through a relay" : "Direct")
                }
            }
        }
    }

    private func tile(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.display(20))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line))
        .accessibilityElement(children: .combine)
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
