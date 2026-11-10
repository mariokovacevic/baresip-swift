#if os(iOS)
    import Foundation
    import AVFoundation
    import UIKit
    import BaresipKit

    extension BaresipAudioSessionController {
        /// Routes audio to the loudspeaker or back to the default route.
        ///
        /// - Parameter enabled: `true` for the loudspeaker.
        /// - Throws: The `AVAudioSession` error.
        public func setSpeakerEnabled(_ enabled: Bool) throws {
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
        }

        /// The current output route.
        public var currentRoute: BaresipAudioRoute {
            guard let output = session.currentRoute.outputs.first else { return .other("none") }
            return Self.route(for: output.portType)
        }

        /// The route an AVFoundation port type belongs to.
        ///
        /// - Parameter portType: An input or output port type.
        /// - Returns: The matching route.
        nonisolated static func route(for portType: AVAudioSession.Port) -> BaresipAudioRoute {
            switch portType {
            case .builtInReceiver: return .earpiece
            case .builtInSpeaker: return .speaker
            case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE: return .bluetooth
            case .headphones, .headsetMic, .usbAudio: return .wiredHeadset
            default: return .other(portType.rawValue)
            }
        }

        /// The outputs the user can pick for call audio right now: the earpiece (unless headphones
        /// are plugged in, which replace it), the loudspeaker, each headset or car kit that also has
        /// a microphone, and whatever external output is currently in use.
        ///
        /// Outputs without a microphone that are not in use, such as an AirPlay speaker, are chosen
        /// with the system route picker (`AVRoutePickerView`) instead.
        public var availableOutputs: [BaresipAudioOutput] {
            var outputs: [BaresipAudioOutput] = []
            let route = session.currentRoute
            let wired = route.outputs.contains { $0.portType == .headphones } ||
                (session.availableInputs ?? []).contains { $0.portType == .headsetMic }
            if !wired, Self.hasEarpiece {
                outputs.append(.earpiece)
            }
            outputs.append(.speaker)
            for port in session.availableInputs ?? [] where port.portType != .builtInMic {
                outputs.append(BaresipAudioOutput(id: port.uid, name: Self.name(for: port),
                                                  route: Self.route(for: port.portType)))
            }
            for port in route.outputs
                where port.portType != .builtInReceiver && port.portType != .builtInSpeaker &&
                !outputs.contains(where: { $0.id == port.uid || $0.name == port.portName }) {
                outputs.append(BaresipAudioOutput(id: port.uid, name: Self.name(for: port),
                                                  route: Self.route(for: port.portType)))
            }
            return outputs
        }

        /// The output call audio is playing on, as listed by ``availableOutputs``.
        public var currentOutput: BaresipAudioOutput? {
            let outputs = availableOutputs
            let route = session.currentRoute
            guard let output = route.outputs.first else { return nil }
            switch output.portType {
            case .builtInReceiver: return outputs.first { $0.id == BaresipAudioOutput.earpiece.id }
            case .builtInSpeaker: return outputs.first { $0.id == BaresipAudioOutput.speaker.id }
            default:
                if let input = route.inputs.first, let match = outputs.first(where: { $0.id == input.uid }) {
                    return match
                }
                return outputs.first { $0.id == output.uid || $0.name == output.portName }
            }
        }

        /// Plays call audio on the given output, and records from its microphone when it has one.
        ///
        /// - Parameter output: One of ``availableOutputs``.
        /// - Throws: The `AVAudioSession` error.
        public func selectOutput(_ output: BaresipAudioOutput) throws {
            if output.id == BaresipAudioOutput.speaker.id {
                try session.overrideOutputAudioPort(.speaker)
                return
            }
            try session.overrideOutputAudioPort(.none)
            let inputs = session.availableInputs ?? []
            if output.id == BaresipAudioOutput.earpiece.id {
                try session.setPreferredInput(inputs.first { $0.portType == .builtInMic })
            } else if let port = inputs.first(where: { $0.uid == output.id }) {
                try session.setPreferredInput(port)
            } else {
                try session.setPreferredInput(nil)
            }
        }

        private static var hasEarpiece: Bool {
            UIDevice.current.userInterfaceIdiom == .phone
        }

        private static func name(for port: AVAudioSessionPortDescription) -> String {
            switch port.portType {
            case .headsetMic, .headphones: return "Headphones"
            default: return port.portName
            }
        }
    }
#endif
