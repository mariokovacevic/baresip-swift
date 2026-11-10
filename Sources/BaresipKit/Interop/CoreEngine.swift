import BaresipKitCore

struct CoreEngine: @unchecked Sendable {
    // SAFETY: the C engine handle is thread-safe: every bsk_* function may be called from any
    // thread and marshals work onto the engine thread. The handle stays valid until destroy().
    let raw: OpaquePointer

    static func check(_ operation: (inout bsk_error) -> bsk_status) throws {
        var error = bsk_error()
        let status = operation(&error)
        guard status == BSK_OK else {
            throw BaresipError(status: status, error)
        }
    }

    static func checkStatus(_ status: bsk_status, message: String = "") throws {
        guard status == BSK_OK else {
            throw BaresipError(code: BaresipError.Code(status), message: message)
        }
    }

    static func withArena<T>(_ body: (CStringArena) throws -> T) rethrows -> T {
        let arena = CStringArena()
        return try withExtendedLifetime(arena) { try body(arena) }
    }

    static func create(_ configuration: BaresipConfiguration) throws -> CoreEngine {
        var created: OpaquePointer?
        try withArena { arena in
            var config = bsk_engine_config(configuration, arena: arena)
            try check { bsk_engine_create(&config, nil, nil, &created, &$0) }
        }
        guard let created else {
            throw BaresipError(code: .internalError, message: "engine handle missing")
        }
        return CoreEngine(raw: created)
    }

    func destroy() {
        bsk_engine_set_event_handler(raw, nil, nil)
        bsk_engine_set_log_handler(raw, nil, nil)
        bsk_engine_destroy(raw)
    }

    func installCallbacks(for owner: BaresipEngine) {
        // SAFETY: BaresipEngine removes both handlers in deinit before the engine is destroyed,
        // so the unretained owner pointer is valid whenever the core calls back.
        let user = Unmanaged.passUnretained(owner).toOpaque()
        bsk_engine_set_event_handler(raw, { _, event, user in
            guard let user, let event, let converted = BaresipEvent(event) else { return }
            Unmanaged<BaresipEngine>.fromOpaque(user).takeUnretainedValue().deliver(converted)
        }, user)
        bsk_engine_set_log_handler(raw, { level, domain, line, length, user in
            guard let user, let line else { return }
            // SAFETY: line points at length bytes that are valid for the duration of the callback.
            let text = decodeUTF8(UnsafeRawBufferPointer(start: line, count: length))
            let entry = BaresipLogEntry(level: BaresipLogLevel(level), domain: BaresipLogDomain(domain), message: text)
            Unmanaged<BaresipEngine>.fromOpaque(user).takeUnretainedValue().deliverLog(entry)
        }, user)
    }

    var state: BaresipEngineState {
        BaresipEngineState(bsk_engine_get_state(raw))
    }

    var isEngineThread: Bool {
        bsk_engine_is_engine_thread(raw)
    }

    func start() throws {
        try Self.check { bsk_engine_start(raw, &$0) }
    }

    func stop(timeout: Duration) throws {
        try Self.check { bsk_engine_stop(raw, timeout.wholeMilliseconds, &$0) }
    }

    func prepareForPushWakeUp() throws {
        try Self.check { bsk_engine_prepare_for_push_wakeup(raw, &$0) }
    }

    func suspend() throws {
        try Self.check { bsk_engine_suspend(raw, &$0) }
    }

    func resume() throws {
        try Self.check { bsk_engine_resume(raw, &$0) }
    }

    func networkChanged(reregister: Bool, updateCalls: Bool) throws {
        try Self.check { bsk_engine_network_changed(raw, reregister, updateCalls, &$0) }
    }

    func audioSessionActivated() throws {
        try Self.check { bsk_engine_audio_session_activated(raw, &$0) }
    }

    func audioSessionDeactivated() throws {
        try Self.check { bsk_engine_audio_session_deactivated(raw, &$0) }
    }

    func audioRouteChanged() throws {
        try Self.check { bsk_engine_audio_route_changed(raw, &$0) }
    }

    func audioInterruption(began: Bool) throws {
        try Self.check { bsk_engine_audio_interruption(raw, began, &$0) }
    }

    static var abiVersion: (major: Int, minor: Int) {
        let version = bsk_abi_version()
        return (Int(version >> 16), Int(version & 0xFFFF))
    }

    static var capabilities: [String] {
        let needed = bsk_capabilities(nil, 0)
        var buffer = [CChar](repeating: 0, count: needed + 1)
        _ = bsk_capabilities(&buffer, buffer.count)
        return string(fromNullTerminated: buffer).split(separator: " ").map(String.init)
    }

    static var version: String {
        String(cString: bsk_version_string())
    }
}
