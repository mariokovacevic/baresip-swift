#if os(iOS)
    import Foundation
    import AVFoundation
    import BaresipKit

    enum SessionActivation {
        case inactive
        case controller
        case callKit
    }

    enum InterruptionResponse {
        case pauseEngine
        case resumeEngine
        case reactivateSessionAndResumeEngine
        case stayPaused
    }

    extension BaresipAudioSessionController {
        nonisolated static func interruptionResponse(to type: AVAudioSession.InterruptionType,
                                                     options: AVAudioSession.InterruptionOptions,
                                                     activation: SessionActivation) -> InterruptionResponse {
            if type == .began {
                return .pauseEngine
            }
            guard type == .ended, options.contains(.shouldResume) else { return .stayPaused }
            switch activation {
            case .controller: return .reactivateSessionAndResumeEngine
            case .callKit: return .stayPaused
            case .inactive: return .resumeEngine
            }
        }

        nonisolated static func reactivatesSession(afterResetWith activation: SessionActivation) -> Bool {
            activation == .controller
        }

        func interruption(_ type: AVAudioSession.InterruptionType,
                          options: AVAudioSession.InterruptionOptions) async {
            switch Self.interruptionResponse(to: type, options: options, activation: activation) {
            case .pauseEngine:
                await engine.audioInterruption(began: true)
            case .resumeEngine:
                await engine.audioInterruption(began: false)
            case .reactivateSessionAndResumeEngine:
                await reactivateSessionAndResumeEngine()
            case .stayPaused:
                break
            }
        }

        func mediaServicesWereReset() async {
            if let voipOptions {
                try? session.setCategory(.playAndRecord, mode: .voiceChat, options: voipOptions)
            }
            if Self.reactivatesSession(afterResetWith: activation) {
                try? await Self.setActive(true, options: [], on: session)
            }
            await engine.audioRouteDidChange()
        }

        private func reactivateSessionAndResumeEngine() async {
            do {
                try await Self.setActive(true, options: [], on: session)
            } catch {
                return
            }
            switch activation {
            case .controller:
                await engine.audioInterruption(began: false)
            case .inactive:
                try? await Self.setActive(false, options: [.notifyOthersOnDeactivation], on: session)
            case .callKit:
                break
            }
        }
    }
#endif
