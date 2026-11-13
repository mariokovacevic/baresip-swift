import SwiftUI
import BaresipKit

/// Incoming call and media settings of the Account screen.
struct AccountCallSections: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        TitledSection(title: "Incoming calls", note: """
        Every incoming call is previewed with 183 Session Progress: the caller's media is received \
        before answering, for example from a door station, while your microphone and camera stay off. \
        Off receives only the picture when the caller offers video. On a phone iOS plays the audio only \
        once the call is answered. Reachable keeps the registration on the server, so a VoIP push can \
        announce a call while the app is closed.
        """) {
            Card {
                ToggleRow(title: "Stay reachable by push", isOn: $model.settings.reachableInBackground)
                RowDivider()
                ToggleRow(title: "Audio in the preview", isOn: $model.settings.previewAudio)
                RowDivider()
                ToggleRow(title: "Accept transfers", isOn: $model.settings.acceptTransfers)
            }
        }
        TitledSection(title: "Media", note: """
        Picture updates also ask for a new video picture with SIP INFO, for door stations that ignore RTCP.
        """) {
            Card {
                MenuRow(title: "Encryption", selection: $model.settings.mediaEncryption) {
                    Text("SRTP optional").tag(BaresipMediaEncryption.srtpOptional)
                    Text("SRTP required").tag(BaresipMediaEncryption.srtpMandatory)
                    Text("DTLS-SRTP").tag(BaresipMediaEncryption.dtlsSRTP)
                    Text("None").tag(BaresipMediaEncryption.none)
                }
                RowDivider()
                ToggleRow(title: "Picture updates over SIP INFO", isOn: $model.settings.pictureUpdateOverInfo)
            }
        }
    }
}

/// NAT traversal settings of the Account screen.
struct AccountNATSection: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        TitledSection(title: "NAT", note: """
        STUN only learns the public address; ICE also checks paths and can use a TURN relay. Relay only \
        forces media through TURN. The pinhole sends empty RTP packets during a preview, so media relays \
        such as rtpengine forward the caller's media even without ICE. A call without RTP for the timeout \
        ends. Relay only and IPv6 restart the engine.
        """) {
            Card {
                SegmentRow(title: "Traversal", selection: $model.settings.natMode, identifier: "account.nat") {
                    Text("None").tag(BaresipNATTraversal.none)
                    Text("STUN").tag(BaresipNATTraversal.stun)
                    Text("ICE").tag(BaresipNATTraversal.ice)
                }
                if model.settings.natMode != .none {
                    RowDivider()
                    FieldRow(title: "STUN server", text: $model.settings.stunURI, prompt: "stun:stun.example.com")
                }
                if model.settings.natMode == .ice {
                    RowDivider()
                    FieldRow(title: "TURN server", text: $model.settings.turnURI,
                             prompt: "turns:turn.example.com:5349")
                    RowDivider()
                    FieldRow(title: "TURN user", text: $model.settings.turnUser, prompt: "None")
                    RowDivider()
                    FieldRow(title: "TURN password", text: $model.turnPassword, prompt: "None", secure: true)
                    RowDivider()
                    ToggleRow(title: "Relay only (TURN)", isOn: $model.settings.engine.iceRelayOnly)
                }
                RowDivider()
                ToggleRow(title: "RTCP on the RTP port", isOn: $model.settings.rtcpMux)
                RowDivider()
                ToggleRow(title: "NAT pinhole while previewing", isOn: $model.settings.pinhole)
                RowDivider()
                StepperRow(title: "RTP timeout", value: rtpTimeout, number: $model.settings.rtpTimeoutSeconds,
                           range: 0 ... 300, step: 10)
                RowDivider()
                ToggleRow(title: "IPv6", isOn: $model.settings.engine.ipv6)
            }
        }
    }
}

private extension AccountNATSection {
    var rtpTimeout: String {
        model.settings.rtpTimeoutSeconds == 0 ? "Off" : "\(model.settings.rtpTimeoutSeconds) s"
    }
}

/// SIP behaviour settings of the Account screen.
struct AccountSIPSection: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        TitledSection(title: "SIP", note: """
        SIP Outbound keeps the registration flow open through NAT. Door stations take door-opening codes \
        as SIP INFO; Automatic sends RFC 4733 events when the peer supports them and SIP INFO otherwise.
        """) {
            Card {
                ToggleRow(title: "SIP Outbound (RFC 5626)", isOn: $model.settings.sipOutbound)
                RowDivider()
                MenuRow(title: "Registration lasts", selection: $model.settings.registerExpiresSeconds) {
                    ForEach(registrationTimes, id: \.self) { seconds in
                        Text(Self.duration(seconds)).tag(seconds)
                    }
                }
                RowDivider()
                MenuRow(title: "DTMF", selection: $model.settings.dtmfMode) {
                    Text("Automatic").tag(BaresipDTMFMode.auto)
                    Text("RFC 4733").tag(BaresipDTMFMode.rtpEvent)
                    Text("SIP INFO").tag(BaresipDTMFMode.sipInfo)
                }
            }
        }
    }

    /// A day or more keeps the registration, and with it the push token, while the app is suspended.
    private var registrationTimes: [Int] {
        Array(Set([300, 600, 3600, 86400, 604_800, model.settings.registerExpiresSeconds])).sorted()
    }

    static func duration(_ seconds: Int) -> String {
        if seconds % 86400 == 0 {
            let days = seconds / 86400
            return days == 1 ? "1 day" : "\(days) days"
        }
        if seconds % 3600 == 0 {
            let hours = seconds / 3600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(seconds / 60) min"
    }
}

/// Codec and video settings of the Account screen.
struct AccountCodecSection: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        TitledSection(title: "Codecs and video", note: """
        Codecs in order of preference, separated by commas, for example "opus, G722, PCMA" or "H264". \
        Empty offers every codec. Video size, frame rate, bitrate and adaptive bitrate restart the engine.
        """) {
            Card {
                FieldRow(title: "Audio codecs", text: $model.settings.audioCodecs, prompt: "Default")
                RowDivider()
                FieldRow(title: "Video codecs", text: $model.settings.videoCodecs, prompt: "Default")
                RowDivider()
                MenuRow(title: "Video size", selection: $model.settings.engine.videoHeight) {
                    ForEach(EngineOptions.videoHeights, id: \.self) { height in
                        Text(height == 0 ? "Default" : "\(EngineOptions.width(forHeight: height)) x \(height)")
                            .tag(height)
                    }
                }
                RowDivider()
                MenuRow(title: "Frame rate", selection: $model.settings.engine.videoFramesPerSecond) {
                    ForEach(EngineOptions.videoFrameRates, id: \.self) { rate in
                        Text(rate == 0 ? "Default" : "\(rate) per second").tag(rate)
                    }
                }
                RowDivider()
                MenuRow(title: "Video bitrate", selection: $model.settings.engine.videoBitrateKbps) {
                    ForEach(EngineOptions.videoBitrates, id: \.self) { rate in
                        Text(rate == 0 ? "Default" : "\(rate) kbit/s").tag(rate)
                    }
                }
                RowDivider()
                ToggleRow(title: "Adaptive video bitrate", isOn: $model.settings.engine.adaptiveBitrate)
            }
        }
    }
}
