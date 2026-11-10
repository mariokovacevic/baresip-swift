import SwiftUI
import BaresipKit
import BaresipKitAudio
import BaresipKitSwiftUI
import BaresipKitVideo

struct InCallView: View {
    @EnvironmentObject private var model: CallModel
    @State private var showOutputs = false
    @State private var showKeypad = false
    @State private var showTransfer = false

    var body: some View {
        ZStack {
            Palette.callBackground.ignoresSafeArea()
            if model.receivingVideo, let call = model.activeCall {
                BaresipCallVideo(call: call) { view in
                    model.snapshots.register(view, for: call.id)
                }
                .ignoresSafeArea()
                .accessibilityLabel("Remote video")
            }

            VStack(spacing: 24) {
                HStack {
                    Button {
                        model.callMinimized = true
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Back to calls")
                    Spacer()
                    if model.calls.count > 1 {
                        Text("\(model.calls.count) calls")
                            .font(.footnote)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.darkChip, in: Capsule())
                    }
                }
                .foregroundStyle(.white)

                VStack(spacing: 24) {
                    header
                    statsChips
                    secondaryActions
                }
                // Keep the call details clear of the self-view in the top right corner.
                .padding(.trailing, model.sendingVideo ? Self.selfViewSize.width + 8 : 0)

                Spacer()

                if showKeypad {
                    DTMFPad { digit in Task { await model.sendDTMF(digit) } }
                    Button("Hide keypad") { showKeypad = false }
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                } else {
                    controls
                }

                Button {
                    Task { await model.hangup() }
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(Palette.signalRed, in: Circle())
                }
                .accessibilityLabel("Hang up")
                .accessibilityIdentifier("call.hangup")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)

            if let call = model.activeCall {
                // Your camera, in the top right corner below the top bar, while it is sent.
                BaresipSelfView(call: call, size: Self.selfViewSize)
                    .accessibilityIdentifier("call.selfView")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 52)
                    .padding(.trailing, 16)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showTransfer) {
            TransferView()
                .environmentObject(model)
        }
        .sheet(isPresented: $showOutputs) {
            NavigationStack {
                AudioOutputView()
            }
            .environmentObject(model)
            .presentationDetents([.medium, .large])
        }
    }

    static let selfViewSize = CGSize(width: 100, height: 140)

    private var currentOutput: BaresipAudioOutput? {
        _ = model.audioRouteChanges
        return model.audio?.currentOutput
    }

    private var outputTitle: String {
        guard let output = currentOutput else { return "audio" }
        return output.route == .earpiece ? "audio" : output.name
    }

    private var header: some View {
        VStack(spacing: 8) {
            if !model.receivingVideo {
                Avatar(
                    initials: model.currentRow?.initials ?? "",
                    size: 96,
                    tint: .white,
                    background: Palette.darkButton
                )
            }
            Text(model.currentRow?.title ?? "Call")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(model.currentRow.map { callStatusText($0, now: context.date) } ?? "")
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.78))
                    .accessibilityIdentifier("call.state")
                    .accessibilityValue(model.callState.map { String(describing: $0) } ?? "")
            }
            if let line = securityLine {
                Label(line, systemImage: model.stats?.audio.isSecure == true ? "lock.fill" : "lock.open")
                    .font(.footnote)
                    .foregroundStyle(Color(white: 0.63))
            }
        }
    }

    @ViewBuilder
    private var statsChips: some View {
        if let stats = model.stats {
            HStack(spacing: 8) {
                chip(String(format: "loss %.1f%%", Double(stats.audio.receivedFractionLostPermille) / 10))
                chip("jitter \(ms(stats.audio.receivedJitter)) ms")
                chip("RTT \(ms(stats.audio.roundTripTime)) ms")
                chip(String(format: "MOS %.1f", stats.mosEstimate))
            }
            if model.receivingVideo || model.sendingVideo {
                chip("video \(stats.videoTargetBitrate / 1000) kbit/s")
            }
        }
    }

    private var controls: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 28), count: 3), spacing: 22) {
            CircleButton(
                title: model.muted ? "unmute" : "mute",
                systemImage: model.muted ? "mic.slash.fill" : "mic.fill",
                active: model.muted
            ) {
                Task { await model.toggleMute() }
            }
            CircleButton(title: "keypad", systemImage: "circle.grid.3x3.fill") {
                showKeypad = true
            }
            CircleButton(title: outputTitle, systemImage: outputIcon(currentOutput?.route),
                         active: currentOutput.map { $0.route != .earpiece } ?? false) {
                showOutputs = true
            }
            .accessibilityIdentifier("call.audioOutput")
            CircleButton(title: model.onHold ? "resume" : "hold", systemImage: "pause.fill", active: model.onHold) {
                Task { await model.toggleHold() }
            }
            CircleButton(
                title: "camera",
                systemImage: model.sendingVideo ? "video.fill" : "video.slash.fill",
                active: model.sendingVideo
            ) {
                Task { await model.toggleVideo() }
            }
            CircleButton(title: "transfer", systemImage: "arrow.left.arrow.right") {
                showTransfer = true
            }
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.toggleRecording() }
            } label: {
                Label(isRecording ? "Stop recording" : "Record",
                      systemImage: isRecording ? "stop.circle.fill" : "record.circle")
            }
            .tint(isRecording ? Palette.recording : .white)
            .accessibilityIdentifier("call.record")
            if model.sendingVideo || model.settings.useICE {
                if model.sendingVideo {
                    Button("Switch camera") { Task { await model.switchCamera() } }
                }
                if model.settings.useICE {
                    Button("Restart ICE") { Task { await model.restartICE() } }
                }
            }
        }
        .font(.footnote.weight(.semibold))
        .buttonStyle(.bordered)
    }

    private var isRecording: Bool {
        model.recordingCall != nil && model.recordingCall == model.currentCall
    }

    private var securityLine: String? {
        var parts: [String] = []
        if let stats = model.stats {
            parts.append(stats.audio.isSecure ? "SRTP" : "Not encrypted")
        }
        if let codec = model.currentRow?.codec, !codec.isEmpty {
            parts.append(codec)
        }
        if let stats = model.stats, model.settings.useICE {
            parts.append(stats.localCandidate == .relay ? "ICE relay" : "ICE direct")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color(white: 0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Palette.darkChip, in: Capsule())
    }

    private func ms(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
