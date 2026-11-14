#if os(iOS)
    import Foundation
    import PushKit

    final class PushRegistryDelegate: NSObject, PKPushRegistryDelegate, @unchecked Sendable {
        weak var adapter: BaresipPushKitAdapter?

        func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials,
                          for type: PKPushType) {
            adapter?.pushRegistry(registry, didUpdate: pushCredentials, for: type)
        }

        func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
            adapter?.pushRegistry(registry, didInvalidatePushTokenFor: type)
        }

        func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                          for type: PKPushType, completion: @escaping () -> Void) {
            guard let adapter else { return completion() }
            adapter.pushRegistry(registry, didReceiveIncomingPushWith: payload, for: type, completion: completion)
        }
    }
#endif
