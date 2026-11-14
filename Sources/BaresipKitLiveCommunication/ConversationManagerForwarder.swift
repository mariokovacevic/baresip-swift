#if os(iOS)
    import AVFoundation
    import Foundation
    import LiveCommunicationKit

    @available(iOS 17.4, *)
    final class ConversationManagerForwarder: ConversationManagerDelegate, @unchecked Sendable {
        weak var adapter: BaresipLiveCommunicationAdapter?

        func conversationManagerDidBegin(_ manager: ConversationManager) {
            adapter?.conversationManagerDidBegin(manager)
        }

        func conversationManagerDidReset(_ manager: ConversationManager) {
            adapter?.conversationManagerDidReset(manager)
        }

        func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {
            adapter?.conversationManager(manager, conversationChanged: conversation)
        }

        func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {
            adapter?.conversationManager(manager, didActivate: audioSession)
        }

        func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
            adapter?.conversationManager(manager, didDeactivate: audioSession)
        }

        func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
            guard let adapter else { return action.fail() }
            adapter.conversationManager(manager, perform: action)
        }

        func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) {
            adapter?.conversationManager(manager, timedOutPerforming: action)
        }
    }
#endif
