struct UncheckedSendable<Value>: @unchecked Sendable {
    // SAFETY: wraps the push payload and the PushKit completion handler, which are handed to a
    // single task and not touched by the delegate method afterwards.
    let value: Value
}
