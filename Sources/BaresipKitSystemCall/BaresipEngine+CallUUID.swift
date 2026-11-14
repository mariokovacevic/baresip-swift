import Foundation
import BaresipKit

extension BaresipEngine {
    package func announcedCallUUID(header: String?, callID: BaresipCallID) async -> UUID? {
        guard let header, let value = try? await incomingHeader(header, callID: callID) else { return nil }
        return UUID(uuidString: value.trimmingCharacters(in: .whitespaces))
    }
}
