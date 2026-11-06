import SwiftUI
import BaresipKit
import BaresipKitVideo

struct ContentView: View {
    @EnvironmentObject private var model: CallModel
    @State private var speaker = false

    var body: some View {
        NavigationStack {
            Form {
                if let incoming = model.incoming {
                    Section("Incoming call") {
                        Text(incoming.remoteDisplayName.isEmpty ? incoming.remoteURI : "\(incoming.remoteDisplayName) <\(incoming.remoteURI)>")
                            .accessibilityIdentifier("incoming.from")
                        if model.previewing {
                            Label("Previewing: you hear\(model.videoEnabled ? " and see" : "") the caller; they do not hear or see you",
                                  systemImage: "eye")
                                .font(.caption)
                        }
                        HStack {
                            if !model.previewing {
                                Button("Preview") { Task { await model.preview() } }
                                    .accessibilityIdentifier("incoming.preview")
                                Spacer()
                            }
                            Button("Answer") { Task { await model.answer() } }
                                .accessibilityIdentifier("incoming.answer")
                            Spacer()
                            Button("Reject", role: .destructive) { Task { await model.reject() } }
                                .accessibilityIdentifier("incoming.reject")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Section("Account") {
                    NavigationLink {
                        AccountView()
                    } label: {
                        Text(model.settings.isComplete ? model.settings.aor : "Set up account")
                    }
                    .accessibilityIdentifier("account.link")
                    Text(registrationText)
                        .font(.caption)
                        .foregroundStyle(registrationColor)
                        .accessibilityIdentifier("registration.state")
                    if model.settings.isComplete {
                        HStack {
                            Button("Register") { Task { await model.register() } }
                            Spacer()
                            Button("Unregister") { Task { await model.unregister() } }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Section("Call") {
                    TextField("Number, user or SIP URI", text: $model.destination)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("call.destination")
                    HStack {
                        Button("Audio call") { Task { await model.call(video: false) } }
                            .accessibilityIdentifier("call.audio")
                        Spacer()
                        Button("Video call") { Task { await model.call(video: true) } }
                            .accessibilityIdentifier("call.video")
                    }
                    .buttonStyle(.borderless)
                    if let state = model.callState, model.incoming == nil {
                        Text("Call: \(String(describing: state))")
                            .accessibilityIdentifier("call.state")
                        HStack {
                            Button(model.onHold ? "Resume" : "Hold") { Task { await model.toggleHold() } }
                            Button(model.muted ? "Unmute" : "Mute") { Task { await model.toggleMute() } }
                            Button(model.videoEnabled ? "Video off" : "Video on") { Task { await model.toggleVideo() } }
                            Button("Hang up", role: .destructive) { Task { await model.hangup() } }
                                .accessibilityIdentifier("call.hangup")
                        }
                        .buttonStyle(.borderless)
                        HStack {
                            if model.videoEnabled {
                                Button("Switch camera") { Task { await model.switchCamera() } }
                            }
                            if model.settings.useICE {
                                Spacer()
                                Button("Restart ICE") { Task { await model.restartICE() } }
                            }
                        }
                        .buttonStyle(.borderless)
                        Toggle("Speaker", isOn: $speaker).onChange(of: speaker) { _, on in model.toggleSpeaker(on) }
                        DTMFPad { digit in Task { await model.sendDTMF(digit) } }
                    }
                    if let stats = model.stats {
                        Text(String(format: "loss %d‰ jitter %@ rtt %@ mos %.2f",
                                    stats.audio.receivedFractionLostPermille,
                                    "\(stats.audio.receivedJitter)", "\(stats.audio.roundTripTime)",
                                    stats.mosEstimate))
                            .font(.caption)
                        if model.videoEnabled {
                            Text("video target \(stats.videoTargetBitrate / 1000) kbit/s, sent \(stats.video.transmitBitrate / 1000) kbit/s")
                                .font(.caption)
                        }
                        if model.settings.useICE {
                            Text("ICE \(String(describing: stats.iceState)) \(String(describing: stats.localCandidate)) -> \(String(describing: stats.remoteCandidate))")
                                .font(.caption)
                        }
                    }
                }
                if model.videoEnabled, let call = model.currentCall {
                    Section("Video") {
                        VideoPane(callID: call, local: false)
                            .frame(height: 240)
                        VideoPane(callID: call, local: true)
                            .frame(height: 120)
                    }
                }
                Section("Log") {
                    ForEach(Array(model.log.suffix(30).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption2.monospaced())
                    }
                }
            }
            .navigationTitle("BaresipKit")
            .task { await model.start() }
        }
    }

    private var registrationText: String {
        if let error = model.registrationError {
            return "\(String(describing: model.registration)): \(error)"
        }
        return String(describing: model.registration)
    }

    private var registrationColor: Color {
        switch model.registration {
        case .registered: return .green
        case .failed: return .red
        default: return .secondary
        }
    }
}

struct DTMFPad: View {
    let send: (String) -> Void
    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["*", "0", "#"]]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { digit in
                        Button(digit) { send(digit) }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
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

    func makeUIView(context: Context) -> BaresipVideoView {
        let view = BaresipVideoView()
        if let engine = model.engine {
            Task {
                try? await engine.setVideoRenderer(view.renderer, callID: callID, local: local)
            }
        }
        return view
    }

    func updateUIView(_ uiView: BaresipVideoView, context: Context) {}
}
