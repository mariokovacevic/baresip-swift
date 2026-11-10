struct UncheckedSendable<Value>: @unchecked Sendable {
    // SAFETY: wraps the PushKit completion handler, which is handed to a single task and not
    // touched by the delegate method afterwards, and the CXProvider of a placeholder call, which
    // is thread-safe and used only until that call has ended.
    let value: Value
}
