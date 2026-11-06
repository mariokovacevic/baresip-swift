import SwiftUI
import BaresipKit

struct InCallView: View {
    @EnvironmentObject private var model: CallModel
    @State private var speaker = false
    @State private var showKeypad = false
    @State private var showTransfer = false

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.118).ignoresSafeArea()
            if model.videoEnabled, let call = model.currentCall {
                VideoPane(callID: call, local: false)
                    .ignoresSafeArea()
                    .accessibilityLabel("Remote video")
                VStack {
                    HStack {
                        Spacer()
                        VideoPane(callID: call, local: true)
                            .frame(width: 110, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Your camera")
                    }
                    Spacer()
                }
                .padding(.top, 56)
                .padding(.horizontal, 16)
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

                header
                statsChips
                secondaryActions

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
                        .background(Color(red: 1.0, green: 0.231, blue: 0.188), in: Circle())
                }
                .accessibilityLabel("Hang up")
                .accessibilityIdentifier("call.hangup")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showTransfer) {
            TransferView()
                .environmentObject(model)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            if !model.videoEnabled {
                Avatar(initials: model.currentRow?.initials ?? "", size: 96, tint: .white, background: Palette.darkButton)
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
            if model.videoEnabled {
                chip("video \(stats.videoTargetBitrate / 1000) kbit/s")
            }
        }
    }

    private var controls: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 28), count: 3), spacing: 22) {
            CircleButton(title: model.muted ? "unmute" : "mute", systemImage: model.muted ? "mic.slash.fill" : "mic.fill", active: model.muted) {
                Task { await model.toggleMute() }
            }
            CircleButton(title: "keypad", systemImage: "circle.grid.3x3.fill") {
                showKeypad = true
            }
            CircleButton(title: "speaker", systemImage: "speaker.wave.2.fill", active: speaker) {
                speaker.toggle()
                model.toggleSpeaker(speaker)
            }
            CircleButton(title: model.onHold ? "resume" : "hold", systemImage: "pause.fill", active: model.onHold) {
                Task { await model.toggleHold() }
            }
            CircleButton(title: "video", systemImage: model.videoEnabled ? "video.fill" : "video.slash.fill", active: model.videoEnabled) {
                Task { await model.toggleVideo() }
            }
            CircleButton(title: "transfer", systemImage: "arrow.left.arrow.right") {
                showTransfer = true
            }
        }
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if model.videoEnabled || model.settings.useICE {
            HStack(spacing: 12) {
                if model.videoEnabled {
                    Button("Switch camera") { Task { await model.switchCamera() } }
                }
                if model.settings.useICE {
                    Button("Restart ICE") { Task { await model.restartICE() } }
                }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.white)
        }
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
