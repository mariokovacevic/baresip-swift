struct UncheckedSendable<Value>: @unchecked Sendable {
    // SAFETY: used only for CallKit actions, whose fulfill() and fail() may be called from any
    // thread, and for values handed to exactly one task without further access by the sender.
    let value: Value
}
