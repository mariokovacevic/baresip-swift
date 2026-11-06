import SwiftUI
import BaresipKit
import BaresipKitVideo

struct ContentView: View {
    @EnvironmentObject private var model: CallModel
    @State private var speaker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("AOR", text: $model.aor)
                    TextField("Registrar", text: $model.registrar)
                    TextField("Auth user", text: $model.authUser)
                    SecureField("Password", text: $model.password)
                    HStack {
                        Text("State: \(String(describing: model.registration))")
                        Spacer()
                        Button("Register") { Task { await model.register() } }
                    }
                }
                Section("Call") {
                    TextField("Destination", text: $model.destination)
                    HStack {
                        Button("Audio call") { Task { await model.call(video: false) } }
                        Spacer()
                        Button("Video call") { Task { await model.call(video: true) } }
                    }
                    if let state = model.callState {
                        Text("Call: \(String(describing: state))")
                        HStack {
                            Button(model.onHold ? "Resume" : "Hold") { Task { await model.toggleHold() } }
                            Button(model.muted ? "Unmute" : "Mute") { Task { await model.toggleMute() } }
                            Button(model.videoEnabled ? "Video off" : "Video on") { Task { await model.toggleVideo() } }
                            Button("Hang up", role: .destructive) { Task { await model.hangup() } }
                        }
                        Toggle("Speaker", isOn: $speaker).onChange(of: speaker) { _, on in model.toggleSpeaker(on) }
                        DTMFPad { digit in Task { await model.sendDTMF(digit) } }
                    }
                    if let stats = model.stats {
                        Text(String(format: "loss %d‰ jitter %@ rtt %@ mos %.2f",
                                    stats.audio.receivedFractionLostPermille,
                                    "\(stats.audio.receivedJitter)", "\(stats.audio.roundTripTime)",
                                    stats.mosEstimate))
                            .font(.caption)
                    }
                }
                if model.videoEnabled, let call = model.currentCall {
                    Section("Video") {
                        VideoPane(callID: call)
                            .frame(height: 240)
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
            .alert("Incoming call", isPresented: Binding(get: { model.incoming != nil }, set: { _ in })) {
                Button("Answer") { Task { await model.answer() } }
                Button("Reject", role: .cancel) { Task { await model.reject() } }
            } message: {
                Text(model.incoming?.remoteURI ?? "")
            }
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

    func makeUIView(context: Context) -> BaresipVideoView {
        let view = BaresipVideoView()
        if let engine = model.engine {
            Task {
                try? await engine.setVideoRenderer(view.renderer, callID: callID)
            }
        }
        return view
    }

    func updateUIView(_ uiView: BaresipVideoView, context: Context) {}
}
