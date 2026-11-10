enum IncomingPushReport {
    @discardableResult
    static func deliver(_ payload: [AnyHashable: Any], to handler: ([AnyHashable: Any]) throws -> Void,
                        orReportPlaceholder reportPlaceholder: () -> Void) -> Error? {
        do {
            try handler(payload)
            return nil
        } catch {
            reportPlaceholder()
            return error
        }
    }
}
