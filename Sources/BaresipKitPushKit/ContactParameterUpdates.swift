import BaresipKit

struct ContactParameterUpdates {
    struct Request: Equatable {
        let accountID: BaresipAccountID
        let parameters: [BaresipContactParameter]
    }

    private var latest: Request?
    private var isSending = false

    mutating func submit(_ request: Request) -> Bool {
        latest = request
        guard !isSending else { return false }
        isSending = true
        return true
    }

    mutating func next() -> Request? {
        guard let request = latest else {
            isSending = false
            return nil
        }
        latest = nil
        return request
    }
}
