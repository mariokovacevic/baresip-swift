#if os(iOS)
    import AVFoundation
    import CallKit
    import Foundation

    final class ProviderDelegate: NSObject, CXProviderDelegate, @unchecked Sendable {
        weak var adapter: BaresipCallKitAdapter?

        func providerDidReset(_ provider: CXProvider) {
            adapter?.providerDidReset(provider)
        }

        func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
            guard let adapter else { return action.fail() }
            adapter.provider(provider, perform: action)
        }

        func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
            guard let adapter else { return action.fail() }
            adapter.provider(provider, perform: action)
        }

        func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
            guard let adapter else { return action.fail() }
            adapter.provider(provider, perform: action)
        }

        func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
            guard let adapter else { return action.fail() }
            adapter.provider(provider, perform: action)
        }

        func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
            guard let adapter else { return action.fail() }
            adapter.provider(provider, perform: action)
        }

        func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
            guard let adapter else { return action.fail() }
            adapter.provider(provider, perform: action)
        }

        func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
            adapter?.provider(provider, timedOutPerforming: action)
        }

        func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
            adapter?.provider(provider, didActivate: audioSession)
        }

        func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
            adapter?.provider(provider, didDeactivate: audioSession)
        }
    }
#endif
