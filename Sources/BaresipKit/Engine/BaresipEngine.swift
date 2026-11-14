import Foundation

/// A SIP user agent backed by baresip.
///
/// Create one engine per app, start it, add an account and place or answer calls. All
/// operations are `async`: they run on the engine thread and return when the core has
/// accepted them. What happens afterwards arrives through ``events``.
///
/// ```swift
/// let engine = try BaresipEngine(configuration: BaresipConfiguration(instanceUUID: installID))
/// try await engine.start()
/// let account = try await engine.addAccount(
///     BaresipAccountConfiguration(aor: "sip:alice@example.com", authPassword: password)
/// )
/// try await engine.register(accountID: account)
/// let call = try await engine.makeCall(destination: "sip:bob@example.com")
/// ```
public final class BaresipEngine: @unchecked Sendable {
    // SAFETY: every mutable property below is read and written only while holding `lock`;
    // `core` is immutable and thread-safe, and `workQueue` is a serial dispatch queue.

    /// The configuration the engine was created with.
    public let configuration: BaresipConfiguration

    let core: CoreEngine
    let lock = NSLock()
    var videoSinks: [VideoSinkKey: VideoSinkBox] = [:]
    private var continuations: [UUID: AsyncStream<BaresipEvent>.Continuation] = [:]
    private var logHandler: BaresipLogHandler?
    private let workQueue = DispatchQueue(label: "baresipkit.engine", qos: .userInitiated)

    /// Creates an engine. The engine does nothing until ``start()`` is called.
    ///
    /// - Parameter configuration: Engine-wide settings.
    /// - Throws: ``BaresipError`` when the core rejects the configuration.
    public init(configuration: BaresipConfiguration) throws {
        self.configuration = configuration
        core = try CoreEngine.create(configuration)
        core.installCallbacks(for: self)
    }

    deinit {
        core.destroy()
        let finished = lock.withLock { () -> [AsyncStream<BaresipEvent>.Continuation] in
            let values = Array(continuations.values)
            continuations.removeAll()
            return values
        }
        for continuation in finished {
            continuation.finish()
        }
    }

    /// A new stream of engine events.
    ///
    /// Each access returns an independent stream that receives every event from that moment
    /// on. The stream ends when the engine is deallocated.
    public var events: AsyncStream<BaresipEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            lock.withLock {
                continuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock {
                    self.continuations[id] = nil
                }
            }
        }
    }

    /// Sets the closure that receives engine log output, or removes it.
    ///
    /// - Parameter handler: The log handler, or `nil` to stop logging.
    public func setLogHandler(_ handler: BaresipLogHandler?) {
        lock.withLock {
            logHandler = handler
        }
    }

    /// The current lifecycle state.
    public var state: BaresipEngineState {
        core.state
    }

    /// `true` when called on the engine's internal thread, for example from a log handler.
    var isEngineThread: Bool {
        core.isEngineThread
    }

    /// The C ABI version of the linked core.
    static var abiVersion: (major: Int, minor: Int) {
        CoreEngine.abiVersion
    }

    /// Feature flags of the linked core, for example `reg.contact-params`.
    static var capabilities: [String] {
        CoreEngine.capabilities
    }

    /// The version string of the linked core, including the baresip and libre versions.
    public static var coreVersion: String {
        CoreEngine.version
    }

    /// Encodes contact parameters exactly as they will appear in the `Contact` header.
    ///
    /// - Parameter parameters: The parameters to encode.
    /// - Returns: The encoded parameters, for example `;pn-provider=apns;pn-prid=…`.
    /// - Throws: ``BaresipError`` with ``BaresipError/Code/invalidArgument`` when a name or value is
    ///   not a valid SIP token.
    public static func encodeContactParameters(_ parameters: [BaresipContactParameter]) throws -> String {
        try CoreEngine.encodeContactParameters(parameters)
    }

    func run<T: Sendable>(_ body: @escaping @Sendable (CoreEngine) throws -> T) async throws -> T {
        let core = core
        return try await withCheckedThrowingContinuation { continuation in
            workQueue.async {
                continuation.resume(with: Result { try body(core) })
            }
        }
    }

    func deliver(_ event: BaresipEvent) {
        if case .call(let callID, .released, _) = event {
            clearVideoSinks(callID: callID)
        }
        let receivers = lock.withLock { Array(continuations.values) }
        for continuation in receivers {
            continuation.yield(event)
        }
    }

    func deliverLog(_ entry: BaresipLogEntry) {
        let handler = lock.withLock { logHandler }
        handler?(entry)
    }
}
