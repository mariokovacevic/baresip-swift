package struct UncheckedSendable<Value>: @unchecked Sendable {
    // SAFETY: used only for CallKit and LiveCommunicationKit actions, whose fulfill() and fail()
    // may be called from any thread, for the CXProvider of PushKit's placeholder call, which is
    // thread-safe, and for values handed to exactly one task without further access by the
    // sender, such as PushKit's completion handler and payload.
    package let value: Value

    package init(value: Value) {
        self.value = value
    }
}
