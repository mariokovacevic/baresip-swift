/// The lifecycle state of a ``BaresipEngine``.
public enum BaresipEngineState: Int, Sendable, Codable {
    /// Created, not started.
    case idle = 0
    /// ``BaresipEngine/start()`` is in progress.
    case starting = 1
    /// Started; modules are loaded.
    case ready = 2
    /// Running and able to register and call.
    case running = 3
    /// ``BaresipEngine/stop(timeout:)`` is in progress.
    case stopping = 4
    /// Stopped. Create a new engine to start again.
    case stopped = 5
    /// Start failed or the engine stopped on an error.
    case failed = 6
}
