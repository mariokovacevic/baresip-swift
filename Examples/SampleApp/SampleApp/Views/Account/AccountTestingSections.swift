import SwiftUI
import BaresipKit

/// NAT traversal settings of the Account screen.
struct AccountNATSection: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        Section {
            Picker("Traversal", selection: $model.settings.natMode) {
                Text("None").tag(BaresipNATTraversal.none)
                Text("STUN").tag(BaresipNATTraversal.stun)
                Text("ICE").tag(BaresipNATTraversal.ice)
            }
            .accessibilityIdentifier("account.nat")
            if model.settings.natMode != .none {
                TextField("STUN URI (optional)", text: $model.settings.stunURI,
                          prompt: Text("stun:stun.example.com"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if model.settings.natMode == .ice {
                TextField("TURN URI (optional)", text: $model.settings.turnURI,
                          prompt: Text("turns:turn.example.com:5349"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("TURN user", text: $model.settings.turnUser)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("TURN password", text: $model.turnPassword)
                Toggle("Relay only (TURN)", isOn: $model.settings.engine.iceRelayOnly)
            }
            Toggle("RTCP on the RTP port (rtcp-mux)", isOn: $model.settings.rtcpMux)
            Toggle("Open NAT pinhole while previewing", isOn: $model.settings.pinhole)
            Stepper(value: $model.settings.rtpTimeoutSeconds, in: 0 ... 300, step: 10) {
                LabeledContent("RTP timeout",
                               value: model.settings.rtpTimeoutSeconds == 0
                                   ? "Off" : "\(model.settings.rtpTimeoutSeconds) s")
            }
            Toggle("IPv6", isOn: $model.settings.engine.ipv6)
        } header: {
            Text("NAT")
        } footer: {
            Text(
                """
                STUN only learns the public address; ICE also checks paths and can use a TURN relay. \
                Relay only forces media through TURN. The pinhole sends empty RTP packets during a \
                preview, so media relays such as rtpengine forward the caller's media even without ICE. \
                A call without RTP for the timeout ends. Relay only and IPv6 restart the engine.
                """
            )
        }
    }
}

/// SIP behaviour settings of the Account screen.
struct AccountSIPSection: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        Section {
            Toggle("SIP Outbound (RFC 5626)", isOn: $model.settings.sipOutbound)
            Stepper(value: $model.settings.registerExpiresSeconds, in: 60 ... 3600, step: 60) {
                LabeledContent("Registration", value: "\(model.settings.registerExpiresSeconds / 60) min")
            }
            Picker("DTMF", selection: $model.settings.dtmfMode) {
                Text("Automatic").tag(BaresipDTMFMode.auto)
                Text("RFC 4733").tag(BaresipDTMFMode.rtpEvent)
                Text("SIP INFO").tag(BaresipDTMFMode.sipInfo)
            }
            Toggle("Accept transfers", isOn: $model.settings.acceptTransfers)
        } header: {
            Text("SIP")
        } footer: {
            Text(
                """
                SIP Outbound keeps the registration flow open through NAT. Door stations take \
                door-opening codes as SIP INFO; Automatic sends RFC 4733 events when the peer supports \
                them and SIP INFO otherwise.
                """
            )
        }
    }
}

/// Codec and video settings of the Account screen.
struct AccountCodecSection: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        Section {
            TextField("Audio codecs", text: $model.settings.audioCodecs, prompt: Text("Default"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Video codecs", text: $model.settings.videoCodecs, prompt: Text("Default"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Picker("Video size", selection: $model.settings.engine.videoHeight) {
                ForEach(EngineOptions.videoHeights, id: \.self) { height in
                    Text(height == 0 ? "Default" : "\(EngineOptions.width(forHeight: height))×\(height)")
                        .tag(height)
                }
            }
            Picker("Frame rate", selection: $model.settings.engine.videoFramesPerSecond) {
                ForEach(EngineOptions.videoFrameRates, id: \.self) { rate in
                    Text(rate == 0 ? "Default" : "\(rate) fps").tag(rate)
                }
            }
            Picker("Video bitrate", selection: $model.settings.engine.videoBitrateKbps) {
                ForEach(EngineOptions.videoBitrates, id: \.self) { rate in
                    Text(rate == 0 ? "Default" : "\(rate) kbit/s").tag(rate)
                }
            }
            Toggle("Adaptive video bitrate", isOn: $model.settings.engine.adaptiveBitrate)
        } header: {
            Text("Codecs and video")
        } footer: {
            Text(
                """
                Codecs in order of preference, separated by commas, for example "opus, G722, PCMA" or \
                "H264". Empty offers every codec. Video size, frame rate, bitrate and adaptive bitrate \
                restart the engine.
                """
            )
        }
    }
}
